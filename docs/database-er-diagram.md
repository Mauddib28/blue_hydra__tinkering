# Blue Hydra Database ER Diagram

## Entity Relationship Diagram

```mermaid
erDiagram
    BLUE_HYDRA_DEVICES {
        INTEGER id PK
        STRING uuid
        STRING name
        STRING status
        STRING address UK
        STRING uap_lap
        TEXT vendor
        STRING appearance
        STRING company
        STRING company_type
        STRING lmp_version
        STRING manufacturer
        STRING firmware
        BOOLEAN classic_mode
        TEXT classic_service_uuids
        TEXT classic_channels
        STRING classic_major_class
        STRING classic_minor_class
        TEXT classic_class
        TEXT classic_rssi
        TEXT classic_tx_power
        TEXT classic_features
        TEXT classic_features_bitmap
        BOOLEAN le_mode
        TEXT le_service_uuids
        STRING le_address_type
        STRING le_random_address_type
        STRING le_company_data
        STRING le_company_uuid
        STRING le_proximity_uuid
        STRING le_major_num
        STRING le_minor_num
        TEXT le_flags
        TEXT le_rssi
        TEXT le_tx_power
        TEXT le_features
        TEXT le_features_bitmap
        STRING ibeacon_range
        DATETIME created_at
        DATETIME updated_at
        INTEGER last_seen
    }
    
    BLUE_HYDRA_SYNC_VERSIONS {
        INTEGER id PK
        STRING version
    }
```

## Table Descriptions

### blue_hydra_devices
The main table storing all discovered Bluetooth devices.

**Key Columns:**
- `id`: Primary key, auto-incrementing
- `address`: MAC address of the device (should be unique but not enforced in schema)
- `uuid`: Sync ID for external synchronization
- `uap_lap`: Last 4 octets of MAC for device lookup
- `status`: Device status (online/offline)
- `last_seen`: Unix timestamp of last detection

**Mode Indicators:**
- `classic_mode`: Boolean indicating Classic Bluetooth support
- `le_mode`: Boolean indicating Bluetooth Low Energy support

**JSON Storage Columns:**
These columns store JSON arrays or objects as text:
- `*_rssi`: Arrays of RSSI readings (limited to 100 values)
- `*_service_uuids`: Arrays of service UUIDs
- `*_features`: Arrays of feature descriptions
- `*_features_bitmap`: JSON objects with page/bitmap pairs

### blue_hydra_sync_versions
Tracks synchronization versions for external systems.

**Key Columns:**
- `id`: Primary key
- `version`: UUID string for version tracking

## Relationships

Currently, Blue Hydra uses a single-table design with no foreign key relationships. All device data is denormalized into the `blue_hydra_devices` table.

## Indexes

**Implicit Indexes:**
- Primary key index on `id` column

**Recommended Indexes (not in current schema):**
- Index on `address` for device lookup
- Index on `uap_lap` for partial MAC lookup
- Index on `status` for filtering active devices
- Composite index on `(status, last_seen)` for timeout queries

## Data Patterns

### Device Identification
Devices can be identified by multiple methods:
1. Full MAC address
2. UAP/LAP (partial MAC)
3. iBeacon trinity (proximity UUID + major + minor)
4. Gimbal beacons (company + company data)

### Temporal Data
- `created_at`: When device was first discovered
- `updated_at`: Last modification time
- `last_seen`: Unix timestamp for timeout calculations

### Mode Detection
A device can support:
- Classic only (`classic_mode=true, le_mode=false`)
- LE only (`classic_mode=false, le_mode=true`)
- Dual mode (`classic_mode=true, le_mode=true`)
- Unknown (both false - legacy data) 