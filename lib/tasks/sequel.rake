namespace :sequel do
  desc "Run database migrations"
  task :migrate, [:version] do |t, args|
    require_relative '../blue_hydra/sequel_db'
    
    puts "Connecting to database..."
    BlueHydra::SequelDB.connect!
    
    version = args[:version] ? args[:version].to_i : nil
    puts "Running migrations#{version ? " to version #{version}" : ""}..."
    
    BlueHydra::SequelDB.migrate!(version)
    
    puts "Migrations complete!"
  end
  
  desc "Rollback database migration"
  task :rollback, [:steps] do |t, args|
    require_relative '../blue_hydra/sequel_db'
    require 'sequel/extensions/migration'
    
    steps = (args[:steps] || 1).to_i
    
    puts "Connecting to database..."
    BlueHydra::SequelDB.connect!
    
    # Get current version
    current = nil
    if BlueHydra::SequelDB.db.tables.include?(:schema_info)
      current = BlueHydra::SequelDB.db[:schema_info].first[:version]
    end
    
    if current && current > 0
      target = [current - steps, 0].max
      puts "Rolling back from version #{current} to #{target}..."
      BlueHydra::SequelDB.migrate!(target)
    else
      puts "No migrations to rollback"
    end
  end
  
  desc "Create a new migration file"
  task :create_migration, [:name] do |t, args|
    unless args[:name]
      puts "Usage: rake sequel:create_migration[migration_name]"
      exit 1
    end
    
    # Find next migration number
    migrations_dir = File.expand_path('../../db/migrations', __dir__)
    existing = Dir[File.join(migrations_dir, '*.rb')].map do |f|
      File.basename(f).match(/^(\d+)_/)[1].to_i
    end.max || 0
    
    next_num = existing + 1
    filename = "%03d_%s.rb" % [next_num, args[:name].downcase.gsub(/\s+/, '_')]
    filepath = File.join(migrations_dir, filename)
    
    File.write(filepath, <<-MIGRATION)
Sequel.migration do
  up do
    # Add your migration code here
  end
  
  down do
    # Add rollback code here
  end
end
MIGRATION
    
    puts "Created migration: #{filepath}"
  end
  
  desc "Show current schema version"
  task :version do
    require_relative '../blue_hydra/sequel_db'
    
    BlueHydra::SequelDB.connect!
    
    if BlueHydra::SequelDB.db.tables.include?(:schema_info)
      version = BlueHydra::SequelDB.db[:schema_info].first[:version]
      puts "Current schema version: #{version}"
    else
      puts "No schema_info table found. Database may not be migrated."
    end
  end
  
  desc "Test Sequel database connection"
  task :test_connection do
    require_relative '../blue_hydra/sequel_db'
    
    puts "Testing Sequel database connection..."
    
    begin
      BlueHydra::SequelDB.connect!
      
      if BlueHydra::SequelDB.connected?
        puts "✓ Successfully connected to database"
        puts "  Database: #{BlueHydra::SequelDB.database_path}"
        
        # Run integrity check
        if BlueHydra::SequelDB.integrity_check
          puts "✓ Database integrity check passed"
        else
          puts "✗ Database integrity check failed"
        end
        
        # Show stats
        stats = BlueHydra::SequelDB.stats
        puts "\nDatabase Statistics:"
        puts "  Tables: #{stats[:tables].join(', ')}"
        puts "  Device count: #{stats[:device_count]}"
        puts "  Online devices: #{stats[:online_devices]}"
        puts "  Offline devices: #{stats[:offline_devices]}"
        puts "  Database size: #{stats[:database_size]} bytes"
      else
        puts "✗ Failed to connect to database"
      end
    rescue => e
      puts "✗ Error: #{e.message}"
      puts e.backtrace
    ensure
      BlueHydra::SequelDB.disconnect!
    end
  end
  
  desc "Compare DataMapper and Sequel schemas"
  task :compare_schemas do
    require_relative '../blue_hydra'
    require_relative '../blue_hydra/sequel_db'
    
    puts "Comparing DataMapper and Sequel schemas...\n"
    
    # Connect to a test database for DataMapper
    DataMapper.setup(:default, 'sqlite::memory:')
    DataMapper.auto_upgrade!
    
    # Get DataMapper schema
    dm_schema = DataMapper.repository.adapter.select("
      SELECT sql FROM sqlite_master 
      WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ")
    
    # Connect Sequel
    BlueHydra::SequelDB.connect!
    BlueHydra::SequelDB.migrate!
    
    # Get Sequel schema
    sequel_schema = BlueHydra::SequelDB.db.fetch("
      SELECT sql FROM sqlite_master 
      WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'schema_info'
      ORDER BY name
    ").map { |r| r[:sql] }
    
    puts "DataMapper Tables:"
    dm_schema.each { |sql| puts "  #{sql.split[2]}" }
    
    puts "\nSequel Tables:"
    sequel_schema.each { |sql| puts "  #{sql.split[2]}" }
    
    puts "\nSchema comparison complete!"
  end
end 