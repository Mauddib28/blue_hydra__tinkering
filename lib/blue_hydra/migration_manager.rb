require 'fileutils'
require 'json'
require 'logger'
require 'sequel'
require 'dm-core'

module BlueHydra
  class MigrationManager
    attr_reader :logger, :source_db_path, :backup_dir
    
    def initialize(source_db_path = 'blue_hydra.db', options = {})
      @source_db_path = source_db_path
      @backup_dir = options[:backup_dir] || 'db/backups'
      @logger = options[:logger] || Logger.new(STDOUT)
      @dry_run = options[:dry_run] || false
      
      ensure_backup_directory
    end
    
    # Main migration method
    def migrate_to_sequel
      logger.info "Starting DataMapper to Sequel migration..."
      
      # Step 1: Validate source database
      unless File.exist?(source_db_path)
        raise "Source database not found: #{source_db_path}"
      end
      
      # Step 2: Create backup
      backup_path = create_backup
      logger.info "Created backup: #{backup_path}"
      
      # Step 3: Setup connections
      dm_db = setup_datamapper_connection
      sequel_db = setup_sequel_connection
      
      # Step 4: Run migration
      begin
        migrate_devices(dm_db, sequel_db)
        migrate_sync_versions(dm_db, sequel_db)
        
        # Step 5: Validate migration
        validate_migration(dm_db, sequel_db)
        
        logger.info "Migration completed successfully!"
        
        # Return migration report
        generate_migration_report(dm_db, sequel_db)
      rescue => e
        logger.error "Migration failed: #{e.message}"
        logger.error e.backtrace.join("\n")
        
        if @dry_run
          logger.info "Dry run mode - no changes were actually made"
        else
          logger.info "Consider restoring from backup: #{backup_path}"
        end
        
        raise e
      ensure
        # Clean up connections
        sequel_db.disconnect if sequel_db
      end
    end
    
    # Create a timestamped backup of the source database
    def create_backup
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      backup_filename = "blue_hydra_backup_#{timestamp}.db"
      backup_path = File.join(backup_dir, backup_filename)
      
      unless @dry_run
        FileUtils.cp(source_db_path, backup_path)
        
        # Also create a metadata file
        metadata = {
          source_path: source_db_path,
          backup_path: backup_path,
          timestamp: timestamp,
          file_size: File.size(source_db_path),
          migration_version: '1.0.0'
        }
        
        File.write("#{backup_path}.json", JSON.pretty_generate(metadata))
      end
      
      backup_path
    end
    
    # Restore from a backup
    def restore_from_backup(backup_path)
      unless File.exist?(backup_path)
        raise "Backup not found: #{backup_path}"
      end
      
      logger.info "Restoring from backup: #{backup_path}"
      
      # Create a safety backup of current state
      if File.exist?(source_db_path)
        safety_backup = "#{source_db_path}.before_restore"
        FileUtils.cp(source_db_path, safety_backup)
        logger.info "Created safety backup: #{safety_backup}"
      end
      
      # Restore the backup
      FileUtils.cp(backup_path, source_db_path)
      logger.info "Database restored successfully"
    end
    
    private
    
    def ensure_backup_directory
      FileUtils.mkdir_p(backup_dir) unless File.exist?(backup_dir)
    end
    
    def setup_datamapper_connection
      # Setup DataMapper with existing database
      DataMapper.setup(:default, "sqlite://#{File.absolute_path(source_db_path)}")
      DataMapper.repository(:default).adapter
    end
    
    def setup_sequel_connection
      # Create new Sequel database (or connect to existing)
      target_path = source_db_path.sub('.db', '_sequel.db')
      
      if @dry_run
        # Use in-memory database for dry run
        db = Sequel.sqlite
      else
        db = Sequel.connect("sqlite://#{File.absolute_path(target_path)}")
      end
      
      # Run migrations
      Sequel.extension :migration
      migrations_path = File.expand_path('../../../db/migrations', __FILE__)
      Sequel::Migrator.run(db, migrations_path)
      
      db
    end
    
    def migrate_devices(dm_db, sequel_db)
      logger.info "Migrating devices table..."
      
      # Get DataMapper model
      require_relative 'models/devices'
      
      # Count records
      total_count = BlueHydra::Devices.count
      logger.info "Found #{total_count} devices to migrate"
      
      # Migrate in batches
      batch_size = 1000
      migrated = 0
      
      (0..total_count).step(batch_size) do |offset|
        devices = BlueHydra::Devices.all(
          offset: offset,
          limit: batch_size,
          order: [:id.asc]
        )
        
        devices.each do |device|
          migrate_device_record(device, sequel_db)
          migrated += 1
          
          if migrated % 100 == 0
            logger.info "Migrated #{migrated}/#{total_count} devices..."
          end
        end
      end
      
      logger.info "Migrated #{migrated} devices successfully"
    end
    
    def migrate_device_record(dm_device, sequel_db)
      # Convert DataMapper record to hash
      attributes = {
        id: dm_device.id,
        uuid: dm_device.uuid,
        name: dm_device.name,
        status: dm_device.status,
        address: dm_device.address,
        uap_lap: dm_device.uap_lap,
        vendor: dm_device.vendor,
        appearance: dm_device.appearance,
        company: dm_device.company,
        company_type: dm_device.company_type,
        lmp_version: dm_device.lmp_version,
        manufacturer: dm_device.manufacturer,
        firmware: dm_device.firmware,
        classic_mode: dm_device.classic_mode,
        le_mode: dm_device.le_mode,
        ibeacon_range: dm_device.ibeacon_range,
        created_at: dm_device.created_at,
        updated_at: dm_device.updated_at,
        last_seen: dm_device.last_seen
      }
      
      # Handle JSON fields
      json_fields = %w[
        classic_service_uuids classic_channels classic_class 
        classic_rssi classic_features classic_features_bitmap
        le_service_uuids le_flags le_rssi le_features le_features_bitmap
      ]
      
      json_fields.each do |field|
        value = dm_device.send(field)
        attributes[field.to_sym] = value.is_a?(String) ? value : value.to_json
      end
      
      # Handle other string fields
      string_fields = %w[
        classic_major_class classic_minor_class classic_tx_power
        le_address_type le_random_address_type le_company_data
        le_company_uuid le_proximity_uuid le_major_num le_minor_num le_tx_power
      ]
      
      string_fields.each do |field|
        attributes[field.to_sym] = dm_device.send(field)
      end
      
      # Insert into Sequel database
      unless @dry_run
        sequel_db[:blue_hydra_devices].insert(attributes)
      end
    rescue => e
      logger.error "Failed to migrate device #{dm_device.id}: #{e.message}"
      raise e
    end
    
    def migrate_sync_versions(dm_db, sequel_db)
      logger.info "Migrating sync versions table..."
      
      require_relative 'models/sync_version'
      
      versions = BlueHydra::SyncVersion.all
      logger.info "Found #{versions.count} sync versions to migrate"
      
      versions.each do |version|
        attributes = {
          id: version.id,
          version: version.version
        }
        
        unless @dry_run
          sequel_db[:blue_hydra_sync_versions].insert(attributes)
        end
      end
      
      logger.info "Migrated sync versions successfully"
    end
    
    def validate_migration(dm_db, sequel_db)
      logger.info "Validating migration..."
      
      # Check record counts
      dm_device_count = BlueHydra::Devices.count
      sequel_device_count = sequel_db[:blue_hydra_devices].count
      
      if dm_device_count != sequel_device_count
        raise "Device count mismatch: DataMapper=#{dm_device_count}, Sequel=#{sequel_device_count}"
      end
      
      dm_version_count = BlueHydra::SyncVersion.count
      sequel_version_count = sequel_db[:blue_hydra_sync_versions].count
      
      if dm_version_count != sequel_version_count
        raise "Sync version count mismatch: DataMapper=#{dm_version_count}, Sequel=#{sequel_version_count}"
      end
      
      # Sample validation - check a few random records
      sample_size = [10, dm_device_count / 100].max
      sample_ids = BlueHydra::Devices.all(
        fields: [:id],
        limit: sample_size,
        order: [:id.asc]
      ).map(&:id)
      
      sample_ids.each do |id|
        validate_device_record(id, dm_db, sequel_db)
      end
      
      logger.info "Migration validation passed!"
    end
    
    def validate_device_record(id, dm_db, sequel_db)
      dm_device = BlueHydra::Devices.get(id)
      sequel_device = sequel_db[:blue_hydra_devices].where(id: id).first
      
      unless sequel_device
        raise "Device #{id} not found in Sequel database"
      end
      
      # Check key fields
      %w[address name uuid status].each do |field|
        dm_value = dm_device.send(field)
        sequel_value = sequel_device[field.to_sym]
        
        if dm_value != sequel_value
          raise "Field mismatch for device #{id}.#{field}: DM='#{dm_value}', Sequel='#{sequel_value}'"
        end
      end
    end
    
    def generate_migration_report(dm_db, sequel_db)
      report = {
        timestamp: Time.now.iso8601,
        source_database: source_db_path,
        statistics: {
          devices: {
            datamapper_count: BlueHydra::Devices.count,
            sequel_count: sequel_db[:blue_hydra_devices].count
          },
          sync_versions: {
            datamapper_count: BlueHydra::SyncVersion.count,
            sequel_count: sequel_db[:blue_hydra_sync_versions].count
          }
        },
        validation: {
          status: 'passed',
          sample_size: [10, BlueHydra::Devices.count / 100].max
        }
      }
      
      # Save report
      report_path = File.join(backup_dir, "migration_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
      File.write(report_path, JSON.pretty_generate(report)) unless @dry_run
      
      logger.info "Migration report saved to: #{report_path}"
      report
    end
  end
end 