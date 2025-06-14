#!/usr/bin/env ruby
# Run performance benchmarks for Blue Hydra

require_relative '../lib/blue_hydra'
require_relative '../lib/blue_hydra/benchmark_runner'

# Parse command line arguments
require 'optparse'

options = {
  test_name: 'full_benchmark',
  device_count: 1000,
  discovery_duration: 30,
  compare_with: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: run_benchmarks.rb [options]"
  
  opts.on("-n", "--name NAME", "Test name (default: full_benchmark)") do |n|
    options[:test_name] = n
  end
  
  opts.on("-d", "--devices COUNT", Integer, "Number of devices for DB test (default: 1000)") do |d|
    options[:device_count] = d
  end
  
  opts.on("-t", "--time SECONDS", Integer, "Discovery test duration (default: 30)") do |t|
    options[:discovery_duration] = t
  end
  
  opts.on("-c", "--compare FILE", "Compare with previous results") do |c|
    options[:compare_with] = c
  end
  
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Initialize benchmark runner
runner = BlueHydra::BenchmarkRunner.new(options[:test_name])

puts "Starting Blue Hydra Performance Benchmarks"
puts "Ruby Version: #{RUBY_VERSION}"
puts "ORM: #{runner.orm_version}"
puts "-" * 50

# 1. Startup benchmarks
puts "\n1. Testing startup performance..."
runner.start_timer("startup_time")
require_relative '../lib/blue_hydra'
runner.stop_timer
puts "✓ Startup time recorded"

# 2. Database benchmarks
puts "\n2. Testing database performance (#{options[:device_count]} devices)..."
runner.benchmark_database_ops(options[:device_count])
puts "✓ Database operations benchmarked"

# 3. Discovery simulation
puts "\n3. Testing discovery performance (#{options[:discovery_duration]}s)..."
runner.benchmark_discovery(options[:discovery_duration])
puts "✓ Discovery simulation completed"

# 4. Memory and thread benchmarks
puts "\n4. Testing resource usage..."
runner.record_metric("baseline_memory", runner.measure_memory, "bytes")
runner.record_metric("baseline_threads", runner.measure_threads, "threads")

# Simulate workload
runner.benchmark("workload_simulation") do
  threads = []
  5.times do |i|
    threads << Thread.new do
      100.times do
        BlueHydra::Device.where(Sequel.lit('last_seen > ?', Time.now.to_i - 300)).count
        sleep 0.01
      end
    end
  end
  threads.each(&:join)
end

runner.record_metric("peak_memory", runner.measure_memory, "bytes")
runner.record_metric("peak_threads", runner.measure_threads, "threads")
puts "✓ Resource usage measured"

# 5. Save results
filename = runner.save_results
puts "\n5. Results saved to: #{filename}"

# 6. Print summary
runner.print_summary

# 7. Compare with previous results if specified
if options[:compare_with] && File.exist?(options[:compare_with])
  puts "\n=== Comparison with #{File.basename(options[:compare_with])} ==="
  comparison = runner.compare_with(options[:compare_with])
  
  comparison[:metrics].each do |metric, data|
    status = data[:improved] ? "✓" : "✗"
    direction = data[:percent_change] > 0 ? "↑" : "↓"
    
    puts "#{status} #{metric}: #{data[:current]} (#{direction} #{data[:percent_change]}%)"
  end
end

puts "\nBenchmark complete!" 