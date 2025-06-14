# Blue Hydra Benchmark Runner
# Provides framework for performance testing and comparison

require 'benchmark'
require 'json'
require 'fileutils'

module BlueHydra
  class BenchmarkRunner
    attr_reader :results, :test_name, :ruby_version, :orm_version

    def initialize(test_name = "benchmark")
      @test_name = test_name
      @ruby_version = RUBY_VERSION
      @orm_version = detect_orm_version
      @results = {
        metadata: {
          test_name: @test_name,
          ruby_version: @ruby_version,
          orm: @orm_version,
          timestamp: Time.now.to_i,
          hostname: `hostname`.strip
        },
        metrics: {}
      }
      @start_time = nil
    end

    # Start a benchmark timer
    def start_timer(metric_name)
      @start_time = Time.now
      @current_metric = metric_name
    end

    # Stop timer and record result
    def stop_timer
      elapsed = Time.now - @start_time
      record_metric(@current_metric, elapsed, 'seconds')
      elapsed
    end

    # Record a metric value
    def record_metric(name, value, unit = nil)
      @results[:metrics][name] = {
        value: value,
        unit: unit,
        timestamp: Time.now.to_i
      }
    end

    # Measure memory usage
    def measure_memory
      if File.exist?('/proc/self/status')
        status = File.read('/proc/self/status')
        if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
          return match[1].to_i * 1024  # Convert to bytes
        end
      end
      0
    end

    # Measure thread count
    def measure_threads
      Thread.list.count
    end

    # Measure CPU usage (requires previous measurement)
    def measure_cpu(previous_stat = nil)
      stat_file = "/proc/#{Process.pid}/stat"
      return nil unless File.exist?(stat_file)
      
      stats = File.read(stat_file).split
      utime = stats[13].to_i
      stime = stats[14].to_i
      total_time = utime + stime
      
      if previous_stat
        elapsed = Time.now - previous_stat[:timestamp]
        cpu_ticks = total_time - previous_stat[:total_time]
        hertz = 100  # Standard USER_HZ
        cpu_percent = (cpu_ticks.to_f / hertz / elapsed * 100).round(2)
        return { percent: cpu_percent, total_time: total_time, timestamp: Time.now }
      else
        return { total_time: total_time, timestamp: Time.now }
      end
    end

    # Run a benchmark block with automatic timing
    def benchmark(name, &block)
      memory_before = measure_memory
      threads_before = measure_threads
      cpu_before = measure_cpu
      
      result = nil
      elapsed = Benchmark.realtime do
        result = yield
      end
      
      memory_after = measure_memory
      threads_after = measure_threads
      cpu_after = measure_cpu(cpu_before)
      
      record_metric("#{name}_time", elapsed, 'seconds')
      record_metric("#{name}_memory_delta", memory_after - memory_before, 'bytes')
      record_metric("#{name}_threads_delta", threads_after - threads_before, 'threads')
      record_metric("#{name}_cpu_percent", cpu_after[:percent], '%') if cpu_after
      
      result
    end

    # Benchmark database operations
    def benchmark_database_ops(count = 1000)
      devices = []
      
      # Benchmark device creation
      benchmark("device_creation_#{count}") do
        count.times do |i|
          devices << Device.create(
            address: sprintf("AA:BB:CC:%02X:%02X:%02X", i/65536, (i/256)%256, i%256),
            name: "Test Device #{i}",
            vendor: "Test Vendor",
            last_seen: Time.now.to_i
          )
        end
      end
      
      # Benchmark device updates
      benchmark("device_updates_#{count}") do
        devices.each do |device|
          device.update(last_seen: Time.now.to_i + 60)
        end
      end
      
      # Benchmark device queries
      benchmark("device_queries") do
        # Find by address
        Device.where(address: devices.sample.address).first
        
        # Find recent devices
        Device.where(Sequel.lit('last_seen > ?', Time.now.to_i - 300)).count
        
        # Complex query
        Device.where(vendor: "Test Vendor")
              .where(Sequel.lit('last_seen > ?', Time.now.to_i - 3600))
              .order(:last_seen)
              .limit(10)
              .all
      end
      
      # Cleanup
      devices.each(&:destroy)
    end

    # Benchmark discovery simulation
    def benchmark_discovery(duration = 30)
      discovered = 0
      start_time = Time.now
      
      benchmark("discovery_simulation_#{duration}s") do
        while Time.now - start_time < duration
          # Simulate device discovery
          address = sprintf("AA:BB:CC:%02X:%02X:%02X", 
                          rand(256), rand(256), rand(256))
          
          device = Device.find_or_create(address: address) do |d|
            d.name = "Simulated Device"
            d.vendor = ["Apple", "Samsung", "Google", "Microsoft"].sample
            d.last_seen = Time.now.to_i
          end
          
          discovered += 1 if device
          sleep 0.01  # Simulate processing time
        end
      end
      
      record_metric("devices_discovered", discovered, 'devices')
      record_metric("discovery_rate", discovered.to_f / duration, 'devices/second')
    end

    # Save results to file
    def save_results(filename = nil)
      filename ||= "benchmarks/#{@test_name}_#{@orm_version}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      FileUtils.mkdir_p(File.dirname(filename))
      
      File.write(filename, JSON.pretty_generate(@results))
      filename
    end

    # Compare with previous results
    def compare_with(other_file)
      other = JSON.parse(File.read(other_file))
      comparison = {
        baseline: other['metadata'],
        current: @results[:metadata],
        metrics: {}
      }
      
      @results[:metrics].each do |metric, data|
        if other['metrics'][metric.to_s]
          baseline_value = other['metrics'][metric.to_s]['value']
          current_value = data[:value]
          
          if baseline_value.is_a?(Numeric) && current_value.is_a?(Numeric)
            diff = current_value - baseline_value
            percent_change = (diff / baseline_value * 100).round(2)
            
            comparison[:metrics][metric] = {
              baseline: baseline_value,
              current: current_value,
              difference: diff,
              percent_change: percent_change,
              improved: diff < 0  # Lower is better for time/memory
            }
          end
        end
      end
      
      comparison
    end

    # Print summary report
    def print_summary
      puts "\n=== Benchmark Results ==="
      puts "Test: #{@test_name}"
      puts "Ruby: #{@ruby_version}"
      puts "ORM: #{@orm_version}"
      puts "Time: #{Time.at(@results[:metadata][:timestamp])}"
      puts "\n--- Metrics ---"
      
      @results[:metrics].each do |metric, data|
        unit = data[:unit] ? " #{data[:unit]}" : ""
        puts "#{metric}: #{data[:value]}#{unit}"
      end
    end

    private

    def detect_orm_version
      if defined?(Sequel)
        "Sequel #{Sequel::VERSION}"
      elsif defined?(DataMapper)
        "DataMapper #{DataMapper::VERSION}"
      else
        "Unknown"
      end
    end
  end
end 