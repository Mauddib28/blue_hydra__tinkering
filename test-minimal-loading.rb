#!/usr/bin/env ruby

puts "Ruby version: #{RUBY_VERSION}"

# Set test mode
ENV['BLUE_HYDRA'] = 'test'

# Add lib to load path
$:.unshift(File.dirname(File.expand_path('../lib/blue_hydra.rb', __FILE__)))

begin
  puts "Step 1: Loading YAML..."
  require 'yaml'
  puts "YAML loaded"

  puts "Step 2: Loading Logger..."
  require 'logger'
  puts "Logger loaded"

  puts "Step 3: Testing if blue_hydra.rb exists..."
  if File.exist?('lib/blue_hydra.rb')
    puts "File exists: lib/blue_hydra.rb"
  else
    puts "ERROR: File not found: lib/blue_hydra.rb"
    exit 1
  end

  puts "Step 4: Loading blue_hydra.rb..."
  # Use load instead of require to see errors
  load 'lib/blue_hydra.rb'

  puts "Blue Hydra loaded successfully!"
  puts "LOCAL_ADAPTER_ADDRESS: #{BlueHydra::LOCAL_ADAPTER_ADDRESS}"
  puts "SYNC_VERSION: #{BlueHydra::SYNC_VERSION}"
  
rescue SystemExit => e
  puts "SystemExit caught with status: #{e.status}"
  raise
rescue => e
  puts "Error: #{e.class}: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(10).each { |line| puts "  #{line}" }
end 