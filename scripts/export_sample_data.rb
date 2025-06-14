#!/usr/bin/env ruby
# Script to export sample data from Blue Hydra database for migration testing

require 'json'
require 'fileutils'

# Set environment to avoid bluetooth initialization
ENV["BLUE_HYDRA"] = "test"

require_relative '../lib/blue_hydra'

# Output directory
output_dir = File.join(File.dirname(__FILE__), '..', 'test_data')
FileUtils.mkdir_p(output_dir)

puts "Blue Hydra Sample Data Exporter"
puts "================================"

# Check if database exists
unless File.exist?(BlueHydra::DB_PATH)
  puts "Error: Database not found at #{BlueHydra::DB_PATH}"
  puts "Please run Blue Hydra first to create a database with sample data."
  exit 1
end

# Export configuration
SAMPLE_SIZE = ENV['SAMPLE_SIZE'] || 100
INCLUDE_OFFLINE = ENV['INCLUDE_OFFLINE'] || false

puts "Exporting up to #{SAMPLE_SIZE} devices..."

# Connect to database
DataMapper.setup(:default, "sqlite://#{BlueHydra::DB_PATH}")

# Export devices
devices_data = {
  metadata: {
    export_date: Time.now.iso8601,
    blue_hydra_version: BlueHydra::VERSION,
    sample_size: SAMPLE_SIZE,
    include_offline: INCLUDE_OFFLINE
  },
  devices: []
}

# Query devices
query_opts = { limit: SAMPLE_SIZE.to_i }
query_opts[:status] = 'online' unless INCLUDE_OFFLINE

BlueHydra::Device.all(query_opts).each do |device|
  device_hash = {
    # Core attributes
    id: device.id,
    uuid: device.uuid,
    address: device.address,
    name: device.name,
    status: device.status,
    vendor: device.vendor,
    uap_lap: device.uap_lap,
    
    # Mode flags
    classic_mode: device.classic_mode,
    le_mode: device.le_mode,
    
    # Timestamps
    created_at: device.created_at&.iso8601,
    updated_at: device.updated_at&.iso8601,
    last_seen: device.last_seen,
    
    # Classic attributes (if applicable)
    classic_attributes: {}
  }
  
  if device.classic_mode
    device_hash[:classic_attributes] = {
      major_class: device.classic_major_class,
      minor_class: device.classic_minor_class,
      service_uuids: JSON.parse(device.classic_service_uuids || '[]'),
      rssi: JSON.parse(device.classic_rssi || '[]'),
      features: JSON.parse(device.classic_features || '[]')
    }
  end
  
  # LE attributes (if applicable)
  if device.le_mode
    device_hash[:le_attributes] = {
      address_type: device.le_address_type,
      service_uuids: JSON.parse(device.le_service_uuids || '[]'),
      rssi: JSON.parse(device.le_rssi || '[]'),
      flags: JSON.parse(device.le_flags || '[]')
    }
    
    # iBeacon data if present
    if device.le_proximity_uuid
      device_hash[:le_attributes][:ibeacon] = {
        proximity_uuid: device.le_proximity_uuid,
        major: device.le_major_num,
        minor: device.le_minor_num,
        company: device.company
      }
    end
  end
  
  devices_data[:devices] << device_hash
end

# Export sync versions
sync_versions = BlueHydra::SyncVersion.all.map do |sv|
  { id: sv.id, version: sv.version }
end

devices_data[:sync_versions] = sync_versions

# Write JSON file
json_file = File.join(output_dir, "sample_devices.json")
File.write(json_file, JSON.pretty_generate(devices_data))
puts "Exported #{devices_data[:devices].size} devices to #{json_file}"

# Export SQL dump for schema
sql_file = File.join(output_dir, "schema.sql")
schema_sql = DataMapper.repository.adapter.select("
  SELECT sql FROM sqlite_master 
  WHERE type='table' AND name NOT LIKE 'sqlite_%'
  ORDER BY name
")

File.open(sql_file, 'w') do |f|
  f.puts "-- Blue Hydra Database Schema"
  f.puts "-- Exported: #{Time.now}"
  f.puts "-- Version: #{BlueHydra::VERSION}"
  f.puts
  
  schema_sql.each do |sql|
    f.puts sql
    f.puts ";"
    f.puts
  end
end

puts "Exported schema to #{sql_file}"

# Export statistics
stats = {
  total_devices: BlueHydra::Device.count,
  online_devices: BlueHydra::Device.all(status: 'online').count,
  offline_devices: BlueHydra::Device.all(status: 'offline').count,
  classic_only: BlueHydra::Device.all(classic_mode: true, le_mode: false).count,
  le_only: BlueHydra::Device.all(classic_mode: false, le_mode: true).count,
  dual_mode: BlueHydra::Device.all(classic_mode: true, le_mode: true).count,
  devices_with_names: BlueHydra::Device.all(:name.not => nil).count
}

stats_file = File.join(output_dir, "database_stats.json")
File.write(stats_file, JSON.pretty_generate(stats))
puts "Exported statistics to #{stats_file}"

puts
puts "Sample data export complete!"
puts "Files created in: #{output_dir}" 