#!/bin/bash
set -e

echo "=== Blue Hydra Container Startup ==="

# Create machine-id if missing (required for D-Bus)
if [ ! -f /etc/machine-id ]; then
    echo "Creating machine-id for D-Bus..."
    dbus-uuidgen > /etc/machine-id
fi

# Create necessary directories
mkdir -p /run/dbus /var/lib/bluetooth

# Check if we're using host D-Bus or need our own
if [ -S /var/run/dbus/system_bus_socket ]; then
    echo "Using host D-Bus system bus..."
    # Link host D-Bus to expected location
    if [ ! -S /run/dbus/system_bus_socket ]; then
        ln -s /var/run/dbus/system_bus_socket /run/dbus/system_bus_socket 2>/dev/null || true
    fi
else
    echo "Starting container D-Bus system bus..."
    # Remove stale files
    rm -f /run/dbus/pid /var/run/dbus/pid
    # Start D-Bus
    if ! pgrep dbus-daemon > /dev/null; then
        dbus-daemon --system --fork
        sleep 2
    else
        echo "D-Bus already running"
    fi
fi

# Start bluetoothd service (CRITICAL for Bluetooth functionality)
echo "Starting bluetoothd service..."
if ! pgrep bluetoothd > /dev/null; then
    # Find bluetoothd executable
    BLUETOOTHD_PATH=$(which bluetoothd || find /usr -name bluetoothd -type f | head -1)
    if [ -z "$BLUETOOTHD_PATH" ]; then
        echo "ERROR: bluetoothd not found! Installing..."
        apt-get update && apt-get install -y bluez
        BLUETOOTHD_PATH=$(which bluetoothd || find /usr -name bluetoothd -type f | head -1)
    fi
    
    if [ -n "$BLUETOOTHD_PATH" ]; then
        echo "Starting bluetoothd from: $BLUETOOTHD_PATH"
        $BLUETOOTHD_PATH --nodetach --debug &
        BLUETOOTHD_PID=$!
        sleep 3
        
        # Verify D-Bus connection
        if dbus-send --system --print-reply --dest=org.bluez / org.freedesktop.DBus.Introspectable.Introspect > /dev/null 2>&1; then
            echo "✅ SUCCESS: bluetoothd connected to D-Bus"
        else
            echo "⚠️  WARNING: bluetoothd D-Bus connection failed, retrying..."
            sleep 2
            if dbus-send --system --print-reply --dest=org.bluez / org.freedesktop.DBus.Introspectable.Introspect > /dev/null 2>&1; then
                echo "✅ SUCCESS: bluetoothd connected to D-Bus on retry"
            else
                echo "⚠️  WARNING: bluetoothd D-Bus connection still failing"
            fi
        fi
    else
        echo "⚠️  WARNING: Could not find bluetoothd executable"
    fi
else
    echo "bluetoothd already running"
fi

echo "Setting up Bluetooth adapter..."
# List available adapters
hciconfig -a 2>/dev/null || echo "Note: No Bluetooth adapters visible in container"

# Try to bring up hci0 if it exists
if hciconfig hci0 2>/dev/null | grep -q "DOWN"; then
    echo "Bringing up hci0..."
    hciconfig hci0 up 2>/dev/null || echo "Note: Could not bring up hci0"
fi

# Enable page and inquiry scan
hciconfig hci0 piscan 2>/dev/null || echo "Note: Could not enable piscan"

# Test bluetoothctl functionality
echo "Testing Bluetooth functionality..."
timeout 5 bluetoothctl list 2>/dev/null || echo "Note: bluetoothctl test completed"

cd /opt/blue_hydra

echo "Starting Blue Hydra..."
echo "============================================"

# Trap signals to properly shutdown bluetoothd
trap 'echo "Shutting down..."; kill $BLUETOOTHD_PID 2>/dev/null || true; exit 0' SIGTERM SIGINT

# Check if we should run with RSSI API
if [[ " $@ " =~ " --rssi-api " ]] || [[ -z "$@" ]]; then
    echo "Starting Blue Hydra with RSSI API..."
    exec ./bin/blue_hydra --rssi-api
else
    echo "Starting Blue Hydra..."
    exec ./bin/blue_hydra "$@"
fi 