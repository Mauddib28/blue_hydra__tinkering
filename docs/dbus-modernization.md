# D-Bus Modernization Guide

This document describes the modernization of Blue Hydra's D-Bus integration, replacing Python script-based discovery with native Ruby D-Bus bindings.

## Overview

Blue Hydra has been modernized to use native Ruby D-Bus bindings via the `ruby-dbus` gem, replacing the previous approach of calling Python scripts through subprocesses. This provides better performance, improved error handling, and more maintainable code.

## Architecture

### Components

1. **DBusManager** (`lib/blue_hydra/dbus_manager.rb`)
   - Centralized D-Bus connection management
   - Automatic reconnection with configurable retry logic
   - Health monitoring with periodic connection checks
   - Thread-safe connection handling

2. **BluezAdapter** (`lib/blue_hydra/bluez_adapter.rb`)
   - Ruby interface to BlueZ org.bluez.Adapter1
   - Full BlueZ 5.x API compatibility
   - Device discovery and management
   - Property access and manipulation

3. **DiscoveryService** (`lib/blue_hydra/discovery_service.rb`)
   - High-level discovery orchestration
   - Graceful fallback for environments without D-Bus
   - Configurable discovery timing

4. **RunnerDBusDiscovery** (`lib/blue_hydra/runner_dbus_discovery.rb`)
   - Module extending Runner with D-Bus discovery
   - Maintains backward compatibility
   - Preserves existing queue processing logic

## Configuration

### Enabling Ruby D-Bus Discovery

By default, Blue Hydra will attempt to use Ruby D-Bus discovery. To force the use of Python scripts:

```yaml
# blue_hydra.yml
use_python_discovery: true
```

Or via environment variable:
```bash
export BLUE_HYDRA_USE_PYTHON_DISCOVERY=true
```

### D-Bus Connection Options

The DBusManager accepts configuration options:

```ruby
dbus_manager = DBusManager.new(:system, {
  max_reconnect_attempts: 5,    # Maximum reconnection attempts
  reconnect_delay: 5,           # Seconds between reconnection attempts
  health_check_interval: 30     # Seconds between health checks
})
```

## API Reference

### DBusManager

```ruby
# Create a new D-Bus manager
manager = BlueHydra::DBusManager.new(:system)

# Connect to D-Bus
manager.connect # => true/false

# Check connection status
manager.connected? # => true/false

# Get a D-Bus service
service = manager.service("org.bluez")

# Execute with automatic reconnection
manager.with_connection do |bus|
  # D-Bus operations
end

# Get connection statistics
stats = manager.stats
# => {
#   state: :connected,
#   bus_type: :system,
#   connection_attempts: 0,
#   last_error: nil,
#   health_check_active: true
# }

# Disconnect
manager.disconnect
```

### BluezAdapter

```ruby
# Create adapter interface
adapter = BlueHydra::BluezAdapter.new("hci0", dbus_manager)

# Discovery operations
adapter.start_discovery
adapter.stop_discovery
adapter.discovering? # => true/false

# Adapter properties
adapter.address     # => "AA:BB:CC:DD:EE:FF"
adapter.name        # => "Adapter Name"
adapter.powered?    # => true/false
adapter.powered = true

# Get all properties
props = adapter.properties
# => { "Address" => "...", "Name" => "...", ... }

# Device management
devices = adapter.devices
# => [{ address: "...", name: "...", rssi: -65, ... }]

adapter.remove_device("11:22:33:44:55:66")
```

### DiscoveryService

```ruby
# Create discovery service
service = BlueHydra::DiscoveryService.new("hci0", discovery_time: 30)

# Connect to adapter
service.connect # => true/false

# Run discovery
result = service.run_discovery
# => :success, :failed, :not_ready, :disabled, etc.

# Get discovered devices
devices = service.devices

# Disconnect
service.disconnect
```

## Error Handling

### Error Classes

- `BlueHydra::DBusConnectionError` - D-Bus connection failures
- `BlueHydra::AdapterNotFoundError` - Bluetooth adapter not found
- `BlueHydra::BluezOperationError` - BlueZ operation failures
- `BlueHydra::BluezAuthorizationError` - Permission denied errors
- `BlueHydra::BluezNotReadyError` - Adapter not ready errors

### Error Recovery

The system implements multiple levels of error recovery:

1. **Connection Level**: Automatic reconnection with exponential backoff
2. **Operation Level**: Retry operations after reconnection
3. **Thread Level**: Discovery thread handles errors gracefully
4. **Fallback Mode**: Passive-only mode when D-Bus unavailable

## Migration from Python Scripts

### Previous Approach

```python
# bin/test-discovery (Python)
adapter = bluezutils.find_adapter(device_id)
adapter.StartDiscovery()
time.sleep(timeout)
adapter.StopDiscovery()
```

### New Approach

```ruby
# Native Ruby
service = DiscoveryService.new(device_id)
service.connect
service.run_discovery
```

### Compatibility

The system maintains full backward compatibility:

1. Automatic detection and use of Ruby D-Bus when available
2. Fallback to Python scripts if ruby-dbus gem not installed
3. Configuration option to force Python script usage
4. No changes required to existing Blue Hydra installations

## Performance Improvements

1. **Reduced Process Overhead**: No subprocess spawning for discovery
2. **Better Error Information**: Structured exceptions vs string parsing
3. **Connection Pooling**: Reused D-Bus connections
4. **Health Monitoring**: Proactive connection monitoring

## Troubleshooting

### Common Issues

1. **"D-Bus system bus not available"**
   - Ensure D-Bus daemon is running: `sudo service dbus start`
   - Check socket exists: `ls -la /run/dbus/system_bus_socket`

2. **"Adapter not found"**
   - Verify Bluetooth hardware: `hciconfig -a`
   - Check BlueZ service: `systemctl status bluetooth`

3. **"Not authorized"**
   - Run Blue Hydra with appropriate privileges
   - Check D-Bus policies in `/etc/dbus-1/system.d/`

### Debug Logging

Enable debug logging for detailed D-Bus operations:

```yaml
# blue_hydra.yml
log_level: debug
```

### Testing D-Bus Connection

```ruby
# Quick test script
require 'blue_hydra/dbus_manager'
require 'blue_hydra/bluez_adapter'

manager = BlueHydra::DBusManager.new
if manager.connect
  puts "D-Bus connected"
  adapter = BlueHydra::BluezAdapter.new(nil, manager)
  puts "Adapter: #{adapter.address}"
else
  puts "D-Bus connection failed"
end
```

## Development

### Running Tests

```bash
# Run all D-Bus related tests
bundle exec rspec spec/dbus_manager_spec.rb spec/bluez_adapter_spec.rb spec/discovery_service_spec.rb

# Run with coverage
bundle exec rspec --coverage
```

### Adding New D-Bus Interfaces

1. Create interface wrapper class
2. Define D-Bus interface constants
3. Implement method wrappers with error handling
4. Add comprehensive tests

## Future Enhancements

1. **Device Interface**: Implement org.bluez.Device1 for device operations
2. **Properties Monitoring**: Add D-Bus signal handling for property changes
3. **GATT Support**: Add BLE GATT service discovery
4. **Adapter Events**: Monitor adapter add/remove events

## References

- [BlueZ D-Bus API](https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc)
- [ruby-dbus Documentation](https://github.com/mvidner/ruby-dbus)
- [D-Bus Specification](https://dbus.freedesktop.org/doc/dbus-specification.html) 