require 'dbus'
require_relative 'dbus_manager'

module BlueHydra
  # BluezAdapter provides a Ruby interface to the BlueZ D-Bus adapter API
  # Compatible with BlueZ 5.x org.bluez.Adapter1 interface
  class BluezAdapter
    BLUEZ_SERVICE = "org.bluez"
    ADAPTER_INTERFACE = "org.bluez.Adapter1"
    OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager"
    PROPERTIES_INTERFACE = "org.freedesktop.DBus.Properties"
    
    attr_reader :adapter_path, :adapter_object, :dbus_manager
    
    def initialize(adapter_id = nil, dbus_manager = nil)
      @adapter_id = adapter_id
      @dbus_manager = dbus_manager || DBusManager.new
      @adapter_path = nil
      @adapter_object = nil
      @adapter_interface = nil
      @properties_interface = nil
      
      connect_to_adapter
    end
    
    # Start device discovery
    def start_discovery
      with_error_handling("start discovery") do
        @adapter_interface.StartDiscovery
        BlueHydra.logger.info("Discovery started on #{@adapter_path}")
        true
      end
    end
    
    # Stop device discovery
    def stop_discovery
      with_error_handling("stop discovery") do
        @adapter_interface.StopDiscovery
        BlueHydra.logger.info("Discovery stopped on #{@adapter_path}")
        true
      end
    end
    
    # Check if discovery is active
    def discovering?
      get_property("Discovering") || false
    end
    
    # Get adapter address
    def address
      get_property("Address")
    end
    
    # Get adapter name
    def name
      get_property("Name")
    end
    
    # Get all adapter properties
    def properties
      with_error_handling("get properties") do
        @properties_interface.GetAll(ADAPTER_INTERFACE)
      end
    end
    
    # Get a specific property
    def get_property(name)
      with_error_handling("get property #{name}") do
        @properties_interface.Get(ADAPTER_INTERFACE, name)
      end
    end
    
    # Set a specific property
    def set_property(name, value)
      with_error_handling("set property #{name}") do
        @properties_interface.Set(ADAPTER_INTERFACE, name, value)
        true
      end
    end
    
    # Power on/off the adapter
    def powered=(state)
      set_property("Powered", state)
    end
    
    # Check if adapter is powered
    def powered?
      get_property("Powered") || false
    end
    
    # Set discoverable state
    def discoverable=(state)
      set_property("Discoverable", state)
    end
    
    # Check if adapter is discoverable
    def discoverable?
      get_property("Discoverable") || false
    end
    
    # Get discovered devices
    def devices
      with_error_handling("get devices") do
        devices = []
        
        # Get all objects from the object manager
        objects = get_managed_objects
        
        objects.each do |path, interfaces|
          # Check if this is a device under our adapter
          if path.start_with?(@adapter_path) && interfaces.key?("org.bluez.Device1")
            device_props = interfaces["org.bluez.Device1"]
            devices << {
              path: path,
              address: device_props["Address"],
              name: device_props["Name"],
              alias: device_props["Alias"],
              paired: device_props["Paired"],
              connected: device_props["Connected"],
              trusted: device_props["Trusted"],
              blocked: device_props["Blocked"],
              rssi: device_props["RSSI"],
              uuids: device_props["UUIDs"] || []
            }
          end
        end
        
        devices
      end
    end
    
    # Remove a device
    def remove_device(device_address)
      with_error_handling("remove device #{device_address}") do
        device_path = find_device_path(device_address)
        if device_path
          @adapter_interface.RemoveDevice(device_path)
          BlueHydra.logger.info("Removed device #{device_address}")
          true
        else
          BlueHydra.logger.warn("Device #{device_address} not found")
          false
        end
      end
    end
    
    # Get adapter path
    def path
      @adapter_path
    end
    
    # Check if connected to adapter
    def connected?
      !@adapter_object.nil? && @dbus_manager.connected?
    end
    
    private
    
    # Connect to the adapter
    def connect_to_adapter
      unless @dbus_manager.connected?
        raise DBusConnectionError, "D-Bus manager not connected" unless @dbus_manager.connect
      end
      
      @dbus_manager.with_connection do |bus|
        # Get the adapter path
        @adapter_path = find_adapter_path(@adapter_id)
        raise AdapterNotFoundError, "Bluetooth adapter not found: #{@adapter_id}" unless @adapter_path
        
        # Get the adapter object
        service = @dbus_manager.bluez_service
        @adapter_object = service.object(@adapter_path)
        @adapter_object.introspect
        
        # Get the adapter interface
        @adapter_interface = @adapter_object[ADAPTER_INTERFACE]
        @properties_interface = @adapter_object[PROPERTIES_INTERFACE]
        
        BlueHydra.logger.info("Connected to adapter: #{@adapter_path}")
      end
    end
    
    # Find adapter path using object manager
    def find_adapter_path(adapter_id = nil)
      objects = get_managed_objects
      
      objects.each do |path, interfaces|
        next unless interfaces.key?(ADAPTER_INTERFACE)
        
        if adapter_id.nil?
          # Return first adapter if no ID specified
          return path
        elsif adapter_id.start_with?("hci")
          # Match by hci number (e.g., hci0)
          return path if path.end_with?(adapter_id)
        else
          # Match by address
          adapter_props = interfaces[ADAPTER_INTERFACE]
          return path if adapter_props["Address"] == adapter_id
        end
      end
      
      nil
    end
    
    # Find device path by address
    def find_device_path(device_address)
      objects = get_managed_objects
      
      objects.each do |path, interfaces|
        if path.start_with?(@adapter_path) && interfaces.key?("org.bluez.Device1")
          device_props = interfaces["org.bluez.Device1"]
          return path if device_props["Address"] == device_address
        end
      end
      
      nil
    end
    
    # Get managed objects from object manager
    def get_managed_objects
      @dbus_manager.with_connection do |bus|
        service = @dbus_manager.bluez_service
        root = service.object("/")
        root.introspect
        
        object_manager = root[OBJECT_MANAGER_INTERFACE]
        object_manager.GetManagedObjects
      end
    end
    
    # Error handling wrapper
    def with_error_handling(operation, &block)
      yield
    rescue DBus::Error => e
      if e.message.include?("NotReady")
        raise BluezNotReadyError, "Adapter not ready for #{operation}"
      elsif e.message.include?("InProgress")
        BlueHydra.logger.warn("Operation already in progress: #{operation}")
        false
      elsif e.message.include?("NotAuthorized")
        raise BluezAuthorizationError, "Not authorized for #{operation}"
      else
        raise BluezOperationError, "Failed to #{operation}: #{e.message}"
      end
    rescue => e
      BlueHydra.logger.error("Unexpected error during #{operation}: #{e.class} - #{e.message}")
      raise
    end
  end
  
  # Custom error classes
  class AdapterNotFoundError < StandardError; end
  class BluezOperationError < StandardError; end
  class BluezAuthorizationError < StandardError; end
end 