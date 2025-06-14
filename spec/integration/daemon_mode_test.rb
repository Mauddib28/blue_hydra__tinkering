#!/usr/bin/env ruby
# encoding: UTF-8
require_relative '../../lib/blue_hydra/data_objects_patch'
require_relative '../../lib/blue_hydra'

# Test daemon mode operation
puts "Testing Blue Hydra daemon mode with Ruby #{RUBY_VERSION}"

# Set daemon mode
BlueHydra.daemon_mode = true
puts "Daemon mode set: #{BlueHydra.daemon_mode}"

# Test PID file creation
pid_file = '/tmp/blue_hydra_test.pid'
File.write(pid_file, Process.pid)
puts "PID file created: #{File.exist?(pid_file)}"

# Test logging
BlueHydra.logger.info("Test message from daemon mode")
BlueHydra.logger.error("Test error from daemon mode")

# Check if log file exists
log_path = BlueHydra::LOGFILE
puts "Log file path: #{log_path}"
puts "Log file exists: #{File.exist?(log_path)}"

if File.exist?(log_path)
  # Check last few lines
  last_lines = `tail -n 5 #{log_path}`.chomp
  puts "Last log entries:"
  puts last_lines
end

# Test signal handling
Signal.trap('INT') do
  puts "SIGINT received, cleaning up..."
  File.unlink(pid_file) if File.exist?(pid_file)
  exit 0
end

Signal.trap('HUP') do
  puts "SIGHUP received, would rotate logs..."
  BlueHydra.initialize_logger
  BlueHydra.update_logger
end

# Test that console output is suppressed
puts "Testing console suppression..."
old_stdout = $stdout
$stdout = StringIO.new

BlueHydra.logger.info("This should not appear in console")

captured_output = $stdout.string
$stdout = old_stdout

puts "Console output suppressed: #{captured_output.empty?}"

# Clean up
File.unlink(pid_file) if File.exist?(pid_file)

puts "\nDaemon mode test complete!" 