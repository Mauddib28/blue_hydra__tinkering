require 'spec_helper'
require 'blue_hydra/dbus_manager'

RSpec.describe BlueHydra::DBusManager do
  let(:logger) { instance_double(Logger, info: nil, debug: nil, error: nil, warn: nil) }
  let(:mock_bus) { instance_double(DBus::SystemBus) }
  let(:mock_service) { double('DBus Service') }
  
  before do
    allow(BlueHydra).to receive(:logger).and_return(logger)
    allow(File).to receive(:exist?).with("/run/dbus/system_bus_socket").and_return(true)
  end
  
  describe '#initialize' do
    it 'initializes with default system bus' do
      manager = described_class.new
      expect(manager.state).to eq(BlueHydra::DBusManager::DISCONNECTED)
      expect(manager.connection_attempts).to eq(0)
    end
    
    it 'accepts custom options' do
      manager = described_class.new(:session, max_reconnect_attempts: 10)
      expect(manager.instance_variable_get(:@options)[:max_reconnect_attempts]).to eq(10)
    end
  end
  
  describe '#connect' do
    let(:manager) { described_class.new }
    
    context 'when connection succeeds' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
        allow(mock_bus).to receive(:service).with("org.freedesktop.DBus").and_return(mock_service)
      end
      
      it 'connects successfully' do
        expect(manager.connect).to be true
        expect(manager.state).to eq(BlueHydra::DBusManager::CONNECTED)
        expect(manager.connected?).to be true
      end
      
      it 'starts health monitoring' do
        expect(manager).to receive(:start_health_monitoring)
        manager.connect
      end
      
      it 'returns true if already connected' do
        manager.connect
        expect(manager.connect).to be true
      end
    end
    
    context 'when D-Bus socket is missing' do
      before do
        allow(File).to receive(:exist?).with("/run/dbus/system_bus_socket").and_return(false)
      end
      
      it 'fails to connect' do
        expect(manager.connect).to be false
        expect(manager.state).to eq(BlueHydra::DBusManager::FAILED)
        expect(manager.last_error).to be_a(DBus::Error)
      end
    end
    
    context 'when connection fails' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_raise(DBus::Error, "Connection refused")
      end
      
      it 'handles connection failure' do
        expect(manager.connect).to be false
        expect(manager.state).to eq(BlueHydra::DBusManager::FAILED)
        expect(manager.connection_attempts).to eq(1)
      end
      
      it 'starts reconnection thread within retry limits' do
        expect(manager).to receive(:start_reconnection_thread)
        manager.connect
      end
    end
  end
  
  describe '#disconnect' do
    let(:manager) { described_class.new }
    
    before do
      allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
      allow(mock_bus).to receive(:service).and_return(mock_service)
      manager.connect
    end
    
    it 'disconnects and resets state' do
      manager.disconnect
      expect(manager.state).to eq(BlueHydra::DBusManager::DISCONNECTED)
      expect(manager.connected?).to be false
      expect(manager.connection_attempts).to eq(0)
    end
    
    it 'stops monitoring threads' do
      expect(manager).to receive(:stop_health_monitoring)
      expect(manager).to receive(:stop_reconnection_thread)
      manager.disconnect
    end
  end
  
  describe '#service' do
    let(:manager) { described_class.new }
    
    context 'when connected' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
        allow(mock_bus).to receive(:service).and_return(mock_service)
        manager.connect
      end
      
      it 'returns the requested service' do
        expect(mock_bus).to receive(:service).with("org.bluez").and_return(mock_service)
        expect(manager.service("org.bluez")).to eq(mock_service)
      end
    end
    
    context 'when not connected' do
      it 'attempts to connect first' do
        expect(manager).to receive(:connect).and_return(false)
        expect { manager.service("org.bluez") }.to raise_error(DBus::Error, "Not connected to D-Bus")
      end
    end
  end
  
  describe '#bluez_service' do
    let(:manager) { described_class.new }
    
    it 'returns the BlueZ service' do
      expect(manager).to receive(:service).with("org.bluez").and_return(mock_service)
      expect(manager.bluez_service).to eq(mock_service)
    end
  end
  
  describe '#with_connection' do
    let(:manager) { described_class.new }
    
    context 'when operation succeeds' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
        allow(mock_bus).to receive(:service).and_return(mock_service)
        manager.connect
      end
      
      it 'yields the bus and returns result' do
        result = manager.with_connection { |bus| "success" }
        expect(result).to eq("success")
      end
    end
    
    context 'when operation fails' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
        allow(mock_bus).to receive(:service).and_return(mock_service)
        manager.connect
      end
      
      it 'attempts reconnection on D-Bus error' do
        # First let the bus.service call raise an error
        call_count = 0
        allow(mock_bus).to receive(:service) do
          call_count += 1
          if call_count == 1
            raise DBus::Error, "Lost connection"
          else
            mock_service
          end
        end
        
        # The manager should connect and retry
        expect(manager).to receive(:connect).and_call_original
        
        # Should not raise error because reconnection succeeds
        result = manager.with_connection { |bus| bus.service("test") }
        expect(result).to eq(mock_service)
      end
      
      it 'raises error if reconnection fails' do
        allow(mock_bus).to receive(:service).and_raise(DBus::Error, "Lost connection")
        expect(manager).to receive(:connect).and_return(false)
        
        expect {
          manager.with_connection { |bus| bus.service("test") }
        }.to raise_error(DBus::Error)
      end
    end
  end
  
  describe '#stats' do
    let(:manager) { described_class.new }
    
    it 'returns connection statistics' do
      stats = manager.stats
      expect(stats).to include(
        state: BlueHydra::DBusManager::DISCONNECTED,
        bus_type: :system,
        connection_attempts: 0,
        last_error: nil,
        health_check_active: false
      )
    end
    
    context 'after failed connection' do
      before do
        allow(DBus::SystemBus).to receive(:instance).and_raise(DBus::Error, "Test error")
        manager.connect
      end
      
      it 'includes error information' do
        stats = manager.stats
        expect(stats[:state]).to eq(BlueHydra::DBusManager::FAILED)
        expect(stats[:last_error]).to eq("Test error")
        expect(stats[:connection_attempts]).to eq(1)
      end
    end
  end
  
  describe 'health monitoring' do
    let(:manager) { described_class.new(:system, health_check_interval: 0.1) }
    
    before do
      allow(DBus::SystemBus).to receive(:instance).and_return(mock_bus)
      allow(mock_bus).to receive(:service).and_return(mock_service)
    end
    
    it 'performs periodic health checks' do
      manager.connect
      
      # Allow health check to run
      expect(mock_bus).to receive(:service).with("org.freedesktop.DBus").at_least(:twice)
      sleep 0.3
      
      manager.disconnect
    end
    
    it 'triggers reconnection on health check failure' do
      manager.connect
      
      # Simulate health check failure
      allow(mock_bus).to receive(:service).and_raise(DBus::Error, "Connection lost")
      expect(manager).to receive(:start_reconnection_thread)
      
      sleep 0.2
      
      manager.disconnect
    end
  end
  
  describe 'reconnection logic' do
    let(:manager) { described_class.new(:system, reconnect_delay: 0.1, max_reconnect_attempts: 2) }
    
    before do
      allow(DBus::SystemBus).to receive(:instance).and_raise(DBus::Error, "Connection failed")
    end
    
    it 'attempts reconnection up to max attempts' do
      2.times { manager.connect }
      
      expect(manager.connection_attempts).to eq(2)
      expect(logger).to have_received(:error).with(/Max reconnection attempts reached/)
    end
  end
end 