#!/bin/bash
set -e

echo "Testing Blue Hydra in Docker..."

# Run Blue Hydra in Docker with full output
sudo docker run \
  --rm \
  --privileged \
  --network host \
  -v $(pwd)/blue_hydra.db:/opt/blue_hydra/blue_hydra.db \
  -v $(pwd)/blue_hydra.yml:/opt/blue_hydra/blue_hydra.yml \
  -v $(pwd)/logs:/opt/blue_hydra/logs \
  blue_hydra:ruby3 \
  bash -c "echo 'Ruby version:' && ruby --version && echo 'Starting Blue Hydra...' && ./bin/blue_hydra || echo 'Exit code: $?'" 