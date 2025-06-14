#!/bin/bash
set -e

echo "Debugging Blue Hydra in Docker..."

# Run an interactive shell in the container
sudo docker run \
  --rm \
  -it \
  --privileged \
  --network host \
  -v $(pwd):/opt/blue_hydra \
  blue_hydra:ruby3 \
  bash -c "
    echo '=== Environment ==='
    echo 'Ruby version: ' && ruby --version
    echo 'Working directory: ' && pwd
    echo 'Files in current directory: ' && ls -la
    echo ''
    echo '=== Testing Ruby dependencies ==='
    ruby -e 'require \"sequel\"; puts \"Sequel loaded successfully\"'
    ruby -e 'require \"dbus\"; puts \"DBus loaded successfully\"'
    echo ''
    echo '=== Running Blue Hydra ==='
    ./bin/blue_hydra 2>&1 || echo 'Blue Hydra exited with code: $?'
  " 