# Blue Hydra Database Schema Documentation

## Overview

Blue Hydra uses SQLite as its database backend with DataMapper ORM for object-relational mapping. The database consists of two main tables storing Bluetooth device information and synchronization versions.

## Database Structure

### Tables

1. **blue_hydra_devices** - Main device storage table
2. **blue_hydra_sync_versions** - Synchronization version tracking

### Connection Details

- **Database Type**: SQLite 3
- **Default Location**: `blue_hydra.db` in working directory
- **Alternative Locations**:
  - `/var/lib/blue_hydra/blue_hydra.db` (system-wide)
  - `:memory:` (test mode)

## Schema Details

### blue_hydra_devices Table

```sql
CREATE TABLE "blue_hydra_devices" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "uuid" VARCHAR(255),
  "name" VARCHAR(255),
  "status" VARCHAR(255),
  "address" VARCHAR(255),
  "uap_lap" VARCHAR(255),
  "vendor" TEXT,
  "appearance" VARCHAR(255),
  "company" VARCHAR(255),
  "company_type" VARCHAR(255),
  "lmp_version" VARCHAR(255),
  "manufacturer" VARCHAR(255),
  "firmware" VARCHAR(255),
  "classic_mode" BOOLEAN DEFAULT 'f',
  "classic_service_uuids" TEXT,
  "classic_channels" TEXT,
  "classic_major_class" VARCHAR(255),
  "classic_minor_class" VARCHAR(255),
  "classic_class" TEXT,
  "classic_rssi" TEXT,
  "classic_tx_power" TEXT,
  "classic_features" TEXT,
  "classic_features_bitmap" TEXT,
  "le_mode" BOOLEAN DEFAULT 'f',
  "le_service_uuids" TEXT,
  "le_address_type" VARCHAR(255),
  "le_random_address_type" VARCHAR(255),
  "le_company_data" VARCHAR(255),
  "le_company_uuid" VARCHAR(255),
  "le_proximity_uuid" VARCHAR(255),
  "le_major_num" VARCHAR(255),
  "le_minor_num" VARCHAR(255),
  "le_flags" TEXT,
  "le_rssi" TEXT,
  "le_tx_power" TEXT,
  "le_features" TEXT,
  "le_features_bitmap" TEXT,
  "ibeacon_range" VARCHAR(255),
  "created_at" TIMESTAMP,
  "updated_at" TIMESTAMP,
  "last_seen" INTEGER
);
```

### blue_hydra_sync_versions Table

```sql
CREATE TABLE "blue_hydra_sync_versions" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "version" VARCHAR(255)
);
```

## Column Descriptions

### Core Device Information

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key, auto-incrementing |
| uuid | VARCHAR(255) | Unique sync identifier (UUID v4) |
| name | VARCHAR(255) | Device name (from inquiry/advertisement) |
| status | VARCHAR(255) | Device status: 'online' or 'offline' |
| address | VARCHAR(255) | Bluetooth MAC address (XX:XX:XX:XX:XX:XX) |
| uap_lap | VARCHAR(255) | Last 4 octets of MAC (XX:XX:XX:XX) |
| vendor | TEXT | MAC vendor lookup result |

### Device Characteristics

| Column | Type | Description |
|--------|------|-------------|
| appearance | VARCHAR(255) | GAP appearance value |
| company | VARCHAR(255) | Company identifier |
| company_type | VARCHAR(255) | Type of company data |
| lmp_version | VARCHAR(255) | Link Manager Protocol version |
| manufacturer | VARCHAR(255) | Manufacturer string |
| firmware | VARCHAR(255) | Firmware version |

### Classic Bluetooth Attributes

| Column | Type | Description |
|--------|------|-------------|
| classic_mode | BOOLEAN | True if device supports Classic Bluetooth |
| classic_service_uuids | TEXT | JSON array of service UUIDs |
| classic_channels | TEXT | JSON array of RFCOMM channels |
| classic_major_class | VARCHAR(255) | Major device class |
| classic_minor_class | VARCHAR(255) | Minor device class |
| classic_class | TEXT | JSON array of class descriptions |
| classic_rssi | TEXT | JSON array of RSSI readings (max 100) |
| classic_tx_power | TEXT | Transmit power |
| classic_features | TEXT | JSON array of supported features |
| classic_features_bitmap | TEXT | JSON object of feature bitmaps |

