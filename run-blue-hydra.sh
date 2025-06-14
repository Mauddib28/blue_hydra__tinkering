#!/bin/bash
# Blue Hydra launcher script
# Automatically uses Docker if system Ruby is < 3.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Blue Hydra Launcher"
echo "=================="

# Function to check system Ruby version
check_ruby_version() {
    if command -v ruby >/dev/null 2>&1; then
        RUBY_VERSION=$(ruby -v | grep -oP 'ruby \K[0-9]+\.[0-9]+')
        echo "System Ruby version: $RUBY_VERSION"
        
        # Check if Ruby version is 3.0 or higher
        if [[ $(echo "$RUBY_VERSION >= 3.0" | bc) -eq 1 ]]; then
            return 0
        else
            return 1
        fi
    else
        echo "Ruby not found in system"
        return 1
    fi
}

# Function to check if Docker is available
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: Docker is not installed"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        echo "Error: Docker daemon is not running or you don't have permissions"
        echo "Try running with sudo or add your user to the docker group"
        exit 1
    fi
}

# Function to build Docker image if needed
build_docker_image() {
    echo "Checking Docker image..."
    if ! docker images | grep -q "blue_hydra.*ruby3"; then
        echo "Docker image not found. Building..."
        docker-compose build
    else
        echo "Docker image found"
    fi
}

# Function to check Bluetooth adapter
check_bluetooth() {
    echo ""
    echo "Checking Bluetooth adapter..."
    if command -v hciconfig >/dev/null 2>&1; then
        hciconfig | head -5 || echo "Note: Bluetooth check requires sudo"
    else
        echo "Note: hciconfig not found on host, will check inside container"
    fi
}

# Main execution
echo ""
if check_ruby_version; then
    echo "Using system Ruby (version >= 3.0)"
    echo "Starting Blue Hydra natively..."
    cd "$(dirname "$0")"
    exec ./bin/blue_hydra "$@"
else
    echo "System Ruby is < 3.0 or not found"
    echo "Using Docker container with Ruby 3.2..."
    
    check_docker
    build_docker_image
    check_bluetooth
    
    echo ""
    echo "Starting Blue Hydra in Docker container..."
    echo "This will run with --rssi-api by default"
    echo ""
    
    # Check if container is already running
    if docker ps | grep -q blue_hydra; then
        echo "Container is already running. Stopping it first..."
        docker-compose down
    fi
    
    # Start the container
    docker-compose up -d
    
    # Wait for container to start
    echo "Waiting for container to initialize..."
    sleep 5
    
    # Show container logs
    echo ""
    echo "Container logs:"
    echo "==============="
    docker-compose logs --tail=20
    
    echo ""
    echo "Blue Hydra is running in the background!"
    echo ""
    echo "Useful commands:"
    echo "  - View logs:        docker-compose logs -f"
    echo "  - Access container: docker exec -it blue_hydra /bin/bash"
    echo "  - Stop container:   docker-compose down"
    echo "  - View status:      docker ps"
    echo ""
    echo "Blue Hydra UI should be available (if RSSI API is enabled)"
    echo "Check logs for any error messages"
fi 