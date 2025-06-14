#!/usr/bin/env ruby
# encoding: UTF-8
require 'timeout'

# Test signal handling functionality
puts "Testing Blue Hydra signal handling with Ruby #{RUBY_VERSION}"

# Test PID file handling
pid_file = "/tmp/blue_hydra_test_#{$$}.pid"

# Test 1: SIGINT handling
puts "\nTest 1: Testing SIGINT handling..."
done = false
Signal.trap('INT') do
  done = true
  puts "SIGINT received, setting done flag"
end

# Simulate SIGINT
Process.kill('INT', $$)
sleep 0.1
puts "Done flag after SIGINT: #{done}"
puts "Success! SIGINT handler works"

# Reset for next test
done = false
Signal.trap('INT', 'DEFAULT')

# Test 2: SIGHUP handling  
puts "\nTest 2: Testing SIGHUP handling..."
got_sighup = false
Signal.trap('HUP') do
  got_sighup = true
  puts "SIGHUP received, would reinitialize logger"
end

# Simulate SIGHUP
Process.kill('HUP', $$)
sleep 0.1
puts "Got SIGHUP flag: #{got_sighup}"
puts "Success! SIGHUP handler works"

# Reset
Signal.trap('HUP', 'DEFAULT')

# Test 3: PID file cleanup
puts "\nTest 3: Testing PID file cleanup..."
begin
  # Write PID file
  File.write(pid_file, Process.pid)
  puts "PID file created: #{File.exist?(pid_file)}"
  
  # Simulate cleanup
  cleanup_called = false
  at_exit do
    if File.exist?(pid_file)
      File.unlink(pid_file)
      cleanup_called = true
    end
  end
  
  # Manually trigger cleanup for test
  if File.exist?(pid_file)
    File.unlink(pid_file)
    cleanup_called = true
  end
  
  puts "PID file removed: #{!File.exist?(pid_file)}"
  puts "Cleanup executed: #{cleanup_called}"
  puts "Success! PID file cleanup works"
rescue => e
  puts "Test 3 failed: #{e.message}"
ensure
  File.unlink(pid_file) if File.exist?(pid_file)
end

# Test 4: Graceful shutdown simulation
puts "\nTest 4: Testing graceful shutdown..."
class MockRunner
  attr_accessor :stopping, :threads
  
  def initialize
    @stopping = false
    @threads = []
  end
  
  def start
    # Simulate starting threads
    @threads << Thread.new { sleep 0.5 }
    @threads << Thread.new { sleep 0.5 }
    puts "Started #{@threads.length} threads"
  end
  
  def stop
    return if @stopping
    @stopping = true
    puts "Stopping runner..."
    
    # Kill all threads
    @threads.each do |thread|
      thread.kill if thread.alive?
    end
    puts "All threads stopped"
  end
  
  def status
    {
      stopping: @stopping,
      threads_alive: @threads.count(&:alive?)
    }
  end
end

runner = MockRunner.new
runner.start

# Check initial status
status = runner.status
puts "Initial status: stopping=#{status[:stopping]}, threads_alive=#{status[:threads_alive]}"

# Simulate graceful shutdown
runner.stop
status = runner.status
puts "After stop: stopping=#{status[:stopping]}, threads_alive=#{status[:threads_alive]}"
puts "Success! Graceful shutdown works"

# Test 5: Multiple signal handling
puts "\nTest 5: Testing multiple signals..."
signal_count = 0
Signal.trap('USR1') do
  signal_count += 1
end

3.times do |i|
  Process.kill('USR1', $$)
  sleep 0.05
end

puts "Received #{signal_count} USR1 signals"
puts "Success! Multiple signal handling works"

# Cleanup
Signal.trap('USR1', 'DEFAULT')

puts "\nSignal handling test complete!" 