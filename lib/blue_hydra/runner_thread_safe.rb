require_relative 'thread_manager'

module BlueHydra
  # Thread-safe version of the Runner class with enhanced thread management
  # and monitoring capabilities for Ruby 3.x
  class Runner
    include MonitorMixin
    
    attr_reader :thread_manager, :command, :queues, :scanner_status, :cui_status
    attr_reader :query_history, :stunned, :processing_speed
    
    # Initialize thread-safe queues and state
    def initialize
      super() # Initialize Monitor
      
      @thread_manager = ThreadManager.new
      @queues = {
        raw: Queue.new,
        chunk: Queue.new,
        result: Queue.new,
        info_scan: Queue.new,
        l2ping: Queue.new
      }
      
      @scanner_status = {}
      @cui_status = {}
      @query_history = {}
      @stunned = false
      @stopping = false
      @rssi_data_mutex = Mutex.new
      
      setup_command
    end
    
    # Setup the command based on configuration
    def setup_command
      @command = if BlueHydra.config["file"]
        if BlueHydra.config["file"] =~ /\.xz$/
          "xzcat #{BlueHydra.config["file"]}"
        elsif BlueHydra.config["file"] =~ /\.gz$/
          "zcat #{BlueHydra.config["file"]}"
        else
          "cat #{BlueHydra.config["file"]}"
        end
      else
        "btmon -T -i #{BlueHydra.config["bt_device"]}"
      end
      
      # Validate command
      cmd_binary = @command.split[0]
      unless ::File.executable?(`command -v #{cmd_binary} 2> /dev/null`.chomp)
        BlueHydra.logger.fatal("Failed to find: '#{cmd_binary}' which is needed for the current setting...")
        exit 1
      end
    end
    
    # Start the runner with enhanced thread safety
    def start
      synchronize do
        return if @running
        @running = true
        @stopping = false
      end
      
      BlueHydra.logger.debug("Runner starting with command: '#{@command}' ...")
      
      # Initialize database state
      initialize_database_state
      
      # Start all threads with proper error handling and monitoring
      start_core_threads
      start_optional_threads
      
      BlueHydra.logger.info("Runner started successfully")
    rescue => e
      handle_startup_error(e)
    end
    
    # Stop the runner gracefully
    def stop
      synchronize do
        return if @stopping
        @stopping = true
      end
      
      BlueHydra.logger.info("Runner stopping...")
      
      # First stop input threads
      @thread_manager.kill_thread(:btmon)
      @thread_manager.kill_thread(:discovery) unless BlueHydra.config["file"]
      @thread_manager.kill_thread(:ubertooth) if thread_status(:ubertooth)
      
      # Wait for queues to drain
      wait_for_queue_drain
      
      # Shutdown remaining threads
      @thread_manager.shutdown(timeout: 10)
      
      # Clear queues
      synchronize do
        @queues.each { |_, queue| queue.clear }
        @running = false
      end
      
      BlueHydra.logger.info("Runner stopped")
    end
    
    # Get comprehensive status
    def status
      synchronize do
        {
          running: @running,
          stopping: @stopping,
          queues: @queues.transform_values(&:length),
          threads: @thread_manager.thread_status,
          scanner_status: @scanner_status.dup,
          healthy: @thread_manager.healthy?
        }
      end
    end
    
    private
    
    # Initialize database state
    def initialize_database_state
      unless BlueHydra::Device.first.nil?
        BlueHydra.logger.info("Marking older devices as 'offline'...")
        BlueHydra::Device.mark_old_devices_offline(true)
        
        if BlueHydra.pulse
          BlueHydra.logger.info("Syncing all hosts to Pulse...")
          BlueHydra::Device.sync_all_to_pulse
        end
      else
        BlueHydra.logger.info("No devices found in DB, starting clean.")
      end
      
      BlueHydra::Pulse.reset
    end
    
    # Start core processing threads
    def start_core_threads
      # Result processing thread (must start first)
      @thread_manager.register_thread(:result, restart_policy: :always) do
        run_result_thread
      end
      
      # Parser thread
      @thread_manager.register_thread(:parser, restart_policy: :always) do
        run_parser_thread
      end
      
      # Chunker thread
      @thread_manager.register_thread(:chunker, restart_policy: :always) do
        run_chunker_thread
      end
      
      # Btmon thread
      @thread_manager.register_thread(:btmon, restart_policy: :limited) do
        run_btmon_thread
      end
    end
    
    # Start optional threads based on configuration
    def start_optional_threads
      # Discovery thread
      unless BlueHydra.config["file"] || ENV["BLUE_HYDRA"] == "test"
        if File.exist?("/run/dbus/system_bus_socket")
          @thread_manager.register_thread(:discovery, restart_policy: :limited) do
            run_discovery_thread
          end
        else
          BlueHydra.logger.warn("D-Bus system bus not available - discovery disabled")
        end
      end
      
      # CUI thread
      unless BlueHydra.daemon_mode
        @thread_manager.register_thread(:cui, restart_policy: :none) do
          run_cui_thread
        end
      end
      
      # API thread
      if BlueHydra.file_api
        @thread_manager.register_thread(:api, restart_policy: :always) do
          run_api_thread
        end
      end
      
      # RSSI threads
      if BlueHydra.signal_spitter
        @thread_manager.register_thread(:signal_spitter, restart_policy: :always) do
          run_signal_spitter_thread
        end
        
        @thread_manager.register_thread(:empty_spittoon, restart_policy: :always) do
          run_empty_spittoon_thread
        end
      end
      
      # Ubertooth thread
      setup_ubertooth unless BlueHydra.config["file"]
    end
    
    # Thread implementations
    def run_btmon_thread
      BlueHydra.logger.info("Btmon thread starting")
      
      handler = BlueHydra::BtmonHandler.new(@command, @queues[:raw])
      
      # Check for shutdown signal
      until Thread.current[:shutdown]
        sleep 1
      end
    rescue BtmonExitedError => e
      BlueHydra.logger.error("Btmon exited: #{e.message}")
      raise
    end
    
    def run_chunker_thread
      BlueHydra.logger.info("Chunker thread starting")
      
      chunker = BlueHydra::Chunker.new(@queues[:raw], @queues[:chunk])
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    end
    
    def run_parser_thread
      BlueHydra.logger.info("Parser thread starting")
      
      parser = BlueHydra::Parser.new(
        @queues[:chunk], 
        @queues[:result],
        rssi_mutex: @rssi_data_mutex
      )
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    end
    
    def run_result_thread
      BlueHydra.logger.info("Result thread starting")
      
      result_handler = BlueHydra::ResultThread.new(
        @queues[:result],
        @queues[:info_scan],
        @queues[:l2ping]
      )
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    end
    
    def run_discovery_thread
      BlueHydra.logger.info("Discovery thread starting")
      
      discovery = BlueHydra::DiscoveryThread.new(
        @queues[:info_scan],
        @queues[:l2ping],
        self
      )
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    rescue DiscoveryDisabledError => e
      BlueHydra.logger.warn("Discovery disabled: #{e.message}")
      # Don't restart this thread
    end
    
    def run_cui_thread
      BlueHydra.logger.info("CUI thread starting")
      
      cui = BlueHydra::Cui.new(self)
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    end
    
    def run_api_thread
      BlueHydra.logger.info("API thread starting")
      
      api = BlueHydra::FileApi.new
      
      until Thread.current[:shutdown]
        sleep 0.1
      end
    end
    
    def run_signal_spitter_thread
      BlueHydra.logger.debug("Signal spitter thread starting")
      
      server = TCPServer.new('localhost', 1124)
      
      loop do
        break if Thread.current[:shutdown]
        
        client = server.accept
        Thread.new(client) do |conn|
          handle_signal_spitter_client(conn)
        end
      end
    ensure
      server&.close
    end
    
    def run_empty_spittoon_thread
      BlueHydra.logger.debug("Empty spittoon thread starting")
      
      loop do
        break if Thread.current[:shutdown]
        
        @rssi_data_mutex.synchronize do
          # Clean old RSSI data
          # Implementation depends on RSSI data structure
        end
        
        sleep 30
      end
    end
    
    # Ubertooth setup with error handling
    def setup_ubertooth
      return unless check_ubertooth_hardware
      
      @thread_manager.register_thread(:ubertooth, restart_policy: :limited) do
        run_ubertooth_thread
      end
    end
    
    def run_ubertooth_thread
      BlueHydra.logger.info("Ubertooth thread starting")
      
      # Ubertooth implementation
      until Thread.current[:shutdown]
        # Run ubertooth command and process output
        sleep 1
      end
    end
    
    # Helper methods
    def wait_for_queue_drain
      timeout = 30
      start_time = Time.now
      
      loop do
        all_empty = synchronize do
          @queues[:result].empty? && 
          @queues[:chunk].empty? &&
          @queues[:raw].empty?
        end
        
        break if all_empty
        break if (Time.now - start_time) > timeout
        
        BlueHydra.logger.info("Waiting for queues to drain... Result: #{@queues[:result].length}")
        sleep 1
      end
    end
    
    def handle_startup_error(error)
      BlueHydra.logger.error("Runner startup failed: #{error.message}")
      error.backtrace.each { |line| BlueHydra.logger.error(line) }
      
      BlueHydra::Pulse.send_event('blue_hydra', {
        key: 'blue_hydra_startup_error',
        title: 'Blue Hydra startup failed',
        message: error.message,
        severity: 'ERROR'
      })
      
      stop
      raise error
    end
    
    def thread_status(name)
      @thread_manager.thread_status(name)
    end
    
    def check_ubertooth_hardware
      # Ubertooth hardware detection logic
      # Returns true if ubertooth should be started
      false # Placeholder
    end
    
    def handle_signal_spitter_client(client)
      # Handle RSSI API client
      client.close
    end
    
    # Queue accessor methods for backward compatibility
    def raw_queue; @queues[:raw]; end
    def chunk_queue; @queues[:chunk]; end
    def result_queue; @queues[:result]; end
    def info_scan_queue; @queues[:info_scan]; end
    def l2ping_queue; @queues[:l2ping]; end
  end
end 