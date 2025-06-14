#!/usr/bin/env ruby
# Benchmark system resource usage

require_relative '../lib/blue_hydra'
require_relative '../lib/blue_hydra/benchmark_runner'

class ResourceBenchmark
  def initialize
    @runner = BlueHydra::BenchmarkRunner.new("resource_benchmark")
    @monitoring = true
  end

  def run
    puts "Blue Hydra Resource Usage Benchmark"
    puts "=" * 50
    
    # Benchmark startup resources
    benchmark_startup_resources
    
    # Benchmark idle resources
    benchmark_idle_resources
    
    # Benchmark under load
    benchmark_load_resources
    
    # Benchmark memory patterns
    benchmark_memory_patterns
    
    # Save and display results
    filename = @runner.save_results
    puts "\nResults saved to: #{filename}"
    @runner.print_summary
    
    # Generate resource graphs if possible
    generate_resource_graphs(filename)
  end

  private

  def benchmark_startup_resources
    puts "\n1. Benchmarking startup resources..."
    
    # Measure clean startup
    memory_samples = []
    cpu_samples = []
    thread_samples = []
    
    @runner.benchmark("startup_sequence") do
      # Initial state
      memory_samples << @runner.measure_memory
      thread_samples << @runner.measure_threads
      
      # Require main library
      require_relative '../lib/blue_hydra'
      memory_samples << @runner.measure_memory
      thread_samples << @runner.measure_threads
      
      # Initialize database
      BlueHydra::Device.db
      memory_samples << @runner.measure_memory
      thread_samples << @runner.measure_threads
      
      # Start thread manager
      thread_manager = BlueHydra::ThreadManager.new
      memory_samples << @runner.measure_memory
      thread_samples << @runner.measure_threads
    end
    
    @runner.record_metric("startup_memory_initial", memory_samples.first, "bytes")
    @runner.record_metric("startup_memory_final", memory_samples.last, "bytes")
    @runner.record_metric("startup_memory_growth", memory_samples.last - memory_samples.first, "bytes")
    @runner.record_metric("startup_threads_initial", thread_samples.first, "threads")
    @runner.record_metric("startup_threads_final", thread_samples.last, "threads")
    
    puts "✓ Startup resource benchmarks complete"
  end

  def benchmark_idle_resources
    puts "\n2. Benchmarking idle resources..."
    
    samples = []
    start_time = Time.now
    
    # Monitor for 30 seconds
    @runner.benchmark("idle_monitoring_30s") do
      cpu_stat = @runner.measure_cpu
      
      while Time.now - start_time < 30
        samples << {
          time: Time.now - start_time,
          memory: @runner.measure_memory,
          threads: @runner.measure_threads,
          cpu: @runner.measure_cpu(cpu_stat)
        }
        cpu_stat = samples.last[:cpu]
        sleep 1
      end
    end
    
    # Calculate statistics
    memory_values = samples.map { |s| s[:memory] }
    thread_values = samples.map { |s| s[:threads] }
    cpu_values = samples.map { |s| s[:cpu][:percent] }.compact
    
    @runner.record_metric("idle_memory_avg", average(memory_values), "bytes")
    @runner.record_metric("idle_memory_min", memory_values.min, "bytes")
    @runner.record_metric("idle_memory_max", memory_values.max, "bytes")
    @runner.record_metric("idle_threads_avg", average(thread_values), "threads")
    @runner.record_metric("idle_cpu_avg", average(cpu_values), "%")
    
    puts "✓ Idle resource benchmarks complete"
  end

  def benchmark_load_resources
    puts "\n3. Benchmarking resources under load..."
    
    samples = []
    errors = 0
    
    @runner.benchmark("load_test_60s") do
      # Start monitoring thread
      monitor_thread = Thread.new do
        cpu_stat = @runner.measure_cpu
        while @monitoring
          samples << {
            memory: @runner.measure_memory,
            threads: @runner.measure_threads,
            cpu: @runner.measure_cpu(cpu_stat)
          }
          cpu_stat = samples.last[:cpu]
          sleep 0.5
        end
      end
      
      # Create load
      load_threads = []
      
      # Database load
      load_threads << Thread.new do
        begin
          1000.times do |i|
            addr = sprintf("EE:FF:00:%02X:%02X:%02X", i/65536, (i/256)%256, i%256)
            BlueHydra::Device.find_or_create(address: addr) do |d|
              d.name = "Load Test Device #{i}"
              d.last_seen = Time.now.to_i
            end
            sleep 0.001
          end
        rescue => e
          errors += 1
        end
      end
      
      # Query load
      3.times do
        load_threads << Thread.new do
          begin
            500.times do
              BlueHydra::Device.where(Sequel.lit('last_seen > ?', Time.now.to_i - 300)).count
              sleep 0.01
            end
          rescue => e
            errors += 1
          end
        end
      end
      
      # Wait for load threads
      load_threads.each(&:join)
      
      # Stop monitoring
      @monitoring = false
      monitor_thread.join
    end
    
    # Calculate peak values
    memory_values = samples.map { |s| s[:memory] }
    thread_values = samples.map { |s| s[:threads] }
    cpu_values = samples.map { |s| s[:cpu][:percent] }.compact
    
    @runner.record_metric("load_memory_peak", memory_values.max || 0, "bytes")
    @runner.record_metric("load_memory_avg", average(memory_values), "bytes")
    @runner.record_metric("load_threads_peak", thread_values.max || 0, "threads")
    @runner.record_metric("load_threads_avg", average(thread_values), "threads")
    @runner.record_metric("load_cpu_peak", cpu_values.max || 0, "%")
    @runner.record_metric("load_cpu_avg", average(cpu_values), "%")
    @runner.record_metric("load_errors", errors, "errors")
    
    puts "✓ Load resource benchmarks complete"
  end

  def benchmark_memory_patterns
    puts "\n4. Benchmarking memory patterns..."
    
    # Test memory allocation/deallocation patterns
    memory_checkpoints = []
    
    @runner.benchmark("memory_allocation_pattern") do
      # Baseline
      GC.start
      memory_checkpoints << { label: "baseline", memory: @runner.measure_memory }
      
      # Allocate devices
      devices = []
      1000.times do |i|
        devices << BlueHydra::Device.new(
          address: sprintf("FF:00:11:%02X:%02X:%02X", i/65536, (i/256)%256, i%256),
          name: "Memory Test #{i}"
        )
      end
      memory_checkpoints << { label: "after_allocation", memory: @runner.measure_memory }
      
      # Force garbage collection
      devices = nil
      GC.start
      memory_checkpoints << { label: "after_gc", memory: @runner.measure_memory }
      
      # Simulate discovery data
      discovery_data = []
      1000.times do
        discovery_data << {
          address: SecureRandom.hex(6).upcase.scan(/../).join(':'),
          rssi: rand(-90..-40),
          name: "Device #{rand(1000)}",
          timestamp: Time.now.to_i
        }
      end
      memory_checkpoints << { label: "discovery_data", memory: @runner.measure_memory }
      
      # Clear and GC
      discovery_data = nil
      GC.start
      memory_checkpoints << { label: "final_gc", memory: @runner.measure_memory }
    end
    
    # Record memory pattern metrics
    baseline = memory_checkpoints.first[:memory]
    memory_checkpoints.each do |checkpoint|
      @runner.record_metric("memory_#{checkpoint[:label]}", checkpoint[:memory], "bytes")
      @runner.record_metric("memory_#{checkpoint[:label]}_delta", checkpoint[:memory] - baseline, "bytes")
    end
    
    puts "✓ Memory pattern benchmarks complete"
  end

  def average(values)
    return 0 if values.empty?
    values.sum.to_f / values.size
  end

  def generate_resource_graphs(results_file)
    puts "\n5. Generating resource graphs..."
    
    # Create a simple CSV for graphing
    csv_file = results_file.sub('.json', '.csv')
    results = JSON.parse(File.read(results_file))
    
    File.open(csv_file, 'w') do |f|
      f.puts "Metric,Value,Unit"
      results['metrics'].each do |metric, data|
        f.puts "#{metric},#{data['value']},#{data['unit'] || 'n/a'}"
      end
    end
    
    puts "✓ CSV data exported to: #{csv_file}"
    puts "  Use your favorite graphing tool to visualize the results"
  end
end

# Run the benchmark
if __FILE__ == $0
  benchmark = ResourceBenchmark.new
  benchmark.run
end 