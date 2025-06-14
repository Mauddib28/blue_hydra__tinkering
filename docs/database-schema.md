# Blue Hydra Database Schema (DataMapper)
# Generated: 2025-06-12 14:02:43 -0700

## SQL Schema

CREATE TABLE "blue_hydra_devices" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "uuid" VARCHAR(255), "name" VARCHAR(255), "status" VARCHAR(255), "address" VARCHAR(255), "uap_lap" VARCHAR(255), "vendor" TEXT, "appearance" VARCHAR(255), "company" VARCHAR(255), "company_type" VARCHAR(255), "lmp_version" VARCHAR(255), "manufacturer" VARCHAR(255), "firmware" VARCHAR(255), "classic_mode" BOOLEAN DEFAULT 'f', "classic_service_uuids" TEXT, "classic_channels" TEXT, "classic_major_class" VARCHAR(255), "classic_minor_class" VARCHAR(255), "classic_class" TEXT, "classic_rssi" TEXT, "classic_tx_power" TEXT, "classic_features" TEXT, "classic_features_bitmap" TEXT, "le_mode" BOOLEAN DEFAULT 'f', "le_service_uuids" TEXT, "le_address_type" VARCHAR(255), "le_random_address_type" VARCHAR(255), "le_company_data" VARCHAR(255), "le_company_uuid" VARCHAR(255), "le_proximity_uuid" VARCHAR(255), "le_major_num" VARCHAR(255), "le_minor_num" VARCHAR(255), "le_flags" TEXT, "le_rssi" TEXT, "le_tx_power" TEXT, "le_features" TEXT, "le_features_bitmap" TEXT, "ibeacon_range" VARCHAR(255), "created_at" TIMESTAMP, "updated_at" TIMESTAMP, "last_seen" INTEGER)
;

CREATE TABLE "blue_hydra_sync_versions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "version" VARCHAR(255))
;

## DataMapper Model Details

### BlueHydra::Device

**Table Name:** blue_hydra_devices

**Properties:**

- `id`: Serial -> Integer (Primary Key) (Required)
- `uuid`: String -> String
- `name`: String -> String
- `status`: String -> String
- `address`: String -> String
- `uap_lap`: String -> String
- `vendor`: Text -> String (Length: 65535)
- `appearance`: String -> String
- `company`: String -> String
- `company_type`: String -> String
- `lmp_version`: String -> String
- `manufacturer`: String -> String
- `firmware`: String -> String
- `classic_mode`: Boolean -> TrueClass (Default: false)
- `classic_service_uuids`: Text -> String (Length: 65535)
- `classic_channels`: Text -> String (Length: 65535)
- `classic_major_class`: String -> String
- `classic_minor_class`: String -> String
- `classic_class`: Text -> String (Length: 65535)
- `classic_rssi`: Text -> String (Length: 65535)
- `classic_tx_power`: Text -> String (Length: 65535)
- `classic_features`: Text -> String (Length: 65535)
- `classic_features_bitmap`: Text -> String (Length: 65535)
- `le_mode`: Boolean -> TrueClass (Default: false)
- `le_service_uuids`: Text -> String (Length: 65535)
- `le_address_type`: String -> String
- `le_random_address_type`: String -> String
- `le_company_data`: String -> String
- `le_company_uuid`: String -> String
- `le_proximity_uuid`: String -> String
- `le_major_num`: String -> String
- `le_minor_num`: String -> String
- `le_flags`: Text -> String (Length: 65535)
- `le_rssi`: Text -> String (Length: 65535)
- `le_tx_power`: Text -> String (Length: 65535)
- `le_features`: Text -> String (Length: 65535)
- `le_features_bitmap`: Text -> String (Length: 65535)
- `ibeacon_range`: String -> String
- `created_at`: DateTime -> DateTime
- `updated_at`: DateTime -> DateTime
- `last_seen`: Integer -> Integer

**Indexes:**
- None defined in model

**Validations:**
- NumericalityValidator: id
- LengthValidator: uuid
- PrimitiveTypeValidator: uuid
- LengthValidator: name
- PrimitiveTypeValidator: name
- LengthValidator: status
- PrimitiveTypeValidator: status
- LengthValidator: address
- PrimitiveTypeValidator: address
- LengthValidator: uap_lap
- PrimitiveTypeValidator: uap_lap
- LengthValidator: vendor
- PrimitiveTypeValidator: vendor
- LengthValidator: appearance
- PrimitiveTypeValidator: appearance
- LengthValidator: company
- PrimitiveTypeValidator: company
- LengthValidator: company_type
- PrimitiveTypeValidator: company_type
- LengthValidator: lmp_version
- PrimitiveTypeValidator: lmp_version
- LengthValidator: manufacturer
- PrimitiveTypeValidator: manufacturer
- LengthValidator: firmware
- PrimitiveTypeValidator: firmware
- PrimitiveTypeValidator: classic_mode
- LengthValidator: classic_service_uuids
- PrimitiveTypeValidator: classic_service_uuids
- LengthValidator: classic_channels
- PrimitiveTypeValidator: classic_channels
- LengthValidator: classic_major_class
- PrimitiveTypeValidator: classic_major_class
- LengthValidator: classic_minor_class
- PrimitiveTypeValidator: classic_minor_class
- LengthValidator: classic_class
- PrimitiveTypeValidator: classic_class
- LengthValidator: classic_rssi
- PrimitiveTypeValidator: classic_rssi
- LengthValidator: classic_tx_power
- PrimitiveTypeValidator: classic_tx_power
- LengthValidator: classic_features
- PrimitiveTypeValidator: classic_features
- LengthValidator: classic_features_bitmap
- PrimitiveTypeValidator: classic_features_bitmap
- PrimitiveTypeValidator: le_mode
- LengthValidator: le_service_uuids
- PrimitiveTypeValidator: le_service_uuids
- LengthValidator: le_address_type
- PrimitiveTypeValidator: le_address_type
- LengthValidator: le_random_address_type
- PrimitiveTypeValidator: le_random_address_type
- LengthValidator: le_company_data
- PrimitiveTypeValidator: le_company_data
- LengthValidator: le_company_uuid
- PrimitiveTypeValidator: le_company_uuid
- LengthValidator: le_proximity_uuid
- PrimitiveTypeValidator: le_proximity_uuid
- LengthValidator: le_major_num
- PrimitiveTypeValidator: le_major_num
- LengthValidator: le_minor_num
- PrimitiveTypeValidator: le_minor_num
- LengthValidator: le_flags
- PrimitiveTypeValidator: le_flags
- LengthValidator: le_rssi
- PrimitiveTypeValidator: le_rssi
- LengthValidator: le_tx_power
- PrimitiveTypeValidator: le_tx_power
- LengthValidator: le_features
- PrimitiveTypeValidator: le_features
- LengthValidator: le_features_bitmap
- PrimitiveTypeValidator: le_features_bitmap
- LengthValidator: ibeacon_range
- PrimitiveTypeValidator: ibeacon_range
- PrimitiveTypeValidator: created_at
- PrimitiveTypeValidator: updated_at
- NumericalityValidator: last_seen
- FormatValidator: address

---

### BlueHydra::SyncVersion

**Table Name:** blue_hydra_sync_versions

**Properties:**

- `id`: Serial -> Integer (Primary Key) (Required)
- `version`: String -> String

**Indexes:**
- None defined in model

**Validations:**
- NumericalityValidator: id
- LengthValidator: version
- PrimitiveTypeValidator: version

---

