#!/bin/bash
echo "Starting investigation..."

sudo docker run --rm -it --privileged --network host \
  -v $(pwd)/blue_hydra.yml:/opt/blue_hydra/blue_hydra.yml \
  -v $(pwd)/logs:/opt/blue_hydra/logs \
  --entrypoint /bin/bash \
  blue_hydra:ruby3 -c "
    echo '=== Checking Blue Hydra files ==='
    ls -la blue_hydra*
    echo ''
    echo '=== Checking for PID file ==='
    ls -la /var/run/blue_hydra.pid 2>/dev/null || echo 'No PID file'
    echo ''
    echo '=== Starting D-Bus manually ==='
    mkdir -p /run/dbus
    dbus-daemon --system --fork
    echo ''
    echo '=== Running Blue Hydra with debug ==='
    ruby -d ./bin/blue_hydra 2>&1 | head -100
  " 