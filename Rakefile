$:.unshift(File.dirname(File.expand_path('../lib/blue_hydra.rb',__FILE__)))
require 'blue_hydra'
require 'pry'

desc "Print the version."
task "version" do
  puts BlueHydra::VERSION
end

desc "Sync all records to pulse"
task "sync_all" do 
  BlueHydra::Device.all.each do |dev|
    puts "Syncing #{dev.address}" 
    dev.sync_to_pulse(true)
  end
end

desc "BlueHydra Console"
task "console" do 
  binding.pry
end

desc "Summarize Devices"
task "summary" do
  BlueHydra::Device.all.each do |dev|
    puts "Device -- #{dev.address}"
    dev.attributes.each do |name, val|
      next if [:address, :classic_rssi, :le_rssi].include?(name)
      if %w{ 
          classic_features le_features le_flags classic_channels
          le_16_bit_service_uuids classic_16_bit_service_uuids
          le_128_bit_service_uuids classic_128_bit_service_uuids classic_class
          le_rssi classic_rssi primary_services
        }.map(&:to_sym).include?(name)
          unless val == '[]' || val == nil
            puts "  #{name}:"
            JSON.parse(val).each do |v|
              puts "    #{v}"
            end
          end
      else
        unless val == nil
          puts "  #{name}: #{val}"
        end
      end
    end
  end
end

# Database Migration Tasks
namespace :db do
  desc "Migrate DataMapper database to Sequel"
  task :migrate_to_sequel do
    require_relative 'lib/blue_hydra/migration_manager'
    
    source_db = ENV['SOURCE_DB'] || 'blue_hydra.db'
    dry_run = ENV['DRY_RUN'] == 'true'
    
    puts "Starting migration from #{source_db}..."
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    
    manager = BlueHydra::MigrationManager.new(source_db, dry_run: dry_run)
    report = manager.migrate_to_sequel
    
    puts "\nMigration completed!"
    puts "Devices migrated: #{report[:statistics][:devices][:sequel_count]}"
    puts "Sync versions migrated: #{report[:statistics][:sync_versions][:sequel_count]}"
  end
  
  desc "Backup database"
  task :backup do
    require_relative 'lib/blue_hydra/migration_manager'
    
    source_db = ENV['SOURCE_DB'] || 'blue_hydra.db'
    manager = BlueHydra::MigrationManager.new(source_db)
    backup_path = manager.create_backup
    
    puts "Database backed up to: #{backup_path}"
  end
  
  desc "Restore database from backup"
  task :restore do
    require_relative 'lib/blue_hydra/migration_manager'
    
    backup_path = ENV['BACKUP']
    unless backup_path
      puts "ERROR: Please specify BACKUP=path/to/backup.db"
      exit 1
    end
    
    source_db = ENV['SOURCE_DB'] || 'blue_hydra.db'
    manager = BlueHydra::MigrationManager.new(source_db)
    manager.restore_from_backup(backup_path)
    
    puts "Database restored from: #{backup_path}"
  end
  
  desc "Run Sequel migrations"
  task :migrate do
    require 'sequel'
    
    db_path = ENV['DATABASE_URL'] || "sqlite://blue_hydra.db"
    db = Sequel.connect(db_path)
    
    Sequel.extension :migration
    migrations_path = File.expand_path('../db/migrations', __FILE__)
    
    Sequel::Migrator.run(db, migrations_path)
    puts "Sequel migrations completed"
  end
  
  desc "Rollback Sequel migrations"
  task :rollback do
    require 'sequel'
    
    db_path = ENV['DATABASE_URL'] || "sqlite://blue_hydra.db"
    db = Sequel.connect(db_path)
    
    Sequel.extension :migration
    migrations_path = File.expand_path('../db/migrations', __FILE__)
    
    # Get current version
    current = Sequel::Migrator.get_current_migration_version(db)
    target = current - 1
    
    if target >= 0
      Sequel::Migrator.run(db, migrations_path, target: target)
      puts "Rolled back to migration version: #{target}"
    else
      puts "No migrations to rollback"
    end
  end
end

