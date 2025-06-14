require 'spec_helper'
require 'blue_hydra/models/device'

RSpec.describe BlueHydra::Models::Device do
  # Connect to test database
  before(:all) do
    BlueHydra::SequelDB.connect(database: ':memory:', test: true)
  end

  # Reset database for each test
  before(:each) do
    BlueHydra::Models::Device.dataset.destroy
  end

  describe 'basic properties' do
    it 'creates a device with minimal attributes' do
      device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:FF',
        status: 'online'
      )
      
      expect(device).to be_valid
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
      expect(device.status).to eq('online')
      expect(device.uuid).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      expect(device.uap_lap).to eq('CC:DD:EE:FF')
    end

    it 'sets default values' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      
      expect(device.classic_mode).to be false
      expect(device.le_mode).to be false
      expect(device.last_seen).to be_a(Integer)
    end
  end

  describe 'validations' do
    it 'requires a valid MAC address' do
      device = BlueHydra::Models::Device.new(address: 'invalid')
      expect(device).not_to be_valid
      expect(device.errors[:address]).to include('is not a valid MAC address')
    end

    it 'accepts various MAC address formats' do
      ['AA:BB:CC:DD:EE:FF', 'aa:bb:cc:dd:ee:ff', 'AA-BB-CC-DD-EE-FF'].each do |mac|
        device = BlueHydra::Models::Device.new(address: mac)
        expect(device).to be_valid
      end
    end

    it 'normalizes MAC address to uppercase' do
      device = BlueHydra::Models::Device.create(address: 'aa:bb:cc:dd:ee:ff')
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
    end

    it 'validates status values' do
      device = BlueHydra::Models::Device.new(address: 'AA:BB:CC:DD:EE:FF', status: 'invalid')
      expect(device).not_to be_valid
      
      ['online', 'offline'].each do |status|
        device.status = status
        expect(device).to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'sets UUID automatically' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      expect(device.uuid).not_to be_nil
      expect(device.uuid).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'sets UAP/LAP from address' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      expect(device.uap_lap).to eq('CC:DD:EE:FF')
    end

    it 'sets vendor for non-random addresses' do
      allow(Louis).to receive(:lookup).and_return({
        'long_vendor' => 'Test Vendor Inc.',
        'short_vendor' => 'TestVendor'
      })
      
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      expect(device.vendor).to eq('Test Vendor Inc.')
    end

    it 'sets special vendor for random addresses' do
      device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:FF',
        le_address_type: 'Random'
      )
      expect(device.vendor).to eq('N/A - Random Address')
    end
  end

  describe 'JSON field handling' do
    let(:device) { BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF') }

    describe 'RSSI fields' do
      it 'stores and limits classic RSSI values' do
        rssi_values = (1..150).map { |i| -50 - i }
        device.classic_rssi = rssi_values
        device.save
        
        parsed = JSON.parse(device.classic_rssi)
        expect(parsed.length).to eq(100)
        expect(parsed.first).to eq(-101)  # Should keep last 100 values
      end

      it 'stores and limits LE RSSI values' do
        rssi_values = (1..150).map { |i| -60 - i }
        device.le_rssi = rssi_values
        device.save
        
        parsed = JSON.parse(device.le_rssi)
        expect(parsed.length).to eq(100)
        expect(parsed.first).to eq(-111)
      end
    end

    describe 'service UUID fields' do
      it 'stores and deduplicates LE service UUIDs' do
        uuids = ['0x1234', '0x5678', '0x1234', '(UUID 0x9ABC)']
        device.le_service_uuids = uuids
        device.save
        
        parsed = JSON.parse(device.le_service_uuids)
        expect(parsed).to eq(['Unknown (0x1234)', 'Unknown (0x5678)', '(UUID 0x9ABC)'])
      end

      it 'stores and deduplicates classic service UUIDs' do
        uuids = ['0x1111', '(UUID 0x2222)', '0x1111']
        device.classic_service_uuids = uuids
        device.save
        
        parsed = JSON.parse(device.classic_service_uuids)
        expect(parsed).to eq(['Unknown (0x1111)', '(UUID 0x2222)'])
      end
    end

    describe 'feature bitmap fields' do
      it 'stores LE features bitmap as JSON object' do
        bitmaps = [['page0', '0xFF'], ['page1', '0xAB']]
        device.le_features_bitmap = bitmaps
        device.save
        
        parsed = JSON.parse(device.le_features_bitmap)
        expect(parsed).to eq({'page0' => '0xFF', 'page1' => '0xAB'})
      end

      it 'stores classic features bitmap as JSON object' do
        bitmaps = [['page0', '0x12'], ['page2', '0x34']]
        device.classic_features_bitmap = bitmaps
        device.save
        
        parsed = JSON.parse(device.classic_features_bitmap)
        expect(parsed).to eq({'page0' => '0x12', 'page2' => '0x34'})
      end
    end
  end

  describe '.update_or_create_from_result' do
    let(:basic_result) {
      {
        address: ['AA:BB:CC:DD:EE:FF'],
        name: ['Test Device'],
        status: ['online'],
        last_seen: [Time.now.to_i]
      }
    }

    it 'creates a new device from result' do
      expect {
        BlueHydra::Models::Device.update_or_create_from_result(basic_result)
      }.to change { BlueHydra::Models::Device.count }.by(1)
      
      device = BlueHydra::Models::Device.first
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
      expect(device.name).to eq('Test Device')
      expect(device.status).to eq('online')
    end

    it 'updates existing device' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF', name: 'Old Name')
      
      result = basic_result.merge(name: ['New Name'])
      BlueHydra::Models::Device.update_or_create_from_result(result)
      
      device.refresh
      expect(device.name).to eq('New Name')
      expect(BlueHydra::Models::Device.count).to eq(1)
    end

    it 'finds device by UAP/LAP fallback' do
      device = BlueHydra::Models::Device.create(
        address: '00:00:CC:DD:EE:FF',
        uap_lap: 'CC:DD:EE:FF'
      )
      
      BlueHydra::Models::Device.update_or_create_from_result(basic_result)
      expect(BlueHydra::Models::Device.count).to eq(1)
      
      device.refresh
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
    end

    it 'finds iBeacon by proximity trinity' do
      device = BlueHydra::Models::Device.create(
        address: '11:22:33:44:55:66',
        le_proximity_uuid: 'UUID-123',
        le_major_num: '100',
        le_minor_num: '200'
      )
      
      result = {
        address: ['AA:BB:CC:DD:EE:FF'],
        le_proximity_uuid: ['UUID-123'],
        le_major_num: ['100'],
        le_minor_num: ['200']
      }
      
      BlueHydra::Models::Device.update_or_create_from_result(result)
      expect(BlueHydra::Models::Device.count).to eq(1)
      
      device.refresh
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
    end

    it 'handles array attributes correctly' do
      result = basic_result.merge(
        le_rssi: [-50, -55, -60],
        le_service_uuids: ['0x1234', '0x5678'],
        le_features: ['Feature1', 'Feature2']
      )
      
      device = BlueHydra::Models::Device.update_or_create_from_result(result)
      
      expect(JSON.parse(device.le_rssi)).to eq([-50, -55, -60])
      expect(JSON.parse(device.le_service_uuids)).to include('Unknown (0x1234)', 'Unknown (0x5678)')
      expect(JSON.parse(device.le_features)).to eq(['Feature1', 'Feature2'])
    end
  end

  describe '.mark_old_devices_offline' do
    before(:each) do
      # Mock Time.now for consistent testing
      allow(Time).to receive(:now).and_return(Time.at(1234567890))
    end

    it 'marks classic devices offline after 15 minutes' do
      old_device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:01',
        classic_mode: true,
        status: 'online',
        last_seen: Time.now.to_i - (16 * 60)  # 16 minutes ago
      )
      
      new_device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:02',
        classic_mode: true,
        status: 'online',
        last_seen: Time.now.to_i - (10 * 60)  # 10 minutes ago
      )
      
      BlueHydra::Models::Device.mark_old_devices_offline
      
      old_device.refresh
      new_device.refresh
      
      expect(old_device.status).to eq('offline')
      expect(new_device.status).to eq('online')
    end

    it 'marks LE devices offline after 3 minutes' do
      old_device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:03',
        le_mode: true,
        status: 'online',
        last_seen: Time.now.to_i - (4 * 60)  # 4 minutes ago
      )
      
      new_device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:04',
        le_mode: true,
        status: 'online',
        last_seen: Time.now.to_i - (2 * 60)  # 2 minutes ago
      )
      
      BlueHydra::Models::Device.mark_old_devices_offline
      
      old_device.refresh
      new_device.refresh
      
      expect(old_device.status).to eq('offline')
      expect(new_device.status).to eq('online')
    end

    it 'marks very old devices offline (2 weeks)' do
      very_old_device = BlueHydra::Models::Device.create(
        address: 'AA:BB:CC:DD:EE:05',
        status: 'online',
        updated_at: Time.at(Time.now.to_i - (604800 * 3))  # 3 weeks ago
      )
      
      BlueHydra::Models::Device.mark_old_devices_offline
      
      very_old_device.refresh
      expect(very_old_device.status).to eq('offline')
    end
  end

  describe 'custom attribute setters' do
    let(:device) { BlueHydra::Models::Device.new(address: 'AA:BB:CC:DD:EE:FF') }

    it 'sets short_name only if name is not set' do
      device.short_name = 'Short Name'
      expect(device.name).to eq('Short Name')
      
      device.short_name = 'Another Name'
      expect(device.name).to eq('Short Name')  # Should not change
    end

    it 'handles le_address_type correctly' do
      device.le_address_type = 'Random'
      expect(device.le_address_type).to eq('Random')
      
      device.le_address_type = 'Public'
      expect(device.le_address_type).to eq('Public')
      expect(device.le_random_address_type).to be_nil
    end

    it 'merges classic_channels properly' do
      device.classic_channels = ['L2CAP (0x0001)', 'RFCOMM (0x0003)']
      device.classic_channels = ['L2CAP (0x0001)', 'SDP (0x0002)']
      
      channels = JSON.parse(device.classic_channels)
      expect(channels).to include('L2CAP', 'RFCOMM', 'SDP')
      expect(channels).not_to include('0x0001', '0x0002', '0x0003')
    end
  end

  describe 'thread safety' do
    it 'handles concurrent updates safely' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      
      threads = 10.times.map do |i|
        Thread.new do
          10.times do |j|
            result = {
              address: ['AA:BB:CC:DD:EE:FF'],
              le_rssi: [-50 - i - j],
              name: ["Thread #{i} Update #{j}"]
            }
            BlueHydra::Models::Device.update_or_create_from_result(result)
          end
        end
      end
      
      threads.each(&:join)
      
      # Should still have only one device
      expect(BlueHydra::Models::Device.count).to eq(1)
      
      device.refresh
      expect(device.address).to eq('AA:BB:CC:DD:EE:FF')
      
      # RSSI should have values (limited to 100)
      rssi = JSON.parse(device.le_rssi)
      expect(rssi.length).to be <= 100
    end
  end

  describe 'DataMapper compatibility' do
    it 'supports .all method with conditions' do
      BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:01', status: 'online')
      BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:02', status: 'offline')
      BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:03', status: 'online')
      
      online_devices = BlueHydra::Models::Device.all(status: 'online')
      expect(online_devices.count).to eq(2)
      expect(online_devices.map(&:address)).to include('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:03')
    end

    it 'supports attribute_dirty? method' do
      device = BlueHydra::Models::Device.create(address: 'AA:BB:CC:DD:EE:FF')
      device.name = 'New Name'
      
      expect(device.attribute_dirty?(:name)).to be true
      expect(device.attribute_dirty?(:address)).to be false
    end
  end
end 