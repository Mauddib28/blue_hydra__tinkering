# Step-by-Step Migration Guide

This guide walks you through migrating Blue Hydra from the legacy version (Ruby 2.7.x + DataMapper) to the modernized version (Ruby 3.x + Sequel).

## Pre-Migration Checklist

Before starting the migration, ensure you have:

- [ ] Root/sudo access (required for Bluetooth operations)
- [ ] At least 500MB free disk space
- [ ] Current database backup
- [ ] Test environment available
- [ ] 30-60 minutes for the migration

## Step 1: Backup Current Installation

### 1.1 Stop Blue Hydra Service

```bash
# If running as systemd service
sudo systemctl stop blue-hydra

# If running manually, find and kill the process
ps aux | grep blue_hydra
sudo kill -INT <PID>
```

### 1.2 Backup Database

```bash
# Create backup directory
mkdir -p ~/blue_hydra_backup/$(date +%Y%m%d)
cd ~/blue_hydra_backup/$(date +%Y%m%d)

# Backup database
cp /var/lib/blue_hydra/blue_hydra.db ./blue_hydra.db.backup
# Or if in local directory
cp blue_hydra.db ./blue_hydra.db.backup

# Backup configuration
cp /etc/blue_hydra/blue_hydra.yml ./blue_hydra.yml.backup
# Or if in local directory
cp blue_hydra.yml ./blue_hydra.yml.backup

# Backup custom scripts if any
cp -r /path/to/blue_hydra/scripts ./scripts_backup
```

### 1.3 Document Current Setup

```bash
# Record current Ruby version
ruby --version > system_info.txt

# Record installed gems
gem list >> system_info.txt

# Record system packages
dpkg -l | grep -E '(bluetooth|bluez|python)' >> system_info.txt
```

## Step 2: Prepare System for Ruby 3.x

### 2.1 Install Ruby Version Manager (if not present)

```bash
# Install rbenv and ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
```

### 2.2 Install Ruby 3.2.0

```bash
# Install dependencies for Ruby compilation
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev libreadline-dev \
  zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev \
  libxslt1-dev libcurl4-openssl-dev software-properties-common \
  libffi-dev

# Install Ruby 3.2.0
rbenv install 3.2.0
rbenv global 3.2.0
ruby --version  # Should show ruby 3.2.0
```

### 2.3 Install System Dependencies

```bash
# For native D-Bus support (optional but recommended)
sudo apt-get install -y libdbus-1-dev libdbus-glib-1-dev

# Bluetooth packages (if not already installed)
sudo apt-get install -y bluetooth bluez libbluetooth-dev \
  bluez-tools rfkill
```

## Step 3: Migrate Blue Hydra Code

### 3.1 Clone Modernized Version

```bash
# Backup old installation
mv /opt/blue_hydra /opt/blue_hydra_legacy

# Clone modernized version
git clone https://github.com/your-repo/blue_hydra_modernized.git /opt/blue_hydra
cd /opt/blue_hydra
```

### 3.2 Copy Configuration and Database

```bash
# Copy database
cp ~/blue_hydra_backup/$(date +%Y%m%d)/blue_hydra.db.backup ./blue_hydra.db

# Copy and update configuration
cp ~/blue_hydra_backup/$(date +%Y%m%d)/blue_hydra.yml.backup ./blue_hydra.yml

# Add new configuration option
echo "use_python_discovery: false" >> blue_hydra.yml
```

### 3.3 Install Dependencies

```bash
# Set Ruby version for project
rbenv local 3.2.0

# Install bundler
gem install bundler:2.4.22

# Install gems
bundle install
```

## Step 4: Database Migration

### 4.1 Run Migration Script

```bash
# The migration will run automatically on first start
# But you can test it manually first
ruby scripts/migrate_database.rb

# Expected output:
# Checking database compatibility...
# Database schema is compatible
# Running Sequel migrations...
# Migration completed successfully
```

### 4.2 Verify Database Integrity

```bash
# Test database access
ruby -e "require './lib/blue_hydra'; puts BlueHydra::Device.count"

# Should output the number of devices in your database
```

## Step 5: Test Basic Functionality

### 5.1 Test in Interactive Mode

```bash
# Run in interactive mode first
sudo ./bin/blue_hydra

# You should see the familiar UI
# Press 'q' to exit after verifying it starts
```

### 5.2 Test Discovery

```bash
# Test with info messages
sudo ./bin/blue_hydra 2>&1 | grep -E "(BlueHydra Starting|Discovery|D-Bus)"

# Should show:
# BlueHydra Starting...
# Using Ruby D-Bus discovery
# Discovery enabled
```

### 5.3 Test API Endpoints

```bash
# Test RSSI API
sudo ./bin/blue_hydra --rssi-api &
sleep 5
echo "bluetooth" | nc localhost 1124
# Should return JSON data

# Test Mohawk API
sudo ./bin/blue_hydra --mohawk-api &
sleep 5
cat /dev/shm/blue_hydra.json
# Should show device JSON
```

## Step 6: Update Service Configuration

### 6.1 Update Systemd Service (if used)

```bash
# Edit service file
sudo nano /etc/systemd/system/blue-hydra.service

# Update ExecStart path and add Ruby path
ExecStart=/home/user/.rbenv/shims/ruby /opt/blue_hydra/bin/blue_hydra -d

# Reload systemd
sudo systemctl daemon-reload
```

### 6.2 Start Service

```bash
# Start the service
sudo systemctl start blue-hydra

# Check status
sudo systemctl status blue-hydra

# Enable auto-start
sudo systemctl enable blue-hydra
```

## Step 7: Verification

### 7.1 Check Logs

```bash
# Check Blue Hydra logs
tail -f /var/log/blue_hydra/blue_hydra.log

# Should show normal operation messages
```

### 7.2 Verify Database Updates

```bash
# Connect to database and check recent entries
sqlite3 blue_hydra.db "SELECT COUNT(*) FROM devices WHERE updated_at > datetime('now', '-1 hour');"
```

### 7.3 Monitor Performance

```bash
# Check resource usage
htop
# Filter for blue_hydra process

# Check thread count
ps -eLf | grep blue_hydra | wc -l
```

## Step 8: Final Cleanup

### 8.1 Remove Legacy Installation (after confirming everything works)

```bash
# After running successfully for 24-48 hours
rm -rf /opt/blue_hydra_legacy

# Remove old Ruby version (optional)
rbenv uninstall 2.7.8
```

### 8.2 Update Documentation

Update any internal documentation or runbooks to reflect:
- New Ruby version requirement
- New dependency on ruby-dbus (optional)
- Any custom script changes

## Migration Complete!

Your Blue Hydra installation is now running on Ruby 3.x with Sequel ORM. 

### Next Steps

1. Monitor logs for any issues over the next few days
2. Compare device detection rates with legacy version
3. Test all integrated systems (Pulse, APIs, etc.)
4. Update monitoring/alerting thresholds if needed

### Getting Help

If you encounter issues:
1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review [Breaking Changes](breaking-changes.md)
3. Check logs in `/var/log/blue_hydra/`
4. File an issue with migration details 