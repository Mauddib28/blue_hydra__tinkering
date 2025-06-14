#!/usr/bin/env ruby

puts "Ruby version: #{RUBY_VERSION}"
puts "Loading Blue Hydra components..."

begin
  # Set env for testing to avoid MAC address lookup
  ENV["BLUE_HYDRA"] = "test"
  
  # Load required gems first
  require 'sequel'
  puts "Sequel loaded successfully"
  
  # Test database connection
  db_path = ':memory:'
  db = Sequel.sqlite(db_path)
  puts "Test database connection successful"
  
  # Test loading the models directory
  $LOAD_PATH.unshift(File.expand_path('lib', __dir__))
  
  # Try to load SequelDB first
  require 'blue_hydra/sequel_db'
  puts "SequelDB loaded successfully"
  
  # Connect to database
  BlueHydra::SequelDB.connect!
  puts "Database connected"
  
  # Run migrations
  BlueHydra::SequelDB.migrate!
  puts "Migrations completed"
  
  # Set Sequel::Model.db
  Sequel::Model.db = BlueHydra::SequelDB.db
  puts "Sequel::Model.db set"
  
  # Now try to load models
  require 'blue_hydra/models/sequel_base'
  puts "SequelBase loaded"
  
  require 'blue_hydra/models/sync_version'
  puts "SyncVersion model loaded"
  
  require 'blue_hydra/models/device'
  puts "Device model loaded"
  
  puts "\nAll components loaded successfully!"
  
rescue SystemExit => e
  puts "System exit called with code: #{e.status}"
  puts "Preventing exit to see full error..."
  raise
rescue => e
  puts "\nError loading Blue Hydra:"
  puts "#{e.class}: #{e.message}"
  puts "\nBacktrace:"
  e.backtrace.each { |line| puts "  #{line}" }
end 