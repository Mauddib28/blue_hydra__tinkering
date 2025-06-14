# Sequel ORM Setup Documentation

## Overview

This document describes the Sequel ORM setup for Blue Hydra, providing a modern replacement for the deprecated DataMapper ORM while maintaining backward compatibility.

## Architecture

### Core Components

1. **Database Connection Module** (`lib/blue_hydra/sequel_db.rb`)
   - Manages database connections
   - Handles configuration
   - Provides migration support
   - Offers utility methods for stats and integrity checks

2. **Base Model Class** (`lib/blue_hydra/models/sequel_base.rb`)
   - Provides DataMapper-compatible API
   - Handles JSON field serialization
   - Implements dirty tracking
   - Offers compatibility methods

3. **Migrations** (`db/migrations/`)
   - Version-controlled schema changes
   - Reversible migrations
   - Maintains DataMapper schema compatibility

## Configuration

### Database Connection

```ruby
# Default configuration
{
  adapter: 'sqlite',
  database: database_path,
  max_connections: 10,
  logger: logger,
  sql_log_level: :debug,
  log_connection_info: false
}
```

### Database Path Logic

- **Test Mode**: Uses `:memory:` database
- **System Installation**: `/var/lib/blue_hydra/blue_hydra.db`
- **Local Installation**: `blue_hydra.db` in working directory

### SQLite Optimizations

```sql
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
```

These match the DataMapper configuration for performance.

## Plugins and Extensions

### Global Sequel Plugins

- **timestamps**: Automatic created_at/updated_at handling
- **validation_helpers**: Model validation methods
- **json_serializer**: JSON serialization support
- **dirty**: Track changed attributes
- **association_dependencies**: Handle related records
- **before_after_save**: Save callbacks

### Database Extensions

- **pagination**: Dataset pagination support
- **date_arithmetic**: Date/time calculations

## Migration System

### Creating Migrations

```bash
rake sequel:create_migration[add_new_feature]
```

Creates a new migration file with proper numbering.

### Running Migrations

```bash
# Run all pending migrations
rake sequel:migrate

# Migrate to specific version
rake sequel:migrate[3]

# Rollback last migration
rake sequel:rollback

# Rollback multiple migrations
rake sequel:rollback[3]
```

### Migration Structure

```ruby
Sequel.migration do
  up do
    # Forward migration code
    add_column :blue_hydra_devices, :new_field, String
  end
  
  down do
    # Rollback code
    drop_column :blue_hydra_devices, :new_field
  end
end
```

## DataMapper Compatibility

### Query Methods

The base model provides DataMapper-compatible methods:

```ruby
# DataMapper style
Device.all(status: 'online')
Device.first(address: 'AA:BB:CC:DD:EE:FF')
Device.get(123)
Device.count(status: 'online')

# All map to Sequel equivalents
Device.where(status: 'online').all
Device.where(address: 'AA:BB:CC:DD:EE:FF').first
Device[123]
Device.where(status: 'online').count
```

### JSON Field Handling

Custom field types handle JSON serialization:

```ruby
class Device < BlueHydra::Models::SequelBase
  # Array fields (auto-serialized to JSON)
  json_array_field :classic_rssi
  json_array_field :le_service_uuids
  
  # Object fields (auto-serialized to JSON)
  json_object_field :classic_features_bitmap
end
```

### Dirty Tracking

```ruby
device.name = "New Name"
device.attribute_dirty?(:name)  # => true
device.attribute_was(:name)     # => "Old Name"
device.dirty_attributes         # => [:name]
```

## Testing Support

### Test Configuration

The spec helper automatically configures Sequel for testing:

```ruby
# In test mode
ENV["BLUE_HYDRA"] = "test"  # Uses :memory: database

# Database cleaner integration
config.before(:suite) do
  BlueHydra::SequelDB.connect!
  BlueHydra::SequelDB.migrate!
end
```

### Factory Support

Factories work seamlessly with Sequel models:

```ruby
FactoryBot.define do
  factory :device, class: 'BlueHydra::Models::Device' do
    address { generate_mac_address }
    name { Faker::Device.model_name }
  end
end
```

## Rake Tasks

### Available Tasks

```bash
# Database operations
rake sequel:migrate              # Run migrations
rake sequel:rollback            # Rollback migrations
rake sequel:version             # Show current version
rake sequel:test_connection     # Test database connection

# Development helpers
rake sequel:create_migration[name]  # Create new migration
rake sequel:compare_schemas        # Compare DataMapper vs Sequel schemas
```

## Performance Considerations

### Indexes

The migration adds indexes not present in DataMapper:

- `address` - Device lookups
- `uap_lap` - Partial MAC lookups
- `status` - Filtering active devices
- `[status, last_seen]` - Timeout queries
- `uuid` - Sync operations
- `last_seen` - Time-based queries
- `[classic_mode, le_mode]` - Mode filtering

### Connection Pooling

- Maximum 10 connections (configurable)
- Automatic connection management
- Thread-safe operations

## Migration from DataMapper

### Parallel Operation

During migration, both ORMs can operate simultaneously:

```ruby
# DataMapper (existing)
device_dm = BlueHydra::Device.first(address: mac)

# Sequel (new)
device_seq = BlueHydra::Models::Device.first(address: mac)
```

### Data Migration

Use the provided migration scripts to transfer data:

```ruby
# In migration script
DataMapper::Device.all.each do |dm_device|
  BlueHydra::Models::Device.create(
    dm_device.attributes
  )
end
```

## Troubleshooting

### Connection Issues

```bash
# Test connection
rake sequel:test_connection

# Check database integrity
BlueHydra::SequelDB.integrity_check
```

### Migration Problems

```bash
# Check current version
rake sequel:version

# Force specific version
rake sequel:migrate[0]  # Reset
rake sequel:migrate     # Re-run all
```

### Performance Monitoring

```ruby
# Enable query logging
BlueHydra::SequelDB.db.loggers << Logger.new(STDOUT)

# Get statistics
BlueHydra::SequelDB.stats
```

## Best Practices

1. **Always use migrations** for schema changes
2. **Test migrations** on copy of production data
3. **Keep backward compatibility** during transition
4. **Monitor performance** after switching ORMs
5. **Use transactions** for bulk operations
6. **Index frequently queried columns**

## Next Steps

1. Implement Device model with Sequel (Task #5)
2. Create data migration scripts (Task #8)
3. Update application code to use Sequel
4. Remove DataMapper dependencies (final phase) 