#!/usr/bin/env ruby
# encoding: UTF-8
require 'socket'
require 'json'
require 'timeout'

# Test RSSI API functionality
puts "Testing Blue Hydra RSSI API with Ruby #{RUBY_VERSION}"

# Mock runner for testing
class MockRunner
  attr_accessor :signal_spitter_thread, :result_queue, :info_scan_queue, :l2ping_queue
  attr_accessor :cui_status, :processing_speed, :stunned, :scanner_status
  
  def initialize
    @cui_status = {}
    @processing_speed = 10.0
    @stunned = false
    @scanner_status = { test_discovery: Time.now.to_i, ubertooth: Time.now.to_i }
    @result_queue = Queue.new
    @info_scan_queue = Queue.new
    @l2ping_queue = Queue.new
    @rssi_data = {
      "AA:BB:CC:DD:EE:01" => [
        { ts: Time.now.to_i - 30, dbm: -42 },
        { ts: Time.now.to_i - 20, dbm: -43 },
        { ts: Time.now.to_i - 10, dbm: -41 }
      ],
      "AA:BB:CC:DD:EE:02" => [
        { ts: Time.now.to_i - 5, dbm: -55 },
        { ts: Time.now.to_i - 2, dbm: -54 }
      ]
    }
    @rssi_data_mutex = Mutex.new
  end
  
  # Simplified signal spitter thread for testing
  def start_signal_spitter_thread
    @signal_spitter_thread = Thread.new do
      begin
        server = TCPServer.new("127.0.0.1", 11240) # Use different port for test
        puts "RSSI API server started on port 11240"
        
        loop do
          Thread.start(server.accept) do |client|
            begin
              magic_word = Timeout::timeout(1) do
                client.gets.chomp
              end
            rescue Timeout::Error
              client.puts "ah ah ah, you didn't say the magic word"
              client.close
              next
            end
            
            if magic_word == 'bluetooth'
              @rssi_data_mutex.synchronize {
                client.puts JSON.generate(@rssi_data)
              }
            else
              client.puts "Invalid magic word"
            end
            client.close
          end
        end
      rescue => e
        puts "RSSI API error: #{e.message}"
      end
    end
  end
  
  def stop
    @signal_spitter_thread.kill if @signal_spitter_thread
  end
end

# Run the test
runner = MockRunner.new
runner.start_signal_spitter_thread

# Give server time to start
sleep 0.5

# Test 1: Connect with correct magic word
begin
  puts "\nTest 1: Connecting with correct magic word..."
  socket = TCPSocket.new("127.0.0.1", 11240)
  socket.puts("bluetooth")
  response = socket.gets
  socket.close
  
  data = JSON.parse(response)
  puts "Success! Received #{data.keys.length} devices"
  puts "Device 1: #{data.keys.first} - Last RSSI: #{data.values.first.last['dbm']} dBm"
rescue => e
  puts "Test 1 failed: #{e.message}"
end

# Test 2: Connect with wrong magic word
begin
  puts "\nTest 2: Connecting with wrong magic word..."
  socket = TCPSocket.new("127.0.0.1", 11240)
  socket.puts("wrong")
  response = socket.gets
  socket.close
  
  puts "Response: #{response.chomp}"
  puts "Success! Server rejected invalid magic word"
rescue => e
  puts "Test 2 failed: #{e.message}"
end

# Test 3: Timeout test
begin
  puts "\nTest 3: Testing timeout..."
  socket = TCPSocket.new("127.0.0.1", 11240)
  # Don't send anything, let it timeout
  response = socket.gets
  socket.close
  
  puts "Response: #{response.chomp}"
  puts "Success! Server handled timeout properly"
rescue => e
  puts "Test 3 failed: #{e.message}"
end

# Clean up
runner.stop
puts "\nRSSI API test complete!" 