#!/usr/bin/env ruby
# Benchmark database operations - DataMapper vs Sequel

require_relative '../lib/blue_hydra'
require_relative '../lib/blue_hydra/benchmark_runner'
require 'securerandom'

class DatabaseBenchmark
  def initialize(device_count = 1000)
    @device_count = device_count
    @runner = BlueHydra::BenchmarkRunner.new("database_benchmark")
    @test_devices = []
  end

  def run
    puts "Blue Hydra Database Performance Benchmark"
    puts "Testing with #{@device_count} devices"
    puts "=" * 50
    
    # Prepare test data
    prepare_test_data
    
    # Run benchmarks
    benchmark_create_operations
    benchmark_update_operations
    benchmark_query_operations
    benchmark_bulk_operations
    benchmark_concurrent_operations
    
    # Cleanup
    cleanup_test_data
    
    # Save and display results
    filename = @runner.save_results
    puts "\nResults saved to: #{filename}"
    @runner.print_summary
  end

  private

  def prepare_test_data
    puts "\nPreparing test data..."
    @test_addresses = @device_count.times.map do |i|
      sprintf("AA:BB:CC:%02X:%02X:%02X", i/65536, (i/256)%256, i%256)
    end
    
    @test_vendors = ["Apple, Inc.", "Samsung Electronics", "Google, Inc.", 
                     "Microsoft", "Sony Corporation", "LG Electronics"]
    
    @test_names = ["iPhone", "Galaxy", "Pixel", "Surface", "Xperia", "Watch",
                   "AirPods", "Buds", "Headphones", "Speaker", "Laptop", "Tablet"]
  end

  def benchmark_create_operations
    puts "\n1. Benchmarking CREATE operations..."
    
    # Single inserts
    addresses_batch = @test_addresses[0...100]
    @runner.benchmark("create_single_100") do
      addresses_batch.each do |addr|
        device = BlueHydra::Device.create(
          address: addr,
          name: @test_names.sample,
          vendor: @test_vendors.sample,
          last_seen: Time.now.to_i,
          company: @test_vendors.sample,
          manufacturer: @test_vendors.sample,
          classic_mode: [true, false].sample,
          le_mode: [true, false].sample
        )
        @test_devices << device
      end
    end
    
    # Batch inserts using find_or_create
    addresses_batch = @test_addresses[100...500]
    @runner.benchmark("create_batch_400") do
      addresses_batch.each do |addr|
        device = BlueHydra::Device.find_or_create(address: addr) do |d|
          d.name = @test_names.sample
          d.vendor = @test_vendors.sample
          d.last_seen = Time.now.to_i
        end
        @test_devices << device
      end
    end
    
    puts "✓ Created #{@test_devices.size} devices"
  end

  def benchmark_update_operations
    puts "\n2. Benchmarking UPDATE operations..."
    
    # Single updates
    devices_to_update = @test_devices[0...100]
    @runner.benchmark("update_single_100") do
      devices_to_update.each do |device|
        device.update(
          last_seen: Time.now.to_i + 60,
          classic_rssi: ["-#{rand(40..90)} dBm"],
          le_rssi: ["-#{rand(40..90)} dBm"]
        )
      end
    end
    
    # Bulk updates using dataset
    @runner.benchmark("update_bulk_where") do
      BlueHydra::Device.where(vendor: @test_vendors.first)
                      .update(last_seen: Time.now.to_i + 120)
    end
    
    puts "✓ Update operations complete"
  end

  def benchmark_query_operations
    puts "\n3. Benchmarking QUERY operations..."
    
    # Simple queries
    @runner.benchmark("query_by_address") do
      100.times do
        addr = @test_addresses.sample
        BlueHydra::Device.where(address: addr).first
      end
    end
    
    # Complex queries with multiple conditions
    @runner.benchmark("query_complex") do
      50.times do
        devices = BlueHydra::Device
          .where(vendor: @test_vendors.sample)
          .where(Sequel.lit('last_seen > ?', Time.now.to_i - 3600))
          .order(:last_seen)
          .limit(10)
          .all
      end
    end
    
    # Count queries
    @runner.benchmark("query_count") do
      100.times do
        BlueHydra::Device.where(classic_mode: true).count
        BlueHydra::Device.where(le_mode: true).count
      end
    end
    
    # LIKE queries
    @runner.benchmark("query_like") do
      50.times do
        BlueHydra::Device.where(Sequel.like(:name, "%Phone%")).all
      end
    end
    
    puts "✓ Query operations complete"
  end

  def benchmark_bulk_operations
    puts "\n4. Benchmarking BULK operations..."
    
    # Bulk insert preparation
    bulk_data = @test_addresses[500...1000].map do |addr|
      {
        address: addr,
        name: @test_names.sample,
        vendor: @test_vendors.sample,
        last_seen: Time.now.to_i,
        created_at: Time.now,
        updated_at: Time.now
      }
    end
    
    # Bulk insert
    @runner.benchmark("bulk_insert_500") do
      if defined?(Sequel)
        # Sequel bulk insert
        BlueHydra::Device.multi_insert(bulk_data)
      else
        # DataMapper doesn't have built-in bulk insert
        bulk_data.each do |data|
          BlueHydra::Device.create(data)
        end
      end
    end
    
    # Bulk delete
    @runner.benchmark("bulk_delete") do
      BlueHydra::Device.where(Sequel.like(:address, "AA:BB:CC:00:%")).destroy
    end
    
    puts "✓ Bulk operations complete"
  end

  def benchmark_concurrent_operations
    puts "\n5. Benchmarking CONCURRENT operations..."
    
    threads = []
    errors = []
    
    @runner.benchmark("concurrent_mixed_ops") do
      # Create multiple threads doing different operations
      5.times do |i|
        threads << Thread.new do
          begin
            case i
            when 0  # Reader thread
              20.times do
                BlueHydra::Device.where(Sequel.lit('last_seen > ?', Time.now.to_i - 300)).count
                sleep 0.01
              end
            when 1  # Writer thread
              20.times do |j|
                addr = sprintf("CC:DD:EE:%02X:%02X:%02X", i, j, rand(256))
                BlueHydra::Device.find_or_create(address: addr) do |d|
                  d.name = "Concurrent Device #{i}-#{j}"
                  d.last_seen = Time.now.to_i
                end
                sleep 0.01
              end
            when 2  # Updater thread
              20.times do
                device = @test_devices.sample
                device.update(last_seen: Time.now.to_i) if device
                sleep 0.01
              end
            when 3  # Complex query thread
              20.times do
                BlueHydra::Device
                  .where(vendor: @test_vendors.sample)
                  .order(:last_seen)
                  .limit(5)
                  .all
                sleep 0.01
              end
            when 4  # Delete thread
              20.times do |j|
                addr = sprintf("DD:EE:FF:%02X:%02X:%02X", i, j, rand(256))
                device = BlueHydra::Device.where(address: addr).first
                device.destroy if device
                sleep 0.01
              end
            end
          rescue => e
            errors << e
          end
        end
      end
      
      threads.each(&:join)
    end
    
    @runner.record_metric("concurrent_errors", errors.size, "errors")
    puts "✓ Concurrent operations complete (#{errors.size} errors)"
  end

  def cleanup_test_data
    puts "\n6. Cleaning up test data..."
    
    @runner.benchmark("cleanup_operations") do
      # Delete all test devices
      @test_addresses.each_slice(100) do |batch|
        BlueHydra::Device.where(address: batch).destroy
      end
      
      # Also cleanup any concurrent test data
      BlueHydra::Device.where(Sequel.like(:address, "CC:DD:EE:%")).destroy
      BlueHydra::Device.where(Sequel.like(:address, "DD:EE:FF:%")).destroy
    end
    
    puts "✓ Cleanup complete"
  end
end

# Run the benchmark
if __FILE__ == $0
  # Parse command line arguments
  device_count = ARGV[0]&.to_i || 1000
  
  benchmark = DatabaseBenchmark.new(device_count)
  benchmark.run
end 