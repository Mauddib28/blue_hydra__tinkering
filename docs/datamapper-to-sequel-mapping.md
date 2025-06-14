# DataMapper to Sequel Migration Mapping

## Overview

This document provides a detailed mapping guide for migrating Blue Hydra from DataMapper to Sequel ORM.

## Database Connection Setup

### DataMapper (Current)
```ruby
DataMapper::Property::String.length(255)
DataMapper.setup(:default, db_path)
DataMapper.auto_upgrade!
DataMapper.finalize
DataMapper.repository.adapter.select('PRAGMA synchronous = OFF')
DataMapper.repository.adapter.select('PRAGMA journal_mode = MEMORY')
```

### Sequel (Migration Target)
```ruby
require 'sequel'

DB = Sequel.sqlite(db_path)
DB.pragma(:synchronous, :off)
DB.pragma(:journal_mode, :memory)

# Default string length handled in migrations
# No auto_upgrade - use explicit migrations
```

## Model Definition

### DataMapper Device Model
```ruby
class BlueHydra::Device
  include DataMapper::Resource
  
  property :id, Serial
  property :address, String
  property :vendor, Text
  property :classic_mode, Boolean, default: false
  property :le_company_data, String, :length => 255
  property :created_at, DateTime
  property :updated_at, DateTime
  
  validates_format_of :address, with: MAC_REGEX
  
  before :save, :set_vendor
  after :save, :sync_to_pulse
end
```

### Sequel Device Model
```ruby
class BlueHydra::Device < Sequel::Model(:blue_hydra_devices)
  plugin :timestamps
  plugin :validation_helpers
  plugin :before_hooks
  plugin :after_hooks
  
  # Validations
  def validate
    super
    validates_format /^((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})$/i, :address
  end
  
  # Callbacks
  before_save :set_vendor, :set_uap_lap, :set_uuid, :prepare_the_filth
  after_save :sync_to_pulse
  
  # Default values handled in schema or model
  def classic_mode
    super || false
  end
  
  def le_mode
    super || false
  end
end
```

## Schema Migration

### Create Sequel Migration
```ruby
# db/migrations/001_create_devices.rb
Sequel.migration do
  change do
    create_table(:blue_hydra_devices) do
      primary_key :id
      String :uuid
      String :name
      String :status
      String :address
      String :uap_lap
      String :vendor, text: true
      String :appearance
      String :company
      String :company_type
      String :lmp_version
      String :manufacturer
      String :firmware
      
      # Boolean fields with defaults
      TrueClass :classic_mode, default: false
      TrueClass :le_mode, default: false
      
      # Text fields for JSON storage
      String :classic_service_uuids, text: true
      String :classic_channels, text: true
      String :classic_class, text: true
      String :classic_rssi, text: true
      String :classic_features, text: true
      String :classic_features_bitmap, text: true
      
      String :le_service_uuids, text: true
      String :le_flags, text: true
      String :le_rssi, text: true
      String :le_features, text: true
      String :le_features_bitmap, text: true
      
      # Other fields
      String :le_company_data
      String :le_proximity_uuid
      Integer :last_seen
      
      # Timestamps
      DateTime :created_at
      DateTime :updated_at
      
      # Indexes
      index :address
      index :uap_lap
    end
    
    create_table(:blue_hydra_sync_versions) do
      primary_key :id
      String :version
    end
  end
end
```

## Query Pattern Mappings

### Basic Queries

| DataMapper | Sequel |
|------------|--------|
| `Device.all(address: addr).first` | `Device.where(address: addr).first` |
| `Device.all(classic_mode: true)` | `Device.where(classic_mode: true)` |
| `Device.all(a: 1, b: 2)` | `Device.where(a: 1, b: 2)` |
| `Device.all().count` | `Device.count` |
| `Device.new` | `Device.new` |

### Advanced Queries

| DataMapper | Sequel |
|------------|--------|
| `Device.all(:updated_at.gte => time)` | `Device.where(updated_at >= time)` |
| `Device.all(:updated_at.lte => time)` | `Device.where(updated_at <= time)` |
| `Device.all(status: "online").select{|x| x.last_seen < cutoff}` | `Device.where(status: "online", last_seen < cutoff)` |

### Creating/Updating Records

| DataMapper | Sequel |
|------------|--------|
| `device.save` | `device.save` |
| `device.valid?` | `device.valid?` |
| `device.errors` | `device.errors` |
| `device.destroy` | `device.destroy` |
| `Device.create(attrs)` | `Device.create(attrs)` |

## Attribute Handling

### Dirty Tracking

DataMapper:
```ruby
def prepare_the_filth
  @filthy_attributes ||= []
  syncable_attributes.each do |attr|
    @filthy_attributes << attr if self.attribute_dirty?(attr)
  end
end
```

Sequel:
```ruby
def prepare_the_filth
  @filthy_attributes ||= []
  syncable_attributes.each do |attr|
    @filthy_attributes << attr if column_changed?(attr)
  end
end
```

### Custom Setters

Both ORMs support custom setters the same way:
```ruby
def address=(new_address)
  # Custom logic
  self[:address] = new_address
end
```

## Direct SQL Execution

| DataMapper | Sequel |
|------------|--------|
| `DataMapper.repository.adapter.select(sql)` | `DB[sql].all` or `DB.fetch(sql).all` |
| `DataMapper.repository.adapter.execute(sql)` | `DB.run(sql)` |

## Validation Mappings

| DataMapper | Sequel (in validate method) |
|------------|------------------------------|
| `validates_format_of :field, with: regex` | `validates_format regex, :field` |
| `validates_presence_of :field` | `validates_presence :field` |
| `validates_uniqueness_of :field` | `validates_unique :field` |

## Callback Mappings

| DataMapper | Sequel |
|------------|--------|
| `before :save` | `before_save` |
| `after :save` | `after_save` |
| `before :create` | `before_create` |
| `after :create` | `after_create` |

## Migration Approach

1. **Create Sequel migrations** for schema
2. **Run migrations** to create new tables with `_sequel` suffix
3. **Create Sequel models** alongside DataMapper models
4. **Implement data migration script** to copy data
5. **Update application code** to use Sequel models
6. **Remove DataMapper** dependencies

## Key Considerations

1. **No Auto-upgrade**: Sequel requires explicit migrations
2. **JSON Fields**: Continue storing as JSON strings
3. **Callbacks**: Similar but different method names
4. **Validations**: Move into `validate` method
5. **Dirty Tracking**: Use `column_changed?` instead of `attribute_dirty?`
6. **Direct SQL**: Different API but similar functionality 