#!/bin/bash

# Blue Hydra Dependency Installer
# Installs Ruby 2.7.8 and DataMapper dependencies for host OS compatibility

set -e

echo "Blue Hydra Dependency Installer"
echo "================================"

# Check OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected Linux OS"
    
    # Install system dependencies
    if command -v apt-get &> /dev/null; then
        echo "Installing Ubuntu/Debian dependencies..."
        sudo apt-get update
        sudo apt-get install -y build-essential libsqlite3-dev ruby-dev git curl
    elif command -v yum &> /dev/null; then
        echo "Installing RHEL/CentOS dependencies..."
        sudo yum install -y gcc gcc-c++ sqlite-devel ruby-devel git curl
    elif command -v dnf &> /dev/null; then
        echo "Installing Fedora dependencies..."
        sudo dnf install -y gcc gcc-c++ sqlite-devel ruby-devel git curl
    else
        echo "Warning: Unknown package manager. Please manually install: build-essential libsqlite3-dev ruby-dev"
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS"
    if ! command -v brew &> /dev/null; then
        echo "Error: Please install Homebrew first: https://brew.sh/"
        exit 1
    fi
    brew install sqlite ruby git
else
    echo "Warning: Unsupported OS: $OSTYPE"
fi

# Install rbenv if not present
if ! command -v rbenv &> /dev/null; then
    echo "Installing rbenv..."
    curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
    
    # Add rbenv to PATH
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    
    # For current session
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

# Install Ruby 2.7.8
echo "Installing Ruby 2.7.8..."
rbenv install -s 2.7.8
rbenv local 2.7.8

# Install bundler
echo "Installing Bundler 2.1.2..."
gem install bundler:2.1.2

# Install gems
echo "Installing Blue Hydra dependencies..."
bundle install

echo ""
echo "✅ Installation complete!"
echo ""
echo "To use Blue Hydra:"
echo "1. Ensure you're in the blue_hydra directory"
echo "2. Run: sudo ./bin/blue_hydra"
echo ""
echo "Note: Blue Hydra requires root privileges for Bluetooth access"
echo ""
echo "For production use, consider using the Docker container instead:"
echo "docker exec -it btosint-collector bash" 