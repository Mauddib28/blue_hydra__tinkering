#!/usr/bin/env ruby
# Test script to check Pulse module loading

puts "Ruby version: #{RUBY_VERSION}"
puts "Working directory: #{Dir.pwd}"
puts ""

# Add lib to load path
$:.unshift(File.expand_path('lib', __dir__))

begin
  puts "Loading basic dependencies..."
  require 'logger'
  require 'yaml'
  require 'open3'
  puts "✓ Basic dependencies loaded"
  
  puts "\nSimulating the blue_hydra.rb loading sequence..."
  
  # This simulates what happens at the top of blue_hydra.rb
  module BlueHydra
    CONFIG_FILE = File.expand_path('../blue_hydra.yml', __dir__)
    DEFAULT_CONFIG = {
      "log_level" => "info",
      "bt_device" => "hci0"
    }
    
    @@config = if File.exist?(CONFIG_FILE)
                 YAML.load(File.read(CONFIG_FILE)) || DEFAULT_CONFIG
               else
                 DEFAULT_CONFIG
               end
    
    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::INFO
    
    def self.logger
      @@logger
    end
    
    def self.config
      @@config
    end
    
    def self.daemon_mode
      false
    end
  end
  
  puts "✓ BlueHydra module initialized"
  
  puts "\nBefore loading Pulse, testing what happens if MAC enumeration fails..."
  
  # This simulates the error at line 365 where Pulse is called before being loaded
  begin
    # Simulate failure
    raise "Simulated MAC enumeration failure"
  rescue => e
    puts "Caught error: #{e.message}"
    puts "Now trying to call BlueHydra::Pulse.send_event (which isn't loaded yet)..."
    begin
      BlueHydra::Pulse.send_event("blue_hydra", {
        key: 'test',
        title: 'Test',
        message: 'Test message',
        severity: 'FATAL'
      })
    rescue NameError => ne
      puts "ERROR: #{ne.class} - #{ne.message}"
      puts "This is the issue! Pulse module is called before being required!"
    end
  end
  
  puts "\nNow loading modules in correct order..."
  
  # Load in the correct order
  require 'blue_hydra/btmon_handler'
  puts "✓ btmon_handler loaded"
  
  require 'blue_hydra/parser'
  puts "✓ parser loaded"
  
  require 'blue_hydra/pulse'
  puts "✓ pulse loaded"
  
  puts "\nNow Pulse module is available:"
  puts "BlueHydra::Pulse class: #{BlueHydra::Pulse.class}"
  
rescue => e
  puts "ERROR: #{e.class} - #{e.message}"
  puts "Backtrace:"
  e.backtrace.each { |line| puts "  #{line}" }
  exit 1
end

puts "\nTest completed!" 