### Bluetooth Low Energy Attributes

| Column | Type | Description |
|--------|------|-------------|
| le_mode | BOOLEAN | True if device supports BLE |
| le_service_uuids | TEXT | JSON array of GATT service UUIDs |
| le_address_type | VARCHAR(255) | 'Public' or 'Random' |
| le_random_address_type | VARCHAR(255) | Type of random address |
| le_company_data | VARCHAR(255) | Company-specific data |
| le_company_uuid | VARCHAR(255) | Company UUID |
| le_proximity_uuid | VARCHAR(255) | iBeacon proximity UUID |
| le_major_num | VARCHAR(255) | iBeacon major number |
| le_minor_num | VARCHAR(255) | iBeacon minor number |
| le_flags | TEXT | JSON array of advertisement flags |
| le_rssi | TEXT | JSON array of RSSI readings (max 100) |
| le_tx_power | TEXT | Advertised TX power |
| le_features | TEXT | JSON array of LE features |
| le_features_bitmap | TEXT | JSON object of LE feature bitmaps |
| ibeacon_range | VARCHAR(255) | Calculated iBeacon range |

### Temporal Attributes

| Column | Type | Description |
|--------|------|-------------|
| created_at | TIMESTAMP | When device was first discovered |
| updated_at | TIMESTAMP | Last database update time |
| last_seen | INTEGER | Unix timestamp of last detection |

## Data Patterns

### JSON Storage Format

Several columns store JSON-encoded data:

**Arrays** (stored as JSON arrays):
- `*_rssi`: `["-42 dBm", "-43 dBm", ...]`
- `*_service_uuids`: `["PnP Information (0x1200)", ...]`
- `*_features`: `["BR/EDR Not Supported", ...]`
- `*_flags`: `["LE General Discoverable Mode", ...]`

**Objects** (stored as JSON objects):
- `*_features_bitmap`: `{"0": "0x0000", "1": "0xFFFF"}`

### Device Identification Methods

1. **Primary MAC Address**
   - Full address match
   - Example: `AA:BB:CC:DD:EE:FF`

2. **UAP/LAP Lookup**
   - Partial MAC match (last 4 octets)
   - Used when NAP changes
   - Example: `CC:DD:EE:FF`

3. **iBeacon Identity**
   - Combination of proximity UUID + major + minor
   - Example: `f7826da6-4fa2-4e98-8024-bc5b71e0893e + 1 + 100`

4. **Gimbal Beacons**
   - Company name + company data
   - Example: `Gimbal + specific_data`

### Status Management

Devices are marked offline based on mode and timeout:
- **Classic devices**: 15 minutes without detection
- **LE devices**: 3 minutes without detection
- **Very old devices**: 2+ weeks marked offline (not deleted)

## Performance Considerations

### Current Limitations

1. **No Indexes**: Only primary key index exists
2. **Full Table Scans**: Most queries scan entire table
3. **JSON Parsing**: Runtime parsing of JSON columns

### Recommended Optimizations

```sql
-- Add indexes for common queries
CREATE INDEX idx_address ON blue_hydra_devices(address);
CREATE INDEX idx_uap_lap ON blue_hydra_devices(uap_lap);
CREATE INDEX idx_status ON blue_hydra_devices(status);
CREATE INDEX idx_status_last_seen ON blue_hydra_devices(status, last_seen);
```

### Database Settings

```sql
-- Performance optimizations applied at runtime
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
```

## Migration Considerations

### DataMapper to Sequel

1. **Schema Creation**: Sequel requires explicit migrations
2. **Boolean Storage**: SQLite stores as 't'/'f' strings
3. **Timestamps**: Ensure timezone handling matches
4. **JSON Fields**: Continue as TEXT with JSON encoding

### Backward Compatibility

- Maintain same table/column names
- Preserve JSON encoding format
- Keep timestamp formats consistent
- Support existing device lookup patterns

## Sample Data Export

Use the provided export script to capture sample data:

```bash
ruby scripts/export_sample_data.rb

# With options:
SAMPLE_SIZE=500 INCLUDE_OFFLINE=true ruby scripts/export_sample_data.rb
```

This creates:
- `test_data/sample_devices.json` - Device data
- `test_data/schema.sql` - SQL schema
- `test_data/database_stats.json` - Statistics 