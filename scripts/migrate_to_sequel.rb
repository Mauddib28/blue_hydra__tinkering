#!/usr/bin/env ruby

# DataMapper to Sequel Migration Script
# Usage: ruby scripts/migrate_to_sequel.rb [options]

require 'optparse'
require 'fileutils'
require_relative '../lib/blue_hydra/migration_manager'

options = {
  source_db: 'blue_hydra.db',
  backup_dir: 'db/backups',
  dry_run: false,
  verbose: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby migrate_to_sequel.rb [options]"
  
  opts.on("-s", "--source DATABASE", "Source database path (default: blue_hydra.db)") do |db|
    options[:source_db] = db
  end
  
  opts.on("-b", "--backup-dir DIR", "Backup directory (default: db/backups)") do |dir|
    options[:backup_dir] = dir
  end
  
  opts.on("-d", "--dry-run", "Perform a dry run without making changes") do
    options[:dry_run] = true
  end
  
  opts.on("-v", "--verbose", "Enable verbose logging") do
    options[:verbose] = true
  end
  
  opts.on("-r", "--restore BACKUP", "Restore from a backup file") do |backup|
    options[:restore] = backup
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Setup logger
logger = Logger.new(STDOUT)
logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

# Change to project root directory
project_root = File.expand_path('../..', __FILE__)
Dir.chdir(project_root) do
  
  # Create migration manager
  manager = BlueHydra::MigrationManager.new(
    options[:source_db],
    backup_dir: options[:backup_dir],
    logger: logger,
    dry_run: options[:dry_run]
  )
  
  if options[:restore]
    # Restore mode
    begin
      manager.restore_from_backup(options[:restore])
      puts "✅ Database restored successfully from: #{options[:restore]}"
    rescue => e
      puts "❌ Restore failed: #{e.message}"
      exit 1
    end
  else
    # Migration mode
    puts "=" * 60
    puts "DataMapper to Sequel Migration Tool"
    puts "=" * 60
    puts
    puts "Configuration:"
    puts "  Source Database: #{options[:source_db]}"
    puts "  Backup Directory: #{options[:backup_dir]}"
    puts "  Mode: #{options[:dry_run] ? 'DRY RUN' : 'LIVE'}"
    puts
    
    if options[:dry_run]
      puts "⚠️  DRY RUN MODE - No changes will be made to the database"
      puts
    else
      puts "⚠️  WARNING: This will create a new Sequel database from your DataMapper database."
      puts "A backup will be created, but please ensure you have your own backups as well."
      puts
      print "Continue? (y/N): "
      
      response = STDIN.gets.chomp.downcase
      unless response == 'y' || response == 'yes'
        puts "Migration cancelled."
        exit 0
      end
    end
    
    begin
      # Run migration
      report = manager.migrate_to_sequel
      
      puts
      puts "=" * 60
      puts "Migration Report"
      puts "=" * 60
      puts "✅ Migration completed successfully!"
      puts
      puts "Statistics:"
      puts "  Devices migrated: #{report[:statistics][:devices][:sequel_count]}"
      puts "  Sync versions migrated: #{report[:statistics][:sync_versions][:sequel_count]}"
      puts
      
      if options[:dry_run]
        puts "This was a dry run. To perform the actual migration, run without --dry-run"
      else
        puts "Next steps:"
        puts "1. Test the new Sequel database: blue_hydra_sequel.db"
        puts "2. Update your Blue Hydra configuration to use Sequel models"
        puts "3. Run Blue Hydra with the new database"
        puts
        puts "If you need to rollback, use:"
        puts "  ruby scripts/migrate_to_sequel.rb --restore <backup_path>"
      end
      
    rescue => e
      puts
      puts "❌ Migration failed: #{e.message}"
      puts
      puts "Error details:"
      puts e.backtrace[0..5].join("\n")
      exit 1
    end
  end
end 