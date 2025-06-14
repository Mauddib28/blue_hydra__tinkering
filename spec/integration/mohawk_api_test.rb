#!/usr/bin/env ruby
# encoding: UTF-8
require 'json'
require 'tempfile'
require 'fileutils'

# Test Mohawk API functionality
puts "Testing Blue Hydra Mohawk API with Ruby #{RUBY_VERSION}"

# Mock runner for testing
class MockRunner
  attr_accessor :api_thread, :processing_speed, :stunned
  attr_accessor :result_queue, :info_scan_queue, :l2ping_queue
  attr_accessor :cui_status, :scanner_status
  
  def initialize
    @processing_speed = 12.5
    @stunned = false
    @result_queue = Queue.new
    @info_scan_queue = Queue.new
    @l2ping_queue = Queue.new
    @scanner_status = { test_discovery: Time.now.to_i, ubertooth: Time.now.to_i }
    
    # Mock device data for CUI
    @cui_status = {
      "uuid-1" => {
        uuid: "uuid-1",
        address: "AA:BB:CC:DD:EE:01",
        name: "iPhone",
        vendor: "Apple, Inc.",
        status: "online",
        last_seen: Time.now.to_i - 30,
        created: Time.now.to_i - 120,
        rssi: "-42",
        vers: "CL4.2"
      },
      "uuid-2" => {
        uuid: "uuid-2", 
        address: "AA:BB:CC:DD:EE:02",
        name: "Fitbit",
        vendor: "Fitbit, Inc.",
        status: "online",
        last_seen: Time.now.to_i - 10,
        created: Time.now.to_i - 60,
        rssi: "-55",
        vers: "LE4.0",
        le_proximity_uuid: "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
        le_major_num: "1",
        le_minor_num: "100"
      }
    }
  end
end

# Mock CliUserInterface for testing
class MockCliUserInterface
  attr_accessor :runner
  
  def initialize(runner)
    @runner = runner
  end
  
  def cui_status
    @runner.cui_status
  end
  
  def result_queue
    @runner.result_queue
  end
  
  def info_scan_queue
    @runner.info_scan_queue.length
  end
  
  def l2ping_queue
    @runner.l2ping_queue
  end
  
  # Simplified api_loop for testing
  def api_loop(output_path)
    begin
      3.times do |i|
        # Write device data to JSON file
        File.write(output_path, JSON.generate(cui_status))
        
        # Also write internal status
        internal_path = output_path.sub('.json', '_internal.json')
        File.write(internal_path, JSON.generate({
          processing_speed: "#{@runner.processing_speed.round}/s",
          db_stunned: @runner.stunned,
          result_queue: result_queue.length,
          info_scan_queue: info_scan_queue,
          l2ping_queue: l2ping_queue.length
        }))
        
        puts "Iteration #{i + 1}: Wrote JSON files"
        sleep 0.5
      end
    rescue => e
      puts "API loop error: #{e.message}"
    end
  end
end

# Create test directory
test_dir = "/tmp/blue_hydra_test_#{$$}"
FileUtils.mkdir_p(test_dir)
output_path = File.join(test_dir, "blue_hydra.json")
internal_path = File.join(test_dir, "blue_hydra_internal.json")

puts "\nTest output directory: #{test_dir}"

# Run the test
runner = MockRunner.new
api = MockCliUserInterface.new(runner)

# Test 1: Run api_loop and check files
puts "\nTest 1: Running api_loop..."
api.api_loop(output_path)

# Test 2: Verify JSON file exists and is valid
if File.exist?(output_path)
  puts "\nTest 2: Checking main JSON file..."
  content = File.read(output_path)
  data = JSON.parse(content)
  
  puts "Success! Found #{data.keys.length} devices in JSON"
  first_device = data.values.first
  puts "First device: #{first_device['name']} (#{first_device['address']})"
  puts "RSSI: #{first_device['rssi']}, Version: #{first_device['vers']}"
else
  puts "Test 2 failed: JSON file not created"
end

# Test 3: Verify internal JSON file
if File.exist?(internal_path)
  puts "\nTest 3: Checking internal JSON file..."
  content = File.read(internal_path)
  data = JSON.parse(content)
  
  puts "Success! Internal status:"
  puts "- Processing speed: #{data['processing_speed']}"
  puts "- DB stunned: #{data['db_stunned']}"
  puts "- Queue lengths: result=#{data['result_queue']}, info_scan=#{data['info_scan_queue']}, l2ping=#{data['l2ping_queue']}"
else
  puts "Test 3 failed: Internal JSON file not created"
end

# Test 4: Verify JSON format matches expected structure
puts "\nTest 4: Verifying JSON structure..."
content = File.read(output_path)
data = JSON.parse(content)
device = data.values.first

expected_keys = %w[uuid address name vendor status last_seen created rssi vers]
missing_keys = expected_keys - device.keys
if missing_keys.empty?
  puts "Success! All expected keys present in device data"
else
  puts "Missing keys: #{missing_keys.join(', ')}"
end

# Clean up
FileUtils.rm_rf(test_dir)
puts "\nMohawk API test complete!" 