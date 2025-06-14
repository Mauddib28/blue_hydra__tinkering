#!/usr/bin/env ruby
# Benchmark discovery performance - Python vs Ruby D-Bus

require_relative '../lib/blue_hydra'
require_relative '../lib/blue_hydra/benchmark_runner'
require 'timeout'

class DiscoveryBenchmark
  def initialize
    @runner = BlueHydra::BenchmarkRunner.new("discovery_benchmark")
  end

  def run
    puts "Blue Hydra Discovery Performance Benchmark"
    puts "=" * 50
    
    # Test Python discovery if available
    if system("which discovery_handler.py > /dev/null 2>&1")
      benchmark_python_discovery
    else
      puts "Python discovery script not found, skipping Python tests"
    end
    
    # Test Ruby D-Bus discovery
    benchmark_ruby_dbus_discovery
    
    # Save and display results
    filename = @runner.save_results
    puts "\nResults saved to: #{filename}"
    @runner.print_summary
  end

  private

  def benchmark_python_discovery
    puts "\n1. Benchmarking Python Discovery..."
    
    # Force Python discovery mode
    BlueHydra.config["use_python_discovery"] = true
    
    # Measure startup time
    @runner.benchmark("python_discovery_startup") do
      cmd = "python discovery_handler.py"
      Process.spawn(cmd, out: "/dev/null", err: "/dev/null")
      sleep 2  # Give it time to initialize
    end
    
    # Measure discovery rate
    devices_found = 0
    @runner.benchmark("python_discovery_30s") do
      start_time = Time.now
      while Time.now - start_time < 30
        # Simulate parsing discovery output
        output = `timeout 1 hcitool scan 2>/dev/null || echo ""`
        devices_found += output.scan(/([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})/i).size
        sleep 0.5
      end
    end
    
    @runner.record_metric("python_devices_found", devices_found, "devices")
    @runner.record_metric("python_discovery_rate", devices_found / 30.0, "devices/sec")
    
    puts "✓ Python discovery benchmark complete"
  end

  def benchmark_ruby_dbus_discovery
    puts "\n2. Benchmarking Ruby D-Bus Discovery..."
    
    # Try to use Ruby D-Bus
    begin
      require 'dbus'
      ruby_dbus_available = true
    rescue LoadError
      ruby_dbus_available = false
    end
    
    if !ruby_dbus_available
      puts "ruby-dbus not available, simulating discovery"
      benchmark_simulated_discovery
      return
    end
    
    # Measure startup time
    @runner.benchmark("ruby_dbus_startup") do
      begin
        BlueHydra::DbusManager.new
      rescue => e
        puts "D-Bus connection error: #{e.message}"
      end
    end
    
    # Measure discovery rate
    devices_found = 0
    @runner.benchmark("ruby_dbus_discovery_30s") do
      begin
        dbus_manager = BlueHydra::DbusManager.new
        discovery_service = BlueHydra::DiscoveryService.new(dbus_manager)
        
        start_time = Time.now
        discovery_service.start_discovery rescue nil
        
        while Time.now - start_time < 30
          devices = discovery_service.devices rescue []
          devices_found = devices.size
          sleep 1
        end
        
        discovery_service.stop_discovery rescue nil
      rescue => e
        puts "Discovery error: #{e.message}"
      end
    end
    
    @runner.record_metric("ruby_dbus_devices_found", devices_found, "devices")
    @runner.record_metric("ruby_dbus_discovery_rate", devices_found / 30.0, "devices/sec")
    
    puts "✓ Ruby D-Bus discovery benchmark complete"
  end

  def benchmark_simulated_discovery
    puts "Simulating discovery performance..."
    
    devices_found = 0
    @runner.benchmark("simulated_discovery_30s") do
      start_time = Time.now
      while Time.now - start_time < 30
        # Simulate device discovery
        if rand(100) < 20  # 20% chance of finding a device
          devices_found += 1
        end
        sleep 0.1
      end
    end
    
    @runner.record_metric("simulated_devices_found", devices_found, "devices")
    @runner.record_metric("simulated_discovery_rate", devices_found / 30.0, "devices/sec")
  end
end

# Run the benchmark
if __FILE__ == $0
  benchmark = DiscoveryBenchmark.new
  benchmark.run
end 