# DataMapper Usage Analysis for Blue Hydra

## Overview

This document provides a comprehensive analysis of how DataMapper ORM is used throughout the Blue Hydra codebase, documenting all patterns, features, and queries that need to be migrated to Sequel.

## DataMapper Models

### 1. BlueHydra::Device (lib/blue_hydra/device.rb)
The main model representing Bluetooth devices.

**Properties:**
- `id` - Serial (auto-incrementing primary key)
- `uuid` - String (sync ID)
- `name` - String
- `status` - String
- `address` - String (MAC address)
- `uap_lap` - String
- `vendor` - Text
- `appearance` - String
- `company` - String
- `company_type` - String
- `lmp_version` - String
- `manufacturer` - String
- `firmware` - String
- Classic mode attributes (13 properties)
- LE mode attributes (15 properties)
- `created_at` - DateTime
- `updated_at` - DateTime
- `last_seen` - Integer

**Validations:**
- `validates_format_of :address, with: MAC_REGEX`

**Callbacks:**
- `before :save` - set_vendor, set_uap_lap, set_uuid, prepare_the_filth
- `after :save` - sync_to_pulse

### 2. BlueHydra::SyncVersion (lib/blue_hydra/sync_version.rb)
Simple model for tracking sync versions.

**Properties:**
- `id` - Serial
- `version` - String

**Callbacks:**
- `before :save` - generate_version

## DataMapper Query Patterns

### 1. Basic Queries
```ruby
# Find all with conditions
BlueHydra::Device.all(address: address).first
BlueHydra::Device.all(classic_mode: true, status: "online")
BlueHydra::Device.all(le_mode: true, status: "online")
BlueHydra::Device.all(uap_lap: uap_lap).first

# Multiple conditions
BlueHydra::Device.all(
  le_proximity_uuid: lpu,
  le_major_num: lmn,
  le_minor_num: lmn2
).first

# Count queries
BlueHydra::Device.all(uuid: new_uuid).count
BlueHydra::Device.all(uap_lap: record.uap_lap).count
```

### 2. Advanced Queries with Comparisons
```ruby
# Greater than or equal
BlueHydra::Device.all(:updated_at.gte => since)

# Less than or equal
BlueHydra::Device.all(:updated_at.lte => Time.at(Time.now.to_i - 604800*2))

# Chained with select
BlueHydra::Device.all(classic_mode: true, status: "online").select{|x|
  x.last_seen < (Time.now.to_i - (15*60))
}
```

### 3. DataMapper-Specific Features Used

#### Property Types
- `Serial` - Auto-incrementing integer primary key
- `String` - Variable length strings (default 255 chars)
- `Text` - Longer text fields
- `Boolean` - True/false with defaults
- `DateTime` - Timestamp fields
- `Integer` - Numeric values

#### Default Values
```ruby
property :classic_mode, Boolean, default: false
property :le_mode, Boolean, default: false
```

#### String Length Specification
```ruby
property :le_company_data, String, :length => 255
```

#### Global String Length Setting
```ruby
DataMapper::Property::String.length(255)
```

## DataMapper Setup and Configuration

### Database Connection
```ruby
# Setup patterns found in lib/blue_hydra.rb
DataMapper.setup(:default, db_path)

# Database paths
db_path = if ENV["BLUE_HYDRA"] == "test" || BlueHydra.no_db
            'sqlite::memory:?cache=shared'
          elsif Dir.exist?(DB_DIR)
            "sqlite:#{DB_PATH}"
          else
            "sqlite:#{DB_NAME}"
          end
```

### Migration Strategy
```ruby
DataMapper.auto_upgrade!  # Non-destructive schema updates
DataMapper.finalize      # Finalize all models
```

### Database Optimizations
```ruby
DataMapper.repository.adapter.select('PRAGMA synchronous = OFF')
DataMapper.repository.adapter.select('PRAGMA journal_mode = MEMORY')
```

### Direct SQL Execution
```ruby
# Integrity check
DataMapper.repository.adapter.select('PRAGMA integrity_check')

# Schema extraction
DataMapper.repository.adapter.select("
  SELECT sql FROM sqlite_master 
  WHERE type='table' 
  ORDER BY name
")
```

## Custom Attribute Setters

Many attributes have custom setters that merge new values with existing:
- `classic_channels=` - Merges channel arrays
- `classic_class=` - Merges class arrays
- `classic_features=` - Merges feature arrays
- `le_features=` - Merges LE features
- `le_flags=` - Merges LE flags
- `le_service_uuids=` - Merges and normalizes UUIDs
- `classic_service_uuids=` - Merges and normalizes UUIDs
- `classic_rssi=` / `le_rssi=` - Maintains last 100 values
- `le_features_bitmap=` / `classic_features_bitmap=` - JSON hash storage

## JSON Serialization

Several fields store JSON data:
- Arrays: classic_channels, classic_class, classic_features, le_features, le_flags, service_uuids, rssi values
- Hashes: le_features_bitmap, classic_features_bitmap

## DataMapper to Sequel Migration Mapping

### Property Types
| DataMapper | Sequel |
|------------|--------|
| Serial | primary_key :id |
| String | String |
| Text | String, text: true |
| Boolean | TrueClass/FalseClass |
| DateTime | DateTime |
| Integer | Integer |

### Validations
| DataMapper | Sequel |
|------------|--------|
| validates_format_of | validates_format |
| validates_presence_of | validates_presence |
| validates_uniqueness_of | validates_unique |

### Callbacks
| DataMapper | Sequel |
|------------|--------|
| before :save | before_save |
| after :save | after_save |

### Query Patterns
| DataMapper | Sequel |
|------------|--------|
| Model.all(conditions) | Model.where(conditions) |
| Model.all().first | Model.first |
| :field.gte => value | field >= value |
| :field.lte => value | field <= value |
| Model.all().count | Model.count |

### Key Differences to Address

1. **Auto-upgrade**: Sequel uses explicit migrations instead of auto_upgrade
2. **Property definitions**: Sequel uses schema blocks in migrations
3. **Default values**: Set in schema or model
4. **Dirty tracking**: Different API for tracking attribute changes
5. **Direct SQL**: Different methods for raw SQL execution
6. **Repository pattern**: Sequel uses DB connection object instead 