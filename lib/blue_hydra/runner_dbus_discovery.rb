require_relative 'discovery_service'

module BlueHydra
  # Module to extend Runner with modernized D-Bus discovery
  # This replaces the Python script-based discovery with native Ruby D-Bus
  module RunnerDBusDiscovery
    # Start discovery thread using native Ruby D-Bus instead of Python scripts
    def start_discovery_thread_dbus
      BlueHydra.logger.info("Discovery thread starting (Ruby D-Bus)")
      
      self.discovery_thread = Thread.new do
        begin
          # Determine discovery timing
          if BlueHydra.info_scan
            discovery_time = 30
          else
            discovery_time = 180
          end
          
          # Create discovery service
          discovery_service = DiscoveryService.new(nil, discovery_time: discovery_time)
          
          # Try to connect
          unless discovery_service.connect
            BlueHydra.logger.warn("Failed to initialize discovery service")
            BlueHydra.logger.info("Continuing in passive-only mode - btmon data collection active")
            return # Exit thread, passive mode only
          end
          
          # Track errors for recovery attempts
          bluez_errors = 0
          bluetoothd_errors = 0
          
          loop do
            begin
              # Process scan queues first
              process_scan_queues(bluetoothd_errors)
              
              # Reset interface before discovery
              hci_reset(bluetoothd_errors)
              
              # Brief pause before discovery
              sleep 1
              
              # Update scanner status
              self.scanner_status[:test_discovery] = Time.now.to_i unless BlueHydra.daemon_mode
              
              # Run discovery
              result = discovery_service.run_discovery
              
              case result
              when :success
                BlueHydra.logger.debug("Discovery cycle completed successfully")
                bluez_errors = 0
              when :not_ready
                raise BluezNotReadyError
              when :disabled
                BlueHydra.logger.info("Discovery disabled - continuing in passive mode")
                break
              when :service_unavailable
                BlueHydra.logger.warn("BlueZ service not available")
                bluetoothd_errors = bluetoothdDbusError(bluetoothd_errors)
              when :access_denied
                BlueHydra.logger.error("Access denied - need root privileges")
                break
              else
                BlueHydra.logger.warn("Discovery returned: #{result}")
              end
              
            rescue DiscoveryDisabledError => e
              BlueHydra.logger.warn("Discovery disabled: #{e.message}")
              BlueHydra.logger.info("Discovery thread exiting - continuing in passive-only mode")
              break
            rescue BluezNotReadyError
              BlueHydra.logger.info("Bluez reports not ready, attempting to recover...")
              bluez_errors += 1
              if bluez_errors == 1
                BlueHydra.logger.error("Bluez reported #{BlueHydra.config["bt_device"]} not ready, attempting to reset with rfkill")
                rfkillreset_command = "#{File.expand_path('../../../bin/rfkill-reset', __FILE__)} #{BlueHydra.config["bt_device"]}"
                rfkillreset_errors = BlueHydra::Command.execute3(rfkillreset_command, 45)[:stdout]
                if rfkillreset_errors
                  bluez_errors += 1
                end
              end
              if bluez_errors > 1
                unless BlueHydra.daemon_mode
                  self.cui_thread.kill if self.cui_thread
                  puts "Bluez reported #{BlueHydra.config["bt_device"]} not ready and failed to auto-reset with rfkill"
                  puts "Try removing and replugging the card, or toggling rfkill on and off"
                end
                BlueHydra.logger.fatal("Bluez reported #{BlueHydra.config["bt_device"]} not ready and failed to reset with rfkill")
                BlueHydra::Pulse.send_event('blue_hydra',
                  {
                    key: 'blue_hydra_bluez_error',
                    title: 'Blue Hydra Encountered Bluez Error',
                    message: "Bluez reported #{BlueHydra.config["bt_device"]} not ready and failed to reset with rfkill",
                    severity: 'FATAL'
                  })
                exit 1
              end
            rescue => e
              BlueHydra.logger.error("Discovery loop crashed: #{e.message}")
              e.backtrace.each do |x|
                BlueHydra.logger.error("#{x}")
              end
              BlueHydra::Pulse.send_event('blue_hydra',
                {
                  key: 'blue_hydra_discovery_loop_error',
                  title: 'Blue Hydras Discovery Loop Encountered An Error',
                  message: "Discovery loop crashed: #{e.message}",
                  severity: 'ERROR'
                })
              BlueHydra.logger.error("Sleeping 20s...")
              sleep 20
              
              # Try to reconnect
              unless discovery_service.connected?
                BlueHydra.logger.info("Attempting to reconnect discovery service...")
                unless discovery_service.connect
                  BlueHydra.logger.error("Failed to reconnect - disabling discovery")
                  break
                end
              end
            end
          end
          
        rescue => e
          BlueHydra.logger.error("Discovery thread error: #{e.message}")
          e.backtrace.each do |x|
            BlueHydra.logger.error("#{x}")
          end
          BlueHydra::Pulse.send_event('blue_hydra',
            {
              key: 'blue_hydra_discovery_thread_error',
              title: 'Blue Hydras Discovery Thread Encountered An Error',
              message: "Discovery thread error: #{e.message}",
              severity: 'ERROR'
            })
        ensure
          # Clean up
          discovery_service&.disconnect
        end
      end
    end
    
    private
    
    # Process info scan and l2ping queues
    def process_scan_queues(bluetoothd_errors)
      # Clear the queues
      until info_scan_queue.empty? && l2ping_queue.empty?
        # Process info scan queue first
        until info_scan_queue.empty?
          hci_reset(bluetoothd_errors)
          
          BlueHydra.logger.debug("Popping off info scan queue. Depth: #{info_scan_queue.length}")
          
          command = info_scan_queue.pop
          case command[:command]
          when :info # classic mode devices
            info_errors = BlueHydra::Command.execute3("hcitool -i #{BlueHydra.config["bt_device"]} info #{command[:address]}", 3)[:stderr]
            
          when :leinfo # low energy devices
            info_errors = BlueHydra::Command.execute3("hcitool -i #{BlueHydra.config["bt_device"]} leinfo --random #{command[:address]}", 3)[:stderr]
            
            # Try different LE address types if random fails
            if info_errors == "Could not create connection: Input/output error"
              info_errors = nil
              BlueHydra.logger.debug("Random leinfo failed against #{command[:address]}")
              hci_reset(bluetoothd_errors)
              
              info2_errors = BlueHydra::Command.execute3("hcitool -i #{BlueHydra.config["bt_device"]} leinfo --static #{command[:address]}", 3)[:stderr]
              if info2_errors == "Could not create connection: Input/output error"
                BlueHydra.logger.debug("Static leinfo failed against #{command[:address]}")
                hci_reset(bluetoothd_errors)
                
                info3_errors = BlueHydra::Command.execute3("hcitool -i #{BlueHydra.config["bt_device"]} leinfo #{command[:address]}", 3)[:stderr]
                if info3_errors == "Could not create connection: Input/output error"
                  BlueHydra.logger.debug("Default leinfo failed against #{command[:address]}")
                end
              end
            end
          else
            BlueHydra.logger.error("Invalid command detected... #{command.inspect}")
            info_errors = nil
          end
          
          # Handle errors if any
          handle_info_errors(info_errors, command) if info_errors
        end
        
        # Process l2ping queue
        unless l2ping_queue.empty?
          hci_reset(bluetoothd_errors)
          BlueHydra.logger.debug("Popping off l2ping queue. Depth: #{l2ping_queue.length}")
          
          command = l2ping_queue.pop
          l2ping_errors = BlueHydra::Command.execute3("l2ping -c 3 -i #{BlueHydra.config["bt_device"]} #{command[:address]}", 5)[:stderr]
          
          handle_l2ping_errors(l2ping_errors, command) if l2ping_errors
        end
      end
    end
    
    # Handle info command errors
    def handle_info_errors(errors, command)
      case errors.chomp
      when /connect: No route to host/i
        # Device not reachable
      when /create connection: Input\/output error/i
        # Connection failed
      else
        BlueHydra.logger.error("Error with info command... #{command.inspect}")
        errors.split("\n").each do |ln|
          BlueHydra.logger.error(ln)
        end
      end
    end
    
    # Handle l2ping errors
    def handle_l2ping_errors(errors, command)
      case errors.chomp
      when /connect: No route to host/i, /connect: Host is down/i
        # Device not reachable
      when /create connection: Input\/output error/i
        # Connection failed
      when /connect: Connection refused/i
        # Connection refused - device exists but refused
      when /connect: Permission denied/i
        # Permission issue or remote denial
      when /connect: Function not implemented/i
        # Not supported by remote device
      else
        BlueHydra.logger.error("Error with l2ping command... #{command.inspect}")
        errors.split("\n").each do |ln|
          BlueHydra.logger.error(ln)
        end
      end
    end
  end
end 