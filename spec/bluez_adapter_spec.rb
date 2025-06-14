require 'spec_helper'
require 'blue_hydra/bluez_adapter'

RSpec.describe BlueHydra::BluezAdapter do
  let(:logger) { instance_double(Logger, info: nil, debug: nil, error: nil, warn: nil) }
  let(:mock_dbus_manager) { instance_double(BlueHydra::DBusManager) }
  let(:mock_service) { double('BlueZ Service') }
  let(:mock_bus) { double('System Bus') }
  let(:mock_adapter_object) { double('Adapter Object') }
  let(:mock_adapter_interface) { double('Adapter Interface') }
  let(:mock_properties_interface) { double('Properties Interface') }
  let(:mock_object_manager) { double('Object Manager') }
  
  let(:managed_objects) do
    {
      "/org/bluez/hci0" => {
        "org.bluez.Adapter1" => {
          "Address" => "AA:BB:CC:DD:EE:FF",
          "Name" => "TestAdapter",
          "Powered" => true,
          "Discovering" => false
        }
      },
      "/org/bluez/hci0/dev_11_22_33_44_55_66" => {
        "org.bluez.Device1" => {
          "Address" => "11:22:33:44:55:66",
          "Name" => "Test Device",
          "Alias" => "Test Device",
          "Paired" => false,
          "Connected" => false,
          "Trusted" => false,
          "Blocked" => false,
          "RSSI" => -65,
          "UUIDs" => ["0000180a-0000-1000-8000-00805f9b34fb"]
        }
      }
    }
  end
  
  before do
    allow(BlueHydra).to receive(:logger).and_return(logger)
    allow(mock_dbus_manager).to receive(:connected?).and_return(true)
    allow(mock_dbus_manager).to receive(:connect).and_return(true)
    allow(mock_dbus_manager).to receive(:bluez_service).and_return(mock_service)
    allow(mock_dbus_manager).to receive(:with_connection).and_yield(mock_bus)
    
    # Setup object manager
    root_object = double('Root Object')
    allow(mock_service).to receive(:object).with("/").and_return(root_object)
    allow(root_object).to receive(:introspect)
    allow(root_object).to receive(:[]).with("org.freedesktop.DBus.ObjectManager").and_return(mock_object_manager)
    allow(mock_object_manager).to receive(:GetManagedObjects).and_return(managed_objects)
    
    # Setup adapter object
    allow(mock_service).to receive(:object).with("/org/bluez/hci0").and_return(mock_adapter_object)
    allow(mock_adapter_object).to receive(:introspect)
    allow(mock_adapter_object).to receive(:[]).with("org.bluez.Adapter1").and_return(mock_adapter_interface)
    allow(mock_adapter_object).to receive(:[]).with("org.freedesktop.DBus.Properties").and_return(mock_properties_interface)
  end
  
  describe '#initialize' do
    context 'with default adapter' do
      it 'connects to the first available adapter' do
        adapter = described_class.new(nil, mock_dbus_manager)
        expect(adapter.adapter_path).to eq("/org/bluez/hci0")
      end
    end
    
    context 'with specific adapter ID' do
      it 'connects to the specified adapter by hci ID' do
        adapter = described_class.new("hci0", mock_dbus_manager)
        expect(adapter.adapter_path).to eq("/org/bluez/hci0")
      end
      
      it 'connects to the specified adapter by address' do
        adapter = described_class.new("AA:BB:CC:DD:EE:FF", mock_dbus_manager)
        expect(adapter.adapter_path).to eq("/org/bluez/hci0")
      end
    end
    
    context 'when adapter not found' do
      let(:managed_objects) { {} }
      
      it 'raises AdapterNotFoundError' do
        expect {
          described_class.new("hci1", mock_dbus_manager)
        }.to raise_error(BlueHydra::AdapterNotFoundError, /Bluetooth adapter not found/)
      end
    end
    
    context 'when D-Bus not connected' do
      before do
        allow(mock_dbus_manager).to receive(:connected?).and_return(false)
        allow(mock_dbus_manager).to receive(:connect).and_return(false)
      end
      
      it 'raises DBusConnectionError' do
        expect {
          described_class.new(nil, mock_dbus_manager)
        }.to raise_error(BlueHydra::DBusConnectionError)
      end
    end
  end
  
  describe '#start_discovery' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    context 'when successful' do
      before do
        allow(mock_adapter_interface).to receive(:StartDiscovery)
      end
      
      it 'starts discovery and returns true' do
        expect(adapter.start_discovery).to be true
        expect(mock_adapter_interface).to have_received(:StartDiscovery)
      end
    end
    
    context 'when adapter not ready' do
      before do
        allow(mock_adapter_interface).to receive(:StartDiscovery).and_raise(DBus::Error, "org.bluez.Error.NotReady")
      end
      
      it 'raises BluezNotReadyError' do
        expect {
          adapter.start_discovery
        }.to raise_error(BluezNotReadyError, /Adapter not ready/)
      end
    end
    
    context 'when discovery already in progress' do
      before do
        allow(mock_adapter_interface).to receive(:StartDiscovery).and_raise(DBus::Error, "org.bluez.Error.InProgress")
      end
      
      it 'returns false and logs warning' do
        expect(adapter.start_discovery).to be false
        expect(logger).to have_received(:warn).with(/Operation already in progress/)
      end
    end
  end
  
  describe '#stop_discovery' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    before do
      allow(mock_adapter_interface).to receive(:StopDiscovery)
    end
    
    it 'stops discovery and returns true' do
      expect(adapter.stop_discovery).to be true
      expect(mock_adapter_interface).to have_received(:StopDiscovery)
    end
  end
  
  describe '#discovering?' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns discovery status' do
      allow(mock_properties_interface).to receive(:Get).with("org.bluez.Adapter1", "Discovering").and_return(true)
      expect(adapter.discovering?).to be true
      
      allow(mock_properties_interface).to receive(:Get).with("org.bluez.Adapter1", "Discovering").and_return(false)
      expect(adapter.discovering?).to be false
    end
  end
  
  describe '#address' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns adapter address' do
      allow(mock_properties_interface).to receive(:Get).with("org.bluez.Adapter1", "Address").and_return("AA:BB:CC:DD:EE:FF")
      expect(adapter.address).to eq("AA:BB:CC:DD:EE:FF")
    end
  end
  
  describe '#name' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns adapter name' do
      allow(mock_properties_interface).to receive(:Get).with("org.bluez.Adapter1", "Name").and_return("TestAdapter")
      expect(adapter.name).to eq("TestAdapter")
    end
  end
  
  describe '#properties' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns all adapter properties' do
      props = { "Address" => "AA:BB:CC:DD:EE:FF", "Name" => "TestAdapter" }
      allow(mock_properties_interface).to receive(:GetAll).with("org.bluez.Adapter1").and_return(props)
      expect(adapter.properties).to eq(props)
    end
  end
  
  describe '#powered=' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'sets adapter power state' do
      allow(mock_properties_interface).to receive(:Set).with("org.bluez.Adapter1", "Powered", true)
      expect(adapter.powered = true).to be true
      expect(mock_properties_interface).to have_received(:Set).with("org.bluez.Adapter1", "Powered", true)
    end
  end
  
  describe '#powered?' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns adapter power status' do
      allow(mock_properties_interface).to receive(:Get).with("org.bluez.Adapter1", "Powered").and_return(true)
      expect(adapter.powered?).to be true
    end
  end
  
  describe '#devices' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns list of discovered devices' do
      devices = adapter.devices
      
      expect(devices).to be_an(Array)
      expect(devices.size).to eq(1)
      
      device = devices.first
      expect(device[:address]).to eq("11:22:33:44:55:66")
      expect(device[:name]).to eq("Test Device")
      expect(device[:rssi]).to eq(-65)
      expect(device[:uuids]).to include("0000180a-0000-1000-8000-00805f9b34fb")
    end
    
    it 'only returns devices for this adapter' do
      # Add device from different adapter
      managed_objects["/org/bluez/hci1/dev_77_88_99_AA_BB_CC"] = {
        "org.bluez.Device1" => { "Address" => "77:88:99:AA:BB:CC" }
      }
      
      devices = adapter.devices
      expect(devices.size).to eq(1)
      expect(devices.first[:address]).to eq("11:22:33:44:55:66")
    end
  end
  
  describe '#remove_device' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    context 'when device exists' do
      before do
        allow(mock_adapter_interface).to receive(:RemoveDevice).with("/org/bluez/hci0/dev_11_22_33_44_55_66")
      end
      
      it 'removes device and returns true' do
        expect(adapter.remove_device("11:22:33:44:55:66")).to be true
        expect(mock_adapter_interface).to have_received(:RemoveDevice).with("/org/bluez/hci0/dev_11_22_33_44_55_66")
      end
    end
    
    context 'when device not found' do
      it 'returns false and logs warning' do
        expect(adapter.remove_device("99:88:77:66:55:44")).to be false
        expect(logger).to have_received(:warn).with(/Device.*not found/)
      end
    end
  end
  
  describe '#connected?' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns true when adapter and D-Bus are connected' do
      expect(adapter.connected?).to be true
    end
    
    it 'returns false when D-Bus is not connected' do
      allow(mock_dbus_manager).to receive(:connected?).and_return(false)
      expect(adapter.connected?).to be false
    end
  end
  
  describe '#path' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    it 'returns adapter path' do
      expect(adapter.path).to eq("/org/bluez/hci0")
    end
  end
  
  describe 'error handling' do
    let(:adapter) { described_class.new(nil, mock_dbus_manager) }
    
    context 'when not authorized' do
      before do
        allow(mock_adapter_interface).to receive(:StartDiscovery).and_raise(DBus::Error, "org.bluez.Error.NotAuthorized")
      end
      
      it 'raises BluezAuthorizationError' do
        expect {
          adapter.start_discovery
        }.to raise_error(BlueHydra::BluezAuthorizationError, /Not authorized/)
      end
    end
    
    context 'with generic D-Bus error' do
      before do
        allow(mock_adapter_interface).to receive(:StartDiscovery).and_raise(DBus::Error, "Generic error")
      end
      
      it 'raises BluezOperationError' do
        expect {
          adapter.start_discovery
        }.to raise_error(BlueHydra::BluezOperationError, /Failed to/)
      end
    end
  end
end 