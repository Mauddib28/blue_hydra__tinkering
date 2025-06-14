#!/bin/bash
# Run Blue Hydra in interactive mode for debugging

echo "Starting interactive Blue Hydra container..."
echo "You can run the following commands inside:"
echo "  mkdir -p /run/dbus && dbus-daemon --system --fork"
echo "  hciconfig hci0 up"
echo "  ./bin/blue_hydra --rssi-api"
echo ""

sudo docker run --rm -it --privileged --network host \
    -v $(pwd):/opt/blue_hydra \
    --entrypoint=/bin/bash \
    blue_hydra:ruby3 