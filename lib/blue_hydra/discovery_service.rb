require_relative 'dbus_manager'
require_relative 'bluez_adapter'

module BlueHydra
  # DiscoveryService handles Bluetooth device discovery using native Ruby D-Bus
  # This replaces the Python test-discovery script approach
  class DiscoveryService
    attr_reader :adapter, :dbus_manager, :discovery_time
    attr_accessor :enabled
    
    def initialize(adapter_id = nil, options = {})
      @adapter_id = adapter_id || BlueHydra.config["bt_device"] || "hci0"
      @discovery_time = options[:discovery_time] || (BlueHydra.info_scan ? 30 : 180)
      @enabled = true
      @adapter = nil
      @dbus_manager = nil
    end
    
    # Initialize D-Bus connection and adapter
    def connect
      return false unless @enabled
      
      begin
        # Check for D-Bus availability first
        unless File.exist?("/run/dbus/system_bus_socket")
          BlueHydra.logger.warn("D-Bus system bus not available - discovery disabled")
          @enabled = false
          return false
        end
        
        # Create D-Bus manager
        @dbus_manager = DBusManager.new(:system, {
          max_reconnect_attempts: 3,
          reconnect_delay: 5,
          health_check_interval: 60
        })
        
        # Connect to D-Bus
        unless @dbus_manager.connect
          BlueHydra.logger.error("Failed to connect to D-Bus")
          @enabled = false
          return false
        end
        
        # Create BlueZ adapter interface
        @adapter = BluezAdapter.new(@adapter_id, @dbus_manager)
        
        # Ensure adapter is powered
        unless @adapter.powered?
          BlueHydra.logger.info("Powering on adapter #{@adapter_id}")
          @adapter.powered = true
          sleep 1 # Give adapter time to power on
        end
        
        BlueHydra.logger.info("Discovery service connected to adapter: #{@adapter.address}")
        true
        
      rescue DBusConnectionError => e
        BlueHydra.logger.error("D-Bus connection error: #{e.message}")
        @enabled = false
        false
      rescue AdapterNotFoundError => e
        BlueHydra.logger.error("Adapter not found: #{e.message}")
        @enabled = false
        false
      rescue => e
        BlueHydra.logger.error("Failed to initialize discovery service: #{e.class} - #{e.message}")
        @enabled = false
        false
      end
    end
    
    # Run discovery for the specified duration
    def run_discovery
      return :disabled unless @enabled
      return :not_connected unless connected?
      
      begin
        # Start discovery
        BlueHydra.logger.debug("Starting discovery for #{@discovery_time} seconds")
        
        # Check if already discovering
        if @adapter.discovering?
          BlueHydra.logger.debug("Discovery already in progress, stopping first")
          @adapter.stop_discovery
          sleep 1
        end
        
        # Start discovery
        unless @adapter.start_discovery
          BlueHydra.logger.warn("Failed to start discovery")
          return :failed
        end
        
        # Run for specified time
        start_time = Time.now
        while (Time.now - start_time) < @discovery_time
          sleep 1
          
          # Check if discovery is still active
          unless @adapter.discovering?
            BlueHydra.logger.warn("Discovery stopped unexpectedly")
            break
          end
        end
        
        # Stop discovery
        @adapter.stop_discovery
        BlueHydra.logger.debug("Discovery completed")
        
        :success
        
      rescue BluezNotReadyError => e
        BlueHydra.logger.error("Adapter not ready: #{e.message}")
        :not_ready
      rescue DBus::Error => e
        handle_dbus_error(e)
      rescue => e
        BlueHydra.logger.error("Discovery error: #{e.class} - #{e.message}")
        :error
      end
    end
    
    # Check if connected to adapter
    def connected?
      @adapter && @adapter.connected? || false
    end
    
    # Disconnect from D-Bus
    def disconnect
      @adapter = nil
      @dbus_manager&.disconnect
      @dbus_manager = nil
    end
    
    # Get discovered devices
    def devices
      return [] unless connected?
      @adapter.devices
    rescue => e
      BlueHydra.logger.error("Failed to get devices: #{e.message}")
      []
    end
    
    # Handle D-Bus errors
    private
    
    def handle_dbus_error(error)
      case error.message
      when /org.bluez.Error.NotReady/
        raise BluezNotReadyError
      when /org.freedesktop.DBus.Error.ServiceUnknown.*org.bluez/
        BlueHydra.logger.error("BlueZ service not available")
        @enabled = false
        :service_unavailable
      when /org.freedesktop.DBus.Error.NoReply/
        BlueHydra.logger.error("D-Bus timeout")
        :timeout
      when /org.freedesktop.DBus.Error.AccessDenied/
        BlueHydra.logger.error("D-Bus access denied - need root privileges")
        @enabled = false
        :access_denied
      else
        BlueHydra.logger.error("D-Bus error: #{error.message}")
        :dbus_error
      end
    end
  end
end 