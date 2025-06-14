# Blue Hydra Technical Migration Guide

## Overview

This guide provides detailed technical instructions for migrating Blue Hydra from DataMapper/Ruby 2.7.8 to Sequel/Ruby 3.2+.

## Prerequisites

- Git
- Docker (optional but recommended)
- Ruby version manager (rbenv or rvm)
- SQLite 3
- Development headers (build-essential on Debian/Ubuntu)

## Step 1: Environment Setup

### 1.1 Clone and Branch

```bash
git clone <repository-url>
cd blue_hydra__tinkering
git checkout -b modernization
```

### 1.2 Install Ruby Versions

```bash
# Install both versions for testing
rbenv install 2.7.8
rbenv install 3.2.4
rbenv local 2.7.8  # Start with current version
```

### 1.3 Install Dependencies

```bash
# System dependencies
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  libsqlite3-dev \
  bluez \
  bluez-tools \
  libbluetooth-dev \
  ruby-dev

# Ruby dependencies
gem install bundler:2.1.2
bundle install
```

## Step 2: Create Test Suite

### 2.1 Add RSpec to Gemfile

```ruby
# Gemfile
group :test do
  gem 'rspec', '~> 3.12'
  gem 'rspec-its'
  gem 'database_cleaner-sequel'
  gem 'factory_bot'
  gem 'faker'
end
```

### 2.2 Create Test Structure

```bash
mkdir -p spec/{models,lib,integration,support}
touch spec/spec_helper.rb
```

### 2.3 Configure RSpec

```ruby
# spec/spec_helper.rb
require 'bundler/setup'
Bundler.require(:default, :test)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Database cleanup
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

## Step 3: Database Schema Documentation

### 3.1 Extract Current Schema

```ruby
# scripts/extract_schema.rb
require_relative '../lib/blue_hydra'

