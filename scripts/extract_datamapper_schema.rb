#!/usr/bin/env ruby
# Script to extract DataMapper schema for migration planning

# Set test environment to avoid bluetooth adapter initialization
ENV["BLUE_HYDRA"] = "test"

# Only require the necessary parts
require 'json'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-validations'
require 'louis'

# Set up DataMapper
DataMapper::Property::String.length(255)
DataMapper.setup(:default, 'sqlite::memory:')

# Define models directly without full blue_hydra initialization
class BlueHydra
  class Device
    include DataMapper::Resource
    
    property :id,                            Serial
    property :uuid,                          String
    property :name,                          String
    property :status,                        String
    property :address,                       String
    property :uap_lap,                       String
    property :vendor,                        Text
    property :appearance,                    String
    property :company,                       String
    property :company_type,                  String
    property :lmp_version,                   String
    property :manufacturer,                  String
    property :firmware,                      String
    property :classic_mode,                  Boolean, default: false
    property :classic_service_uuids,         Text
    property :classic_channels,              Text
    property :classic_major_class,           String
    property :classic_minor_class,           String
    property :classic_class,                 Text
    property :classic_rssi,                  Text
    property :classic_tx_power,              Text
    property :classic_features,              Text
    property :classic_features_bitmap,       Text
    property :le_mode,                       Boolean, default: false
    property :le_service_uuids,              Text
    property :le_address_type,               String
    property :le_random_address_type,        String
    property :le_company_data,               String, :length => 255
    property :le_company_uuid,               String
    property :le_proximity_uuid,             String
    property :le_major_num,                  String
    property :le_minor_num,                  String
    property :le_flags,                      Text
    property :le_rssi,                       Text
    property :le_tx_power,                   Text
    property :le_features,                   Text
    property :le_features_bitmap,            Text
    property :ibeacon_range,                 String
    property :created_at,                    DateTime
    property :updated_at,                    DateTime
    property :last_seen,                     Integer
    
    MAC_REGEX = /^((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})$/i
    validates_format_of :address, with: MAC_REGEX
  end
  
  class SyncVersion
    include DataMapper::Resource
    property :id, Serial
    property :version, String
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!

puts "# Blue Hydra Database Schema (DataMapper)"
puts "# Generated: #{Time.now}"
puts

# Extract schema using SQLite master table
schema_sql = DataMapper.repository.adapter.select("
  SELECT sql FROM sqlite_master 
  WHERE type='table' AND name NOT LIKE 'sqlite_%'
  ORDER BY name
")

puts "## SQL Schema"
puts
schema_sql.each do |sql|
  puts sql
  puts ";"
  puts
end

puts "## DataMapper Model Details"
puts

# Document all models
DataMapper::Model.descendants.each do |model|
  puts "### #{model.name}"
  puts
  puts "**Table Name:** #{model.storage_name}"
  puts
  puts "**Properties:**"
  puts
  
  model.properties.each do |prop|
    type_info = prop.class.name.split('::').last
    type_info += " -> #{prop.primitive.to_s}"
    type_info += " (Primary Key)" if prop.serial?
    type_info += " (Required)" if prop.required?
    
    defaults = []
    defaults << "Default: false" if prop.name.to_s =~ /mode$/ && prop.primitive == TrueClass
    defaults << "Length: #{prop.length}" if prop.respond_to?(:length) && prop.primitive == String && prop.length != 255
    
    type_str = "- `#{prop.name}`: #{type_info}"
    type_str += " (#{defaults.join(', ')})" if defaults.any?
    
    puts type_str
  end
  
  puts
  puts "**Indexes:**"
  if model.properties.any?(&:index)
    model.properties.select(&:index).each do |prop|
      puts "- #{prop.name}"
    end
  else
    puts "- None defined in model"
  end
  
  puts
  puts "**Validations:**"
  if model.validators.any?
    model.validators.each do |context, validators|
      validators.each do |validator|
        puts "- #{validator.class.name.split('::').last}: #{validator.field_name}"
      end
    end
  else
    puts "- None"
  end
  
  puts
  puts "---"
  puts
end 