# Sequel Device Model Migration Documentation

## Overview

Successfully migrated the Blue Hydra Device model from DataMapper to Sequel ORM while maintaining full backward compatibility and functionality.

## Key Changes

### 1. Model Structure
- Created `lib/blue_hydra/models/device.rb` inheriting from `BlueHydra::Models::SequelBase`
- Maintained all 40+ properties from the DataMapper model
- Set table name to `:blue_hydra_devices`

### 2. Validations
- **MAC Address Format**: Using regex validation `/^((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})$/i`
- **Address Normalization**: Automatically converts addresses to uppercase
- **Status Validation**: Validates status as 'online' or 'offline'

### 3. Callbacks (Matching DataMapper Order)
**Before Save:**
1. `set_vendor` - Performs Louis lookup for vendor identification
2. `set_uap_lap` - Extracts last 4 octets from MAC address
3. `set_uuid` - Generates unique UUID if not present
4. `prepare_the_filth` - Tracks dirty attributes for sync

**After Save:**
1. `sync_to_pulse` - Syncs device data to Pulse if enabled

### 4. JSON Field Handling
Implemented custom setters for all JSON fields with proper:
- **Array merging** for service UUIDs, features, flags
- **RSSI limiting** to last 100 entries
- **Object merging** for feature bitmaps
- **Data normalization** (removing hex prefixes, wrapping unknown UUIDs)

### 5. Core Methods

#### `update_or_create_from_result`
Maintains the complex device matching logic:
1. Primary lookup by address
2. Fallback to UAP/LAP matching
3. iBeacon trinity matching (proximity UUID + major + minor)
4. Gimbal device matching by company data
5. Creates new device if no match found

#### `mark_old_devices_offline`
Preserves timeout logic:
- Classic devices: 15 minutes
- LE devices: 3 minutes  
- Very old devices: 2 weeks (marked offline but not deleted)

### 6. DataMapper Compatibility
- Supports `.all(conditions)` method syntax
- Implements `attribute_dirty?` for change tracking
- Maintains same attribute names and behaviors

### 7. Testing
Created comprehensive test suite in `spec/models/sequel_device_spec.rb`:
- Basic property tests
- Validation tests
- Callback tests
- JSON field handling tests
- `update_or_create_from_result` scenarios
- `mark_old_devices_offline` functionality
- Custom setter behaviors
- Thread safety tests
- DataMapper compatibility tests

## Migration Approach

The migration follows a parallel implementation strategy:
1. Sequel model exists alongside DataMapper model
2. Both models can operate on the same database
3. Gradual migration possible without breaking changes
4. Full backward compatibility maintained

## Performance Improvements

1. **Added indexes** on commonly queried fields:
   - `address` (unique)
   - `uap_lap`
   - `status`
   - `last_seen`
   - Composite index on `updated_at, status`

2. **Optimized queries** using Sequel's dataset methods
3. **Efficient bulk updates** in `mark_old_devices_offline`

## Next Steps

With the Device model successfully migrated, the next major task is fixing Ruby 3.x compatibility issues throughout the codebase, particularly addressing the Fixnum/Integer unification problem. 