File.open('docs/schema.sql', 'w') do |f|
  DataMapper.repository.adapter.select("
    SELECT sql FROM sqlite_master 
    WHERE type='table' 
    ORDER BY name
  ").each do |sql|
    f.puts sql
    f.puts ";\n"
  end
end
```

### 3.2 Document Models

```ruby
# scripts/document_models.rb
require_relative '../lib/blue_hydra'

models = DataMapper::Model.descendants
models.each do |model|
  puts "Model: #{model.name}"
  puts "Properties:"
  model.properties.each do |prop|
    puts "  - #{prop.name}: #{prop.type} #{prop.options}"
  end
  puts ""
end
```

## Step 4: Sequel Setup

### 4.1 Update Gemfile

```ruby
# Gemfile
# Comment out DataMapper gems
# gem 'dm-migrations'
# gem 'dm-sqlite-adapter'
# gem 'dm-timestamps'
# gem 'dm-validations'

# Add Sequel
gem 'sequel', '~> 5.75'
gem 'sqlite3', '~> 1.6'
```

### 4.2 Create Sequel Configuration

```ruby
# lib/blue_hydra/sequel_config.rb
require 'sequel'
require 'logger'

module BlueHydra
  class Database
    class << self
      attr_reader :connection

      def connect(options = {})
        db_path = options[:path] || database_path
        
        @connection = Sequel.sqlite(db_path)
        
        # Configure connection
        @connection.pragma(:synchronous, :off)
        @connection.pragma(:journal_mode, :memory)
        
        # Add plugins
        Sequel::Model.plugin :timestamps
        Sequel::Model.plugin :validation_helpers
        
        # Set up logging
        if BlueHydra.config["log_level"]
          @connection.loggers << BlueHydra.logger
        end
        
        @connection
      end

      private

      def database_path
        if ENV["BLUE_HYDRA"] == "test" || BlueHydra.no_db
          "sqlite::memory:"
        elsif Dir.exist?('/etc/blue_hydra')
          "sqlite:///etc/blue_hydra/blue_hydra.db"
        else
          "sqlite://blue_hydra.db"
        end
      end
    end
  end
end
```

## Step 5: Model Migration

### 5.1 Create Sequel Models

```ruby
# lib/blue_hydra/models/sequel_device.rb
module BlueHydra
  class SequelDevice < Sequel::Model(:blue_hydra_devices)
    # Validations
    def validate
      super
      validates_presence :address
      validates_unique :address
      validates_format /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/, :address
    end
    
    # Associations
    one_to_many :rssi_logs, class: 'BlueHydra::RssiLog', key: :blue_hydra_device_id
    
    # Scopes
    dataset_module do
      def classic_mode
        where(classic_mode: true)
      end
      
      def le_mode
        where(le_mode: true)
      end
      
      def seen_recently(minutes = 5)
        where(last_seen: (Time.now - (minutes * 60))..Time.now)
      end
    end
    
    # Instance methods
    def mode_list
      modes = []
      modes << :cl if classic_mode
      modes << :le if le_mode
      modes << :le_rand if le_random_address_type
      modes
    end
  end
end
```

### 5.2 Create Migration Scripts

```ruby
# db/migrations/001_create_devices.rb
Sequel.migration do
  change do
    create_table(:blue_hydra_devices) do
      primary_key :id
      String :address, size: 255, null: false, unique: true
      String :name, size: 255
      String :short_name, size: 255
      String :vendor, size: 255
      Integer :appearance
      String :company, size: 255
      String :company_type, size: 255
      Integer :lmp_version
      String :manufacturer, size: 255
      String :firmware, size: 255
      Boolean :classic_mode, default: false
      Boolean :le_mode, default: false
      String :le_address_type, size: 255
      Integer :br_type
      Integer :le_type
      DateTime :created_at
      DateTime :updated_at
      DateTime :last_seen
      
      index :address
      index :last_seen
    end
  end
end
```

## Step 6: Query Pattern Migration

### 6.1 DataMapper to Sequel Query Mapping

```ruby
# DataMapper (Old)
Device.all(:address => "AA:BB:CC:DD:EE:FF")
Device.first(:name.like => "%phone%")
Device.all(:created_at.gte => 1.hour.ago)

# Sequel (New)
SequelDevice.where(address: "AA:BB:CC:DD:EE:FF").all
SequelDevice.where(Sequel.like(:name, "%phone%")).first
SequelDevice.where(created_at: (Time.now - 3600)..Time.now).all
```

### 6.2 Update Business Logic

```ruby
# Old DataMapper code
def self.recent_devices
  Device.all(:last_seen.gte => 5.minutes.ago)
end

# New Sequel code
def self.recent_devices
  SequelDevice.seen_recently(5).all
end
```

## Step 7: Ruby 3.x Compatibility

### 7.1 Fix Fixnum References

```bash
# Find all Fixnum references
grep -r "Fixnum" lib/ --include="*.rb"

# Replace with Integer
find lib/ -name "*.rb" -exec sed -i 's/Fixnum/Integer/g' {} +
```

### 7.2 Update Keyword Arguments

```ruby
# Ruby 2.x style
def initialize(options = {})
  @address = options[:address]
  @name = options[:name]
end

# Ruby 3.x style
def initialize(address: nil, name: nil, **options)
  @address = address
  @name = name
  @options = options
end
```

### 7.3 Fix String Encoding

```ruby
# Add to file headers
# encoding: UTF-8
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
```

## Step 8: Thread Safety Improvements

### 8.1 Add Proper Synchronization

```ruby
# lib/blue_hydra/thread_safe_queue.rb
require 'thread'

module BlueHydra
  class ThreadSafeQueue
    def initialize
      @queue = Queue.new
      @mutex = Mutex.new
      @resource = ConditionVariable.new
    end
    
    def push(item)
      @mutex.synchronize do
        @queue.push(item)
        @resource.signal
      end
    end
    
    def pop(timeout = nil)
      @mutex.synchronize do
        if @queue.empty? && timeout
          @resource.wait(@mutex, timeout)
        end
        @queue.pop if !@queue.empty?
      end
    end
  end
end
```

## Step 9: Testing Migration

### 9.1 Create Migration Test

```ruby
# spec/migration/database_migration_spec.rb
require 'spec_helper'

RSpec.describe "Database Migration" do
  let(:old_db) { "spec/fixtures/old_blue_hydra.db" }
  let(:new_db) { "spec/fixtures/migrated.db" }
  
  it "migrates all devices" do
    # Count old records
    old_count = DataMapper.repository.adapter.select(
      "SELECT COUNT(*) FROM blue_hydra_devices"
    ).first
    
    # Run migration
    migrate_database(old_db, new_db)
    
    # Verify count
    new_count = Sequel.sqlite(new_db)[:blue_hydra_devices].count
    expect(new_count).to eq(old_count)
  end
  
  it "preserves all data fields" do
    # Test specific device migration
    old_device = DataMapper.repository.adapter.select(
      "SELECT * FROM blue_hydra_devices LIMIT 1"
    ).first
    
    migrate_database(old_db, new_db)
    
    new_device = Sequel.sqlite(new_db)[:blue_hydra_devices].first
    
    expect(new_device[:address]).to eq(old_device[:address])
    expect(new_device[:name]).to eq(old_device[:name])
    # ... test all fields
  end
end
```

## Step 10: Performance Testing

### 10.1 Create Benchmarks

```ruby
# benchmarks/device_operations.rb
require 'benchmark/ips'
require_relative '../lib/blue_hydra'

Benchmark.ips do |x|
  x.report("DataMapper: Find by address") do
    Device.first(address: "AA:BB:CC:DD:EE:FF")
  end
  
  x.report("Sequel: Find by address") do
    SequelDevice.first(address: "AA:BB:CC:DD:EE:FF")
  end
  
  x.compare!
end
```

## Step 11: Deployment

### 11.1 Update Dockerfile

```dockerfile
# Dockerfile
FROM ruby:3.2.4-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  libsqlite3-dev \
  bluez \
  bluez-tools \
  libbluetooth-dev \
  && rm -rf /var/lib/apt/lists/*

# Set up app
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test
COPY . .

# Run as non-root
RUN useradd -m -s /bin/bash hydra
USER hydra

CMD ["./bin/blue_hydra"]
```

### 11.2 Create Migration Script

```bash
#!/bin/bash
# scripts/migrate_database.sh

set -e

echo "Blue Hydra Database Migration"
echo "============================"

# Backup existing database
if [ -f "blue_hydra.db" ]; then
  echo "Creating backup..."
  cp blue_hydra.db "blue_hydra_backup_$(date +%Y%m%d_%H%M%S).db"
fi

# Run migration
echo "Running migration..."
ruby scripts/migrate_to_sequel.rb

echo "Migration complete!"
echo "Please test the application before removing backups."
```

## Troubleshooting

### Common Issues

1. **Encoding Errors**
   ```bash
   export LC_ALL=en_US.UTF-8
   export LANG=en_US.UTF-8
   ```

2. **Permission Errors**
   ```bash
   sudo usermod -a -G bluetooth $USER
   ```

3. **D-Bus Connection Failed**
   ```bash
   sudo service dbus start
   sudo service bluetooth start
   ```

## Verification Checklist

- [ ] All tests pass on Ruby 3.2+
- [ ] Database migration completes without errors
- [ ] No data loss confirmed
- [ ] Bluetooth discovery works
- [ ] Performance benchmarks acceptable
- [ ] Docker image builds successfully
- [ ] Documentation updated

## Next Steps

1. Run full test suite
2. Deploy to test environment
3. Monitor for 24 hours
4. Compare metrics with legacy version
5. Plan production rollout 