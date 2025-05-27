#!/usr/bin/python3

"""
Minimal bluezutils implementation for Blue Hydra
Provides find_adapter functionality needed by test-discovery script
"""

import dbus

def find_adapter(device_id=None):
    """
    Find and return a BlueZ adapter object
    
    Args:
        device_id: Optional device ID (e.g., 'hci0'). If None, returns first adapter.
        
    Returns:
        dbus.Interface: BlueZ adapter interface
        
    Raises:
        RuntimeError: If no adapter found or BlueZ not available
    """
    try:
        bus = dbus.SystemBus()
        
        # Get BlueZ object manager
        manager = dbus.Interface(
            bus.get_object("org.bluez", "/"),
            "org.freedesktop.DBus.ObjectManager"
        )
        
        objects = manager.GetManagedObjects()
        
        # Find adapters
        adapters = []
        for path, interfaces in objects.items():
            if "org.bluez.Adapter1" in interfaces:
                adapters.append(path)
        
        if not adapters:
            raise RuntimeError("No Bluetooth adapters found")
        
        # If specific device requested, find it
        if device_id:
            target_path = f"/org/bluez/{device_id}"
            if target_path in adapters:
                adapter_path = target_path
            else:
                raise RuntimeError(f"Adapter {device_id} not found")
        else:
            # Use first adapter
            adapter_path = adapters[0]
        
        # Return adapter interface
        adapter = dbus.Interface(
            bus.get_object("org.bluez", adapter_path),
            "org.bluez.Adapter1"
        )
        
        return adapter
        
    except dbus.exceptions.DBusException as e:
        if "org.freedesktop.DBus.Error.ServiceUnknown" in str(e):
            raise RuntimeError("BlueZ service not available - bluetoothd may not be running")
        elif "org.freedesktop.DBus.Error.NameHasNoOwner" in str(e):
            raise RuntimeError("BlueZ service not accessible - check bluetoothd status")
        else:
            raise RuntimeError(f"D-Bus error: {e}")
    except Exception as e:
        raise RuntimeError(f"Failed to find adapter: {e}")

def get_adapter_path(device_id=None):
    """
    Get the D-Bus path for an adapter
    
    Args:
        device_id: Optional device ID (e.g., 'hci0')
        
    Returns:
        str: D-Bus path to adapter
    """
    adapter = find_adapter(device_id)
    return adapter.object_path 