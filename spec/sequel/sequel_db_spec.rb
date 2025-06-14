require 'spec_helper'
require_relative '../../lib/blue_hydra/sequel_db'

describe BlueHydra::SequelDB do
  describe ".config" do
    it "returns database configuration" do
      config = described_class.config
      
      expect(config[:adapter]).to eq('sqlite')
      expect(config[:database]).to eq(':memory:') # In test mode
      expect(config[:max_connections]).to eq(10)
    end
    
    it "uses memory database in test mode" do
      expect(ENV["BLUE_HYDRA"]).to eq("test")
      expect(described_class.database_path).to eq(':memory:')
    end
  end
  
  describe ".connect!" do
    after do
      described_class.disconnect!
    end
    
    it "establishes database connection" do
      db = described_class.connect!
      
      expect(db).to be_a(Sequel::Database)
      expect(described_class.connected?).to be true
    end
    
    it "applies SQLite optimizations" do
      db = described_class.connect!
      
      # Check pragmas were set
      sync = db.fetch("PRAGMA synchronous").first[:synchronous]
      expect(sync).to eq(0) # OFF = 0
      
      journal = db.fetch("PRAGMA journal_mode").first[:journal_mode]
      expect(journal).to eq("memory")
    end
    
    it "loads Sequel plugins" do
      described_class.connect!
      
      # Check global plugins are loaded
      expect(Sequel::Model.plugins).to include(:timestamps)
      expect(Sequel::Model.plugins).to include(:validation_helpers)
      expect(Sequel::Model.plugins).to include(:json_serializer)
      expect(Sequel::Model.plugins).to include(:dirty)
    end
  end
  
  describe ".disconnect!" do
    it "closes database connection" do
      described_class.connect!
      expect(described_class.connected?).to be true
      
      described_class.disconnect!
      expect(described_class.connected?).to be false
    end
  end
  
  describe ".migrate!" do
    before do
      described_class.connect!
    end
    
    after do
      described_class.disconnect!
    end
    
    it "runs migrations" do
      # Run migrations
      described_class.migrate!
      
      # Check tables were created
      tables = described_class.db.tables
      expect(tables).to include(:blue_hydra_devices)
      expect(tables).to include(:blue_hydra_sync_versions)
    end
    
    it "creates proper schema" do
      described_class.migrate!
      
      # Check device table columns
      columns = described_class.db[:blue_hydra_devices].columns
      expect(columns).to include(:id)
      expect(columns).to include(:address)
      expect(columns).to include(:name)
      expect(columns).to include(:classic_mode)
      expect(columns).to include(:le_mode)
      expect(columns).to include(:created_at)
      expect(columns).to include(:updated_at)
    end
    
    it "can migrate to specific version" do
      # Migrate to version 0 (no tables)
      described_class.migrate!(0)
      expect(described_class.db.tables).not_to include(:blue_hydra_devices)
      
      # Migrate to version 1
      described_class.migrate!(1)
      expect(described_class.db.tables).to include(:blue_hydra_devices)
    end
  end
  
  describe ".integrity_check" do
    before do
      described_class.connect!
    end
    
    after do
      described_class.disconnect!
    end
    
    it "returns true for valid database" do
      expect(described_class.integrity_check).to be true
    end
  end
  
  describe ".stats" do
    before do
      described_class.connect!
      described_class.migrate!
    end
    
    after do
      described_class.disconnect!
    end
    
    it "returns database statistics" do
      stats = described_class.stats
      
      expect(stats[:tables]).to include(:blue_hydra_devices)
      expect(stats[:device_count]).to eq(0)
      expect(stats[:online_devices]).to eq(0)
      expect(stats[:offline_devices]).to eq(0)
    end
    
    it "counts devices correctly" do
      # Add some test data
      db = described_class.db
      db[:blue_hydra_devices].insert(
        address: 'AA:BB:CC:DD:EE:FF',
        status: 'online',
        created_at: Time.now,
        updated_at: Time.now
      )
      db[:blue_hydra_devices].insert(
        address: '11:22:33:44:55:66',
        status: 'offline',
        created_at: Time.now,
        updated_at: Time.now
      )
      
      stats = described_class.stats
      expect(stats[:device_count]).to eq(2)
      expect(stats[:online_devices]).to eq(1)
      expect(stats[:offline_devices]).to eq(1)
    end
  end
  
  describe ".transaction" do
    before do
      described_class.connect!
      described_class.migrate!
    end
    
    after do
      described_class.disconnect!
    end
    
    it "executes block in transaction" do
      expect {
        described_class.transaction do
          described_class.db[:blue_hydra_devices].insert(
            address: 'AA:BB:CC:DD:EE:FF',
            created_at: Time.now,
            updated_at: Time.now
          )
        end
      }.to change { described_class.db[:blue_hydra_devices].count }.by(1)
    end
    
    it "rolls back on error" do
      expect {
        described_class.transaction do
          described_class.db[:blue_hydra_devices].insert(
            address: 'AA:BB:CC:DD:EE:FF',
            created_at: Time.now,
            updated_at: Time.now
          )
          raise "Test error"
        end
      }.to raise_error("Test error")
      
      expect(described_class.db[:blue_hydra_devices].count).to eq(0)
    end
  end
end 