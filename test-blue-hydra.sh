#!/bin/bash
set -x  # Enable debug output

echo "Testing Blue Hydra in Docker..."

# Run a test to see what happens
sudo docker run --rm -it \
  --privileged \
  --network host \
  -v $(pwd)/blue_hydra.yml:/opt/blue_hydra/blue_hydra.yml \
  -v $(pwd)/logs:/opt/blue_hydra/logs \
  --entrypoint=/bin/bash \
  blue_hydra:ruby3 -c "
    echo '=== Environment ===';
    ruby --version;
    echo '';
    echo '=== Working Directory ===';
    pwd;
    echo '';
    echo '=== Testing requires ===';
    ruby -e 'require \"sequel\"; puts \"Sequel OK\"' || echo 'Sequel failed';
    ruby -e 'require \"dbus\"; puts \"DBus OK\"' || echo 'DBus failed';
    echo '';
    echo '=== Starting D-Bus ===';
    mkdir -p /run/dbus;
    rm -f /run/dbus/pid /run/dbus/system_bus_socket;
    dbus-daemon --system --fork;
    sleep 2;
    echo '';
    echo '=== Running Blue Hydra ===';
    cd /opt/blue_hydra;
    ./bin/blue_hydra --version || echo 'Version check failed';
    echo '';
    echo '=== Starting Blue Hydra with RSSI API ===';
    ./bin/blue_hydra --rssi-api 2>&1 || echo 'Blue Hydra exited with code: '\$?;
  " 