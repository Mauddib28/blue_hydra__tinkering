# Sequel ORM Database Configuration for Blue Hydra
require 'sequel'
require 'logger'

module BlueHydra
  module SequelDB
    extend self
    
    # Database connection instance
    attr_accessor :db
    
    # Database configuration
    def config
      @config ||= {
        adapter: 'sqlite',
        database: database_path,
        max_connections: 10,
        logger: logger,
        sql_log_level: :debug,
        log_connection_info: false
      }
    end
    
    # Database path logic (matching DataMapper setup)
    def database_path
      # Resolve constants at runtime to avoid loading order issues
      db_dir = begin
        ::BlueHydra::DB_DIR
      rescue NameError
        '/etc/blue_hydra'
      end
      
      db_name = begin
        ::BlueHydra::DB_NAME
      rescue NameError
        'blue_hydra.db'
      end
      
      db_path = begin
        ::BlueHydra::DB_PATH
      rescue NameError
        File.join(db_dir, db_name)
      end
      
      if ENV["BLUE_HYDRA"] == "test" || (defined?(BlueHydra) && BlueHydra.respond_to?(:no_db) && BlueHydra.no_db)
        ':memory:'
      elsif Dir.exist?(db_dir)
        db_path
      else
        db_name
      end
    end
    
    # Logger configuration
    def logger
      return nil if ENV["BLUE_HYDRA"] == "test"
      @logger ||= Logger.new(STDOUT).tap do |log|
        log.level = ENV['LOG_LEVEL'] ? Logger.const_get(ENV['LOG_LEVEL']) : Logger::INFO
      end
    end
    
    # Connect to database
    def connect!
      @db = Sequel.connect(config)
      
      # Apply SQLite optimizations (matching DataMapper settings)
      if config[:adapter] == 'sqlite'
        @db.run('PRAGMA synchronous = OFF')
        @db.run('PRAGMA journal_mode = MEMORY')
      end
      
      # Load Sequel extensions
      @db.extension :pagination
      @db.extension :date_arithmetic
      
      # Load plugins globally
      Sequel::Model.plugin :timestamps, update_on_create: true
      Sequel::Model.plugin :validation_helpers
      Sequel::Model.plugin :json_serializer
      Sequel::Model.plugin :dirty
      Sequel::Model.plugin :association_dependencies
      Sequel::Model.plugin :before_after_save
      
      @db
    end
    
    # Disconnect from database
    def disconnect!
      @db&.disconnect
      @db = nil
    end
    
    # Transaction helper
    def transaction(&block)
      @db.transaction(&block)
    end
    
    # Run migrations
    def migrate!(version = nil)
      require 'sequel/extensions/migration'
      
      migrations_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrations')
      
      if version
        Sequel::Migrator.run(@db, migrations_dir, target: version)
      else
        Sequel::Migrator.run(@db, migrations_dir)
      end
    end
    
    # Check if connected
    def connected?
      @db && @db.test_connection
    rescue
      false
    end
    
    # Database integrity check
    def integrity_check
      return unless connected?
      
      result = @db.fetch('PRAGMA integrity_check').first
      result && result[:integrity_check] == 'ok'
    end
    
    # Get database stats
    def stats
      return {} unless connected?
      
      # Calculate database size safely
      db_size = begin
        File.size(database_path)
      rescue
        0
      end
      
      {
        tables: @db.tables,
        device_count: @db[:blue_hydra_devices].count,
        online_devices: @db[:blue_hydra_devices].where(status: 'online').count,
        offline_devices: @db[:blue_hydra_devices].where(status: 'offline').count,
        database_size: db_size
      }
    rescue
      {}
    end
  end
end 