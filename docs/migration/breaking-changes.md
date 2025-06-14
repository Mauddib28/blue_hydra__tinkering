# Breaking Changes - Blue Hydra Modernization

This document lists all breaking changes introduced in the modernized version of Blue Hydra.

## Ruby Version Requirements

### Legacy Version
- **Required**: Ruby 2.7.x (specifically 2.7.8)
- **Status**: End of life as of March 2023

### Modernized Version
- **Minimum Required**: Ruby 3.0.0
- **Recommended**: Ruby 3.2.0 or higher
- **Tested With**: Ruby 3.2.0

## Core Dependencies

### ORM Migration: DataMapper → Sequel

The most significant breaking change is the migration from DataMapper to Sequel ORM.

#### Impact
- Database schema remains compatible
- Model API has changed significantly
- Custom DataMapper plugins need rewriting
- Query syntax is different

#### Key Differences
```ruby
# Legacy (DataMapper)
Device.all(:address => "AA:BB:CC:DD:EE:FF")
Device.first_or_create(:address => address)

# Modernized (Sequel)
Device.where(address: "AA:BB:CC:DD:EE:FF").all
Device.find_or_create(address: address)
```

### D-Bus Integration

#### Legacy Version
- Used Python scripts for D-Bus communication
- Required `python-dbus` system package
- Subprocess-based discovery

#### Modernized Version
- Native Ruby D-Bus integration via `ruby-dbus` gem
- No Python dependencies
- Direct API calls
- Automatic fallback to Python if needed

### Gem Dependencies

#### Removed Dependencies
- `data_mapper` (1.2.0)
- `dm-sqlite-adapter` (1.2.0)
- `dm-timestamps` (1.2.0)
- `dm-validations` (1.2.0)
- All DataMapper ecosystem gems

#### Added Dependencies
- `sequel` (~> 5.70)
- `ruby-dbus` (~> 0.23.0)
- `sequel-annotate` (for development)

#### Updated Dependencies
- `sqlite3` (1.4.4 → 1.6.x for Ruby 3.x)
- `faker` (2.23 → 3.x for Ruby 3.x)

## API Changes

### Model Attributes

#### Device Model
- All attributes now use Sequel's API
- JSON serialization handled differently
- Validations syntax changed

#### Callbacks
```ruby
# Legacy (DataMapper)
before :save, :set_vendor

# Modernized (Sequel)
def before_save
  super
  set_vendor
end
```

### Discovery API

#### Legacy
```ruby
# Started Python subprocess
start_python_discovery

# Parsed string output
parse_python_output(output)
```

#### Modernized
```ruby
# Native Ruby method calls
discovery_service.start_discovery

# Direct object responses
discovery_service.devices
```

## Configuration Changes

### New Configuration Options

Added to `blue_hydra.yml`:
```yaml
use_python_discovery: false  # Force Python discovery mode
```

### Environment Variables

No changes to environment variable names, but ensure proper Ruby 3.x environment setup.

## Database Migration

### Schema Compatibility
- Database schema remains backward compatible
- Existing SQLite databases can be used directly
- Migration handled automatically on first run

### Data Types
- Integer columns properly handle Ruby 3.x Integer unification
- JSON columns maintain compatibility

## Thread Safety

### Improvements
- New `ThreadManager` class for better thread management
- Automatic thread recovery
- Improved mutex usage

### Breaking Changes
- Thread creation API slightly different
- Must use ThreadManager for consistency

## Signal Handling

No breaking changes - signal handling remains compatible:
- SIGINT for graceful shutdown
- SIGHUP for log rotation

## Compatibility Features

### DataMapper Compatibility Layer
A compatibility layer is provided for easier migration:
- Common DataMapper methods mapped to Sequel
- Gradual migration path available
- Located in `lib/blue_hydra/models/device_sequel.rb`

### Python Discovery Fallback
- Automatically detects if ruby-dbus unavailable
- Falls back to Python scripts
- No code changes needed

## Removed Features

### Deprecated Methods
- Direct DataMapper repository access
- Some internal DataMapper-specific helpers

### Deprecated Options
None - all command-line options maintained

## Performance Implications

### Improvements
- Faster database queries with Sequel
- Reduced subprocess overhead with native D-Bus
- Better memory management

### Potential Regressions
- Initial migration may take time for large databases
- Some complex DataMapper queries need optimization

## Required Actions for Migration

1. **Upgrade Ruby**: Must upgrade to Ruby 3.0.0 or higher
2. **Update Gemfile**: Replace DataMapper gems with Sequel
3. **Run Bundle Install**: Update all dependencies
4. **Database Backup**: Recommended before migration
5. **Test Thoroughly**: Especially custom plugins/extensions

## Rollback Considerations

To rollback to legacy version:
1. Restore Ruby 2.7.8 environment
2. Restore original Gemfile
3. Database remains compatible
4. Restore any custom DataMapper code 