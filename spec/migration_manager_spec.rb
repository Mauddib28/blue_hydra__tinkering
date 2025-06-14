require 'spec_helper'
require_relative '../lib/blue_hydra/migration_manager'

RSpec.describe BlueHydra::MigrationManager do
  let(:test_db_path) { 'spec/fixtures/test_blue_hydra.db' }
  let(:backup_dir) { 'spec/tmp/backups' }
  let(:manager) { described_class.new(test_db_path, backup_dir: backup_dir, dry_run: true) }
  
  before(:each) do
    # Clean up test directories
    FileUtils.rm_rf(backup_dir)
    FileUtils.mkdir_p(File.dirname(test_db_path))
    
    # Create a test DataMapper database
    setup_test_database
  end
  
  after(:each) do
    # Clean up
    FileUtils.rm_rf(backup_dir)
    FileUtils.rm_f(test_db_path)
    FileUtils.rm_f("#{test_db_path.sub('.db', '_sequel.db')}")
  end
  
  def setup_test_database
    # Setup DataMapper with test database
    DataMapper.setup(:default, "sqlite://#{File.absolute_path(test_db_path)}")
    
    # Define models inline for testing
    class TestDevice
      include DataMapper::Resource
      storage_names[:default] = 'blue_hydra_devices'
      
      property :id, Serial
      property :uuid, String, length: 255
      property :name, String, length: 255
      property :status, String, length: 255
      property :address, String, length: 255
      property :uap_lap, String, length: 255
      property :vendor, Text
      property :classic_mode, Boolean, default: false
      property :le_mode, Boolean, default: false
      property :created_at, DateTime
      property :updated_at, DateTime
      property :last_seen, Integer
    end
    
    class TestSyncVersion
      include DataMapper::Resource
      storage_names[:default] = 'blue_hydra_sync_versions'
      
      property :id, Serial
      property :version, String, length: 255
    end
    
    DataMapper.finalize
    DataMapper.auto_migrate!
    
    # Add test data
    TestDevice.create(
      uuid: 'test-uuid-1',
      name: 'Test Device 1',
      status: 'online',
      address: 'AA:BB:CC:DD:EE:FF',
      uap_lap: 'CC:DD:EE:FF',
      vendor: 'Test Vendor',
      classic_mode: true,
      le_mode: false,
      last_seen: Time.now.to_i
    )
    
    TestDevice.create(
      uuid: 'test-uuid-2',
      name: 'Test Device 2',
      status: 'offline',
      address: '11:22:33:44:55:66',
      uap_lap: '33:44:55:66',
      vendor: 'Another Vendor',
      classic_mode: false,
      le_mode: true,
      last_seen: Time.now.to_i - 3600
    )
    
    TestSyncVersion.create(version: '1.0.0')
  end
  
  describe '#initialize' do
    it 'creates backup directory if it does not exist' do
      expect(Dir.exist?(backup_dir)).to be true
    end
    
    it 'sets default options correctly' do
      expect(manager.source_db_path).to eq(test_db_path)
      expect(manager.backup_dir).to eq(backup_dir)
    end
  end
  
  describe '#create_backup' do
    context 'in dry run mode' do
      it 'returns backup path without creating file' do
        backup_path = manager.create_backup
        expect(backup_path).to include('blue_hydra_backup_')
        expect(File.exist?(backup_path)).to be false
      end
    end
    
    context 'in live mode' do
      let(:manager) { described_class.new(test_db_path, backup_dir: backup_dir, dry_run: false) }
      
      it 'creates backup file and metadata' do
        backup_path = manager.create_backup
        
        expect(File.exist?(backup_path)).to be true
        expect(File.exist?("#{backup_path}.json")).to be true
        
        # Check metadata content
        metadata = JSON.parse(File.read("#{backup_path}.json"))
        expect(metadata['source_path']).to eq(test_db_path)
        expect(metadata['migration_version']).to eq('1.0.0')
      end
    end
  end
  
  describe '#migrate_to_sequel' do
    context 'with valid source database' do
      it 'performs dry run migration without errors' do
        expect { manager.migrate_to_sequel }.not_to raise_error
      end
      
      it 'returns migration report' do
        report = manager.migrate_to_sequel
        
        expect(report).to be_a(Hash)
        expect(report[:statistics]).to include(:devices, :sync_versions)
        expect(report[:validation][:status]).to eq('passed')
      end
    end
    
    context 'with missing source database' do
      let(:manager) { described_class.new('non_existent.db', backup_dir: backup_dir) }
      
      it 'raises error' do
        expect { manager.migrate_to_sequel }.to raise_error(/Source database not found/)
      end
    end
  end
  
  describe '#restore_from_backup' do
    let(:manager) { described_class.new(test_db_path, backup_dir: backup_dir, dry_run: false) }
    
    context 'with valid backup' do
      it 'restores database from backup' do
        # Create a backup first
        backup_path = manager.create_backup
        
        # Modify original database
        TestDevice.all.destroy
        expect(TestDevice.count).to eq(0)
        
        # Restore from backup
        manager.restore_from_backup(backup_path)
        
        # Verify restoration
        expect(TestDevice.count).to eq(2)
      end
    end
    
    context 'with missing backup' do
      it 'raises error' do
        expect { manager.restore_from_backup('non_existent_backup.db') }
          .to raise_error(/Backup not found/)
      end
    end
  end
  
  describe 'data validation' do
    it 'validates record counts match' do
      # This would be tested in integration tests
      # Here we just verify the validation logic exists
      expect(manager).to respond_to(:validate_migration)
    end
    
    it 'validates individual records' do
      expect(manager).to respond_to(:validate_device_record)
    end
  end
  
  describe 'batch processing' do
    before do
      # Add more test devices
      50.times do |i|
        TestDevice.create(
          uuid: "test-uuid-#{i}",
          name: "Device #{i}",
          status: ['online', 'offline'].sample,
          address: "#{i.to_s(16)}:#{i.to_s(16)}:#{i.to_s(16)}:#{i.to_s(16)}:#{i.to_s(16)}:#{i.to_s(16)}",
          last_seen: Time.now.to_i - i * 60
        )
      end
    end
    
    it 'processes devices in batches' do
      expect { manager.migrate_to_sequel }.not_to raise_error
    end
  end
end 