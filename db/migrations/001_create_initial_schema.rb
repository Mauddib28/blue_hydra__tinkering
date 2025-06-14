# Initial schema migration for Blue Hydra
# Matches existing DataMapper schema for compatibility

Sequel.migration do
  up do
    # Create devices table
    create_table(:blue_hydra_devices) do
      primary_key :id
      
      # Core attributes
      String :uuid, size: 255
      String :name, size: 255
      String :status, size: 255
      String :address, size: 255
      String :uap_lap, size: 255
      Text :vendor
      
      # Device characteristics
      String :appearance, size: 255
      String :company, size: 255
      String :company_type, size: 255
      String :lmp_version, size: 255
      String :manufacturer, size: 255
      String :firmware, size: 255
      
      # Classic Bluetooth attributes
      TrueClass :classic_mode, default: false
      Text :classic_service_uuids
      Text :classic_channels
      String :classic_major_class, size: 255
      String :classic_minor_class, size: 255
      Text :classic_class
      Text :classic_rssi
      Text :classic_tx_power
      Text :classic_features
      Text :classic_features_bitmap
      
      # Bluetooth Low Energy attributes
      TrueClass :le_mode, default: false
      Text :le_service_uuids
      String :le_address_type, size: 255
      String :le_random_address_type, size: 255
      String :le_company_data, size: 255
      String :le_company_uuid, size: 255
      String :le_proximity_uuid, size: 255
      String :le_major_num, size: 255
      String :le_minor_num, size: 255
      Text :le_flags
      Text :le_rssi
      Text :le_tx_power
      Text :le_features
      Text :le_features_bitmap
      String :ibeacon_range, size: 255
      
      # Timestamps
      DateTime :created_at
      DateTime :updated_at
      Integer :last_seen
      
      # Indexes
      index :address
      index :uap_lap
      index :status
      index [:status, :last_seen]
    end
    
    # Create sync versions table
    create_table(:blue_hydra_sync_versions) do
      primary_key :id
      String :version, size: 255
    end
    
    # Add additional indexes if needed
    # Note: DataMapper didn't create explicit indexes, but these improve performance
    add_index :blue_hydra_devices, :uuid
    add_index :blue_hydra_devices, :last_seen
    add_index :blue_hydra_devices, [:classic_mode, :le_mode]
  end
  
  down do
    drop_table(:blue_hydra_sync_versions)
    drop_table(:blue_hydra_devices)
  end
end 