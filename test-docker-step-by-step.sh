#!/bin/bash

echo "Testing Blue Hydra in Docker step by step..."

# Create a test script inside the container
cat > test-inside-docker.sh << 'EOF'
#!/bin/bash
set -e

echo "Step 1: Setting up D-Bus..."
mkdir -p /run/dbus
dbus-daemon --system --fork
echo "D-Bus started successfully"

echo "Step 2: Checking Bluetooth adapter..."
hciconfig hci0 up 2>/dev/null || echo "Note: hci0 not available (expected in container)"

echo "Step 3: Testing Ruby and Blue Hydra loading..."
ruby -e "
  ENV['BLUE_HYDRA'] = 'test'
  require './lib/blue_hydra'
  puts 'Blue Hydra library loaded successfully'
  puts 'SYNC_VERSION: ' + BlueHydra::SYNC_VERSION if defined?(BlueHydra::SYNC_VERSION)
"

echo "Step 4: Running Blue Hydra with --version..."
./bin/blue_hydra --version

echo "Step 5: Attempting to run Blue Hydra with RSSI API..."
timeout 10 ./bin/blue_hydra --rssi-api 2>&1 || echo "Blue Hydra exited with code: $?"

echo "Step 6: Checking logs..."
tail -20 blue_hydra.log 2>/dev/null || echo "No log file found"
EOF

# Run the test script in Docker
sudo docker run --rm -it --privileged --network host \
    -v $(pwd):/opt/blue_hydra \
    --entrypoint=/bin/bash \
    blue_hydra:ruby3 \
    -c "cd /opt/blue_hydra && bash test-inside-docker.sh" 