require 'spec_helper'
require 'blue_hydra/discovery_service'

RSpec.describe BlueHydra::DiscoveryService do
  let(:logger) { instance_double(Logger, info: nil, debug: nil, error: nil, warn: nil) }
  let(:mock_dbus_manager) { instance_double(BlueHydra::DBusManager) }
  let(:mock_adapter) { instance_double(BlueHydra::BluezAdapter) }
  
  before do
    allow(BlueHydra).to receive(:logger).and_return(logger)
    allow(BlueHydra).to receive(:config).and_return({ "bt_device" => "hci0" })
    allow(BlueHydra).to receive(:info_scan).and_return(true)
    allow(File).to receive(:exist?).with("/run/dbus/system_bus_socket").and_return(true)
  end
  
  describe '#initialize' do
    it 'sets default values' do
      service = described_class.new
      expect(service.enabled).to be true
      expect(service.discovery_time).to eq(30) # info_scan is true
    end
    
    it 'uses custom discovery time' do
      service = described_class.new(nil, discovery_time: 60)
      expect(service.discovery_time).to eq(60)
    end
    
    it 'uses longer discovery time when info_scan is false' do
      allow(BlueHydra).to receive(:info_scan).and_return(false)
      service = described_class.new
      expect(service.discovery_time).to eq(180)
    end
  end
  
  describe '#connect' do
    let(:service) { described_class.new }
    
    before do
      allow(BlueHydra::DBusManager).to receive(:new).and_return(mock_dbus_manager)
      allow(BlueHydra::BluezAdapter).to receive(:new).and_return(mock_adapter)
    end
    
    context 'when D-Bus is not available' do
      before do
        allow(File).to receive(:exist?).with("/run/dbus/system_bus_socket").and_return(false)
      end
      
      it 'returns false and disables service' do
        expect(service.connect).to be false
        expect(service.enabled).to be false
        expect(logger).to have_received(:warn).with(/D-Bus system bus not available/)
      end
    end
    
    context 'when D-Bus connection fails' do
      before do
        allow(mock_dbus_manager).to receive(:connect).and_return(false)
      end
      
      it 'returns false and disables service' do
        expect(service.connect).to be false
        expect(service.enabled).to be false
      end
    end
    
    context 'when adapter is not found' do
      before do
        allow(mock_dbus_manager).to receive(:connect).and_return(true)
        allow(BlueHydra::BluezAdapter).to receive(:new).and_raise(BlueHydra::AdapterNotFoundError, "No adapter")
      end
      
      it 'returns false and disables service' do
        expect(service.connect).to be false
        expect(service.enabled).to be false
      end
    end
    
    context 'when connection succeeds' do
      before do
        allow(mock_dbus_manager).to receive(:connect).and_return(true)
        allow(mock_adapter).to receive(:powered?).and_return(true)
        allow(mock_adapter).to receive(:address).and_return("AA:BB:CC:DD:EE:FF")
      end
      
      it 'connects successfully' do
        expect(service.connect).to be true
        expect(service.adapter).to eq(mock_adapter)
      end
      
      it 'powers on adapter if needed' do
        allow(mock_adapter).to receive(:powered?).and_return(false)
        allow(mock_adapter).to receive(:powered=).with(true)
        
        expect(service.connect).to be true
        expect(mock_adapter).to have_received(:powered=).with(true)
      end
    end
  end
  
  describe '#run_discovery' do
    let(:service) { described_class.new(nil, discovery_time: 2) }
    
    before do
      allow(BlueHydra::DBusManager).to receive(:new).and_return(mock_dbus_manager)
      allow(BlueHydra::BluezAdapter).to receive(:new).and_return(mock_adapter)
      allow(mock_dbus_manager).to receive(:connect).and_return(true)
      allow(mock_adapter).to receive(:powered?).and_return(true)
      allow(mock_adapter).to receive(:address).and_return("AA:BB:CC:DD:EE:FF")
    end
    
    context 'when not enabled' do
      before do
        service.enabled = false
      end
      
      it 'returns :disabled' do
        expect(service.run_discovery).to eq(:disabled)
      end
    end
    
    context 'when not connected' do
      it 'returns :not_connected' do
        expect(service.run_discovery).to eq(:not_connected)
      end
    end
    
    context 'when connected' do
      before do
        service.connect
        allow(mock_adapter).to receive(:connected?).and_return(true)
        allow(mock_adapter).to receive(:discovering?).and_return(false)
        allow(mock_adapter).to receive(:start_discovery).and_return(true)
        allow(mock_adapter).to receive(:stop_discovery).and_return(true)
      end
      
      it 'runs discovery successfully' do
        expect(service.run_discovery).to eq(:success)
        expect(mock_adapter).to have_received(:start_discovery)
        expect(mock_adapter).to have_received(:stop_discovery)
      end
      
      it 'stops existing discovery first' do
        allow(mock_adapter).to receive(:discovering?).and_return(true, false)
        
        expect(service.run_discovery).to eq(:success)
        expect(mock_adapter).to have_received(:stop_discovery).twice
      end
      
      it 'returns :failed if start_discovery fails' do
        allow(mock_adapter).to receive(:start_discovery).and_return(false)
        
        expect(service.run_discovery).to eq(:failed)
      end
      
      it 'handles BluezNotReadyError' do
        allow(mock_adapter).to receive(:start_discovery).and_raise(BluezNotReadyError, "Not ready")
        
        expect(service.run_discovery).to eq(:not_ready)
      end
    end
  end
  
  describe '#connected?' do
    let(:service) { described_class.new }
    
    it 'returns false when not connected' do
      expect(service.connected?).to be false
    end
    
    it 'returns true when connected' do
      allow(BlueHydra::DBusManager).to receive(:new).and_return(mock_dbus_manager)
      allow(BlueHydra::BluezAdapter).to receive(:new).and_return(mock_adapter)
      allow(mock_dbus_manager).to receive(:connect).and_return(true)
      allow(mock_adapter).to receive(:powered?).and_return(true)
      allow(mock_adapter).to receive(:address).and_return("AA:BB:CC:DD:EE:FF")
      allow(mock_adapter).to receive(:connected?).and_return(true)
      
      service.connect
      expect(service.connected?).to be true
    end
  end
  
  describe '#disconnect' do
    let(:service) { described_class.new }
    
    before do
      allow(BlueHydra::DBusManager).to receive(:new).and_return(mock_dbus_manager)
      allow(BlueHydra::BluezAdapter).to receive(:new).and_return(mock_adapter)
      allow(mock_dbus_manager).to receive(:connect).and_return(true)
      allow(mock_dbus_manager).to receive(:disconnect)
      allow(mock_adapter).to receive(:powered?).and_return(true)
      allow(mock_adapter).to receive(:address).and_return("AA:BB:CC:DD:EE:FF")
      
      service.connect
    end
    
    it 'disconnects and clears references' do
      service.disconnect
      expect(service.adapter).to be_nil
      expect(service.dbus_manager).to be_nil
      expect(mock_dbus_manager).to have_received(:disconnect)
    end
  end
  
  describe '#devices' do
    let(:service) { described_class.new }
    let(:mock_devices) { [{ address: "11:22:33:44:55:66", name: "Test Device" }] }
    
    context 'when not connected' do
      it 'returns empty array' do
        expect(service.devices).to eq([])
      end
    end
    
    context 'when connected' do
      before do
        allow(BlueHydra::DBusManager).to receive(:new).and_return(mock_dbus_manager)
        allow(BlueHydra::BluezAdapter).to receive(:new).and_return(mock_adapter)
        allow(mock_dbus_manager).to receive(:connect).and_return(true)
        allow(mock_adapter).to receive(:powered?).and_return(true)
        allow(mock_adapter).to receive(:address).and_return("AA:BB:CC:DD:EE:FF")
        allow(mock_adapter).to receive(:connected?).and_return(true)
        allow(mock_adapter).to receive(:devices).and_return(mock_devices)
        
        service.connect
      end
      
      it 'returns devices from adapter' do
        expect(service.devices).to eq(mock_devices)
      end
      
      it 'handles errors gracefully' do
        allow(mock_adapter).to receive(:devices).and_raise("Some error")
        expect(service.devices).to eq([])
        expect(logger).to have_received(:error).with(/Failed to get devices/)
      end
    end
  end
end 