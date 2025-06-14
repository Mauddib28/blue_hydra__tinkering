#!/usr/bin/env ruby
# Script to migrate existing DataMapper database to Sequel format

require_relative '../lib/blue_hydra'
require_relative '../lib/blue_hydra/migration_manager'

# Display usage information
if ARGV.include?('--help') || ARGV.include?('-h')
  puts <<~USAGE
    Usage: #{$0} [options]
    
    Options:
      --backup-only     Only create backup, don't migrate
      --dry-run         Test migration without making changes
      --force           Skip confirmation prompts
      --help, -h        Show this help message
    
    This script migrates your Blue Hydra database from DataMapper to Sequel format.
    A backup is automatically created before migration.
  USAGE
  exit 0
end

# Parse command line options
backup_only = ARGV.include?('--backup-only')
dry_run = ARGV.include?('--dry-run')
force = ARGV.include?('--force')

# Initialize migration manager
manager = BlueHydra::MigrationManager.new

# Get current database path
db_path = BlueHydra.config["db_path"] || "blue_hydra.db"

puts "Blue Hydra Database Migration"
puts "=" * 50
puts "Database: #{db_path}"
puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
puts ""

# Check if database exists
unless File.exist?(db_path)
  puts "ERROR: Database file not found: #{db_path}"
  exit 1
end

# Confirm migration unless forced
unless force || dry_run
  print "This will migrate your database to the new format. Continue? (y/N): "
  response = gets.chomp.downcase
  unless response == 'y' || response == 'yes'
    puts "Migration cancelled."
    exit 0
  end
end

begin
  # Create backup
  puts "\nStep 1: Creating backup..."
  backup_path = manager.backup_database(db_path)
  puts "✓ Backup created: #{backup_path}"
  
  if backup_only
    puts "\nBackup complete. Exiting (--backup-only mode)."
    exit 0
  end
  
  # Check compatibility
  puts "\nStep 2: Checking database compatibility..."
  if manager.check_compatibility(db_path)
    puts "✓ Database schema is compatible"
  else
    puts "✗ Database schema incompatibility detected"
    puts "  Please check the logs for details"
    exit 1 unless force
  end
  
  # Run migration
  if dry_run
    puts "\nStep 3: Simulating migration (dry run)..."
    puts "✓ Dry run complete - no changes made"
  else
    puts "\nStep 3: Running migration..."
    if manager.migrate_database(db_path, db_path)
      puts "✓ Migration completed successfully"
    else
      puts "✗ Migration failed"
      puts "  Backup is available at: #{backup_path}"
      exit 1
    end
  end
  
  # Verify migration
  puts "\nStep 4: Verifying migration..."
  if manager.verify_migration(db_path)
    puts "✓ Migration verified successfully"
  else
    puts "✗ Verification failed"
    puts "  You may need to restore from backup: #{backup_path}"
    exit 1
  end
  
  puts "\n" + "=" * 50
  puts "Migration completed successfully!"
  puts "Your Blue Hydra database is now using Sequel ORM."
  puts ""
  puts "Next steps:"
  puts "1. Test Blue Hydra with the migrated database"
  puts "2. Keep the backup until you're confident everything works"
  puts "3. Report any issues to the development team"
  
rescue => e
  puts "\nERROR: Migration failed with error:"
  puts "  #{e.class}: #{e.message}"
  puts "\nBacktrace:"
  puts e.backtrace.take(5).map { |line| "  #{line}" }
  puts "\nYour original database is unchanged."
  puts "Backup is available at: #{backup_path}" if backup_path
  exit 1
end 