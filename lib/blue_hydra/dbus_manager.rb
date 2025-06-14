require 'dbus'
require 'logger'
require 'forwardable'

module BlueHydra
  # DBusManager provides centralized D-Bus connection management with health monitoring,
  # automatic reconnection, and graceful error handling.
  class DBusManager
    extend Forwardable
    
    # Connection states
    DISCONNECTED = :disconnected
    CONNECTING   = :connecting
    CONNECTED    = :connected
    FAILED       = :failed
    
    attr_reader :state, :last_error, :connection_attempts
    
    # Delegate logging methods to BlueHydra logger
    def_delegators :BlueHydra, :logger
    
    def initialize(bus_type = :system, options = {})
      @bus_type = bus_type
      @options = {
        max_reconnect_attempts: 5,
        reconnect_delay: 5,
        health_check_interval: 30
      }.merge(options)
      
      @bus = nil
      @state = DISCONNECTED
      @last_error = nil
      @connection_attempts = 0
      @health_check_thread = nil
      @reconnect_thread = nil
      @mutex = Mutex.new
      
      logger.info("DBusManager initialized for #{@bus_type} bus")
    end
    
    # Connect to D-Bus
    def connect
      @mutex.synchronize do
        return true if @state == CONNECTED
        
        @state = CONNECTING
        @connection_attempts += 1
        
        begin
          logger.debug("Attempting to connect to D-Bus #{@bus_type} bus (attempt #{@connection_attempts})")
          
          # Check if D-Bus socket exists for system bus
          if @bus_type == :system && !File.exist?("/run/dbus/system_bus_socket")
            raise DBus::Error, "D-Bus system bus socket not found"
          end
          
          @bus = case @bus_type
                 when :system
                   DBus::SystemBus.instance
                 when :session
                   DBus::SessionBus.instance
                 else
                   raise ArgumentError, "Invalid bus type: #{@bus_type}"
                 end
          
          # Test the connection by getting a service
          @bus.service("org.freedesktop.DBus")
          
          @state = CONNECTED
          @connection_attempts = 0
          @last_error = nil
          
          logger.info("Successfully connected to D-Bus #{@bus_type} bus")
          
          # Start health monitoring
          start_health_monitoring
          
          true
        rescue => e
          @state = FAILED
          @last_error = e
          
          logger.error("Failed to connect to D-Bus: #{e.class} - #{e.message}")
          
          # Start reconnection thread if within retry limits
          if @connection_attempts < @options[:max_reconnect_attempts]
            start_reconnection_thread
          else
            logger.error("Max reconnection attempts reached. D-Bus connection failed permanently.")
          end
          
          false
        end
      end
    end
    
    # Disconnect from D-Bus
    def disconnect
      @mutex.synchronize do
        stop_health_monitoring
        stop_reconnection_thread
        
        @bus = nil
        @state = DISCONNECTED
        @connection_attempts = 0
        
        logger.info("Disconnected from D-Bus #{@bus_type} bus")
      end
    end
    
    # Check if connected
    def connected?
      @state == CONNECTED
    end
    
    # Get a service from the bus
    def service(name)
      ensure_connected
      @bus.service(name)
    end
    
    # Get the BlueZ service
    def bluez_service
      service("org.bluez")
    end
    
    # Execute a block with automatic reconnection on failure
    def with_connection(&block)
      ensure_connected
      
      begin
        yield @bus
      rescue DBus::Error => e
        logger.error("D-Bus operation failed: #{e.message}")
        @state = FAILED
        @last_error = e
        
        # Try to reconnect
        if connect
          # Retry the operation once after reconnection
          yield @bus
        else
          raise e
        end
      end
    end
    
    # Get connection statistics
    def stats
      {
        state: @state,
        bus_type: @bus_type,
        connection_attempts: @connection_attempts,
        last_error: @last_error&.message,
        health_check_active: !@health_check_thread.nil?
      }
    end
    
    private
    
    # Ensure we're connected before operations
    def ensure_connected
      unless connected?
        raise DBus::Error, "Not connected to D-Bus" unless connect
      end
    end
    
    # Start health monitoring thread
    def start_health_monitoring
      return if @health_check_thread
      
      @health_check_thread = Thread.new do
        logger.debug("Health monitoring thread started")
        
        loop do
          sleep @options[:health_check_interval]
          
          begin
            # Simple health check - try to get DBus service
            @mutex.synchronize do
              if @state == CONNECTED && @bus
                @bus.service("org.freedesktop.DBus")
                logger.debug("D-Bus health check passed")
              end
            end
          rescue => e
            logger.warn("D-Bus health check failed: #{e.message}")
            @mutex.synchronize do
              @state = FAILED
              @last_error = e
            end
            
            # Trigger reconnection
            start_reconnection_thread
            break
          end
        end
      end
    end
    
    # Stop health monitoring thread
    def stop_health_monitoring
      if @health_check_thread
        @health_check_thread.kill
        @health_check_thread = nil
        logger.debug("Health monitoring thread stopped")
      end
    end
    
    # Start reconnection thread
    def start_reconnection_thread
      return if @reconnect_thread
      
      @reconnect_thread = Thread.new do
        logger.info("Reconnection thread started")
        
        sleep @options[:reconnect_delay]
        
        # Stop health monitoring during reconnection
        stop_health_monitoring
        
        # Try to reconnect
        connect
        
        @reconnect_thread = nil
      end
    end
    
    # Stop reconnection thread
    def stop_reconnection_thread
      if @reconnect_thread
        @reconnect_thread.kill
        @reconnect_thread = nil
        logger.debug("Reconnection thread stopped")
      end
    end
  end
  
  # Custom error class for D-Bus connection issues
  class DBusConnectionError < StandardError; end
end 