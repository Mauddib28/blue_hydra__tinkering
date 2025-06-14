# Troubleshooting Guide & Rollback Procedures

This guide helps you resolve common issues during and after migration to Blue Hydra's modernized version.

## Common Migration Issues

### 1. Ruby Version Issues

#### Problem: "LoadError: cannot load such file -- data_objects"
**Cause**: Ruby 3.x cannot load legacy DataMapper gems.

**Solution**:
```bash
# Ensure you're using Ruby 3.x
ruby --version

# If still on 2.7.x, switch to 3.x
rbenv local 3.2.0

# Clean and reinstall gems
rm -rf .bundle
bundle install
```

#### Problem: "Fixnum/Bignum deprecation warnings"
**Cause**: Ruby 3.x unified Integer class.

**Solution**:
```bash
# Ensure data_objects patch is loaded
# Check lib/blue_hydra/data_objects_patch.rb exists
# Should be automatically loaded by blue_hydra.rb
```

### 2. Database Migration Issues

#### Problem: "Database locked" error
**Cause**: Another process is accessing the database.

**Solution**:
```bash
# Find processes using the database
lsof | grep blue_hydra.db

# Kill any stale processes
kill -9 <PID>

# Remove lock file if exists
rm -f blue_hydra.db-journal
rm -f blue_hydra.db-wal
rm -f blue_hydra.db-shm
```

#### Problem: "undefined method for DataMapper"
**Cause**: Code still trying to use DataMapper API.

**Solution**:
```bash
# Check for custom scripts using DataMapper
grep -r "DataMapper" lib/ scripts/

# Update custom code to use Sequel API
# See breaking-changes.md for API mapping
```

### 3. D-Bus Connection Issues

#### Problem: "D-Bus connection failed"
**Cause**: System D-Bus or BlueZ service issues.

**Solution**:
```bash
# Check D-Bus service
sudo systemctl status dbus

# Check BlueZ service
sudo systemctl status bluetooth

# Restart services if needed
sudo systemctl restart dbus
sudo systemctl restart bluetooth

# Test D-Bus manually
dbus-send --system --print-reply --dest=org.bluez / org.freedesktop.DBus.Introspectable.Introspect
```

#### Problem: "ruby-dbus gem not loading"
**Cause**: Missing system dependencies.

**Solution**:
```bash
# Install D-Bus development libraries
sudo apt-get install -y libdbus-1-dev libdbus-glib-1-dev

# Reinstall ruby-dbus gem
gem uninstall ruby-dbus
bundle install

# Force Python discovery if needed
echo "use_python_discovery: true" >> blue_hydra.yml
```

### 4. Bluetooth Discovery Issues

#### Problem: "No devices discovered"
**Cause**: Bluetooth adapter issues or permissions.

**Solution**:
```bash
# Check Bluetooth adapter
hciconfig -a

# If adapter is down
sudo hciconfig hci0 up

# Reset Bluetooth adapter
sudo hciconfig hci0 reset

# Check rfkill status
rfkill list
sudo rfkill unblock bluetooth

# Ensure running as root/sudo
sudo ./bin/blue_hydra
```

### 5. Performance Issues

#### Problem: "High CPU usage"
**Cause**: Inefficient queries or thread management.

**Solution**:
```bash
# Check thread count
ps -eLf | grep blue_hydra | wc -l

# If too many threads, check ThreadManager
# Max threads should be around 20-30

# Profile the application
ruby -rprofile ./bin/blue_hydra

# Reduce discovery frequency if needed
# Edit blue_hydra.yml
# bt_device_timeout: 300  # Increase timeout
```

### 6. API Endpoint Issues

#### Problem: "RSSI API not responding"
**Cause**: Port already in use or thread crash.

**Solution**:
```bash
# Check if port 1124 is in use
sudo lsof -i :1124

# Kill process using the port
sudo kill -9 <PID>

# Test manually
echo "bluetooth" | nc localhost 1124
```

#### Problem: "Mohawk JSON not updating"
**Cause**: File permissions or path issues.

**Solution**:
```bash
# Check /dev/shm permissions
ls -la /dev/shm/

# Create file manually to test
echo "{}" > /dev/shm/blue_hydra.json
chmod 666 /dev/shm/blue_hydra.json

# Check if API thread is running
ps aux | grep blue_hydra
```

## Rollback Procedures

### Quick Rollback (< 1 hour downtime)

If you need to quickly rollback to the legacy version:

#### Step 1: Stop Modernized Version
```bash
sudo systemctl stop blue-hydra
# Or kill manually
sudo killall -INT blue_hydra
```

#### Step 2: Switch Ruby Version
```bash
rbenv local 2.7.8
ruby --version  # Verify it's 2.7.8
```

#### Step 3: Restore Legacy Code
```bash
# If you kept backup
mv /opt/blue_hydra /opt/blue_hydra_modern
mv /opt/blue_hydra_legacy /opt/blue_hydra

# Or re-clone legacy version
cd /opt
rm -rf blue_hydra
git clone https://github.com/pwnieexpress/blue_hydra.git
cd blue_hydra
```

#### Step 4: Restore Gemfile
```bash
# Copy backed up Gemfile
cp ~/blue_hydra_backup/*/Gemfile* ./

# Install legacy gems
bundle install
```

#### Step 5: Restore Configuration
```bash
# Remove new config options
grep -v "use_python_discovery" blue_hydra.yml > blue_hydra.yml.tmp
mv blue_hydra.yml.tmp blue_hydra.yml
```

#### Step 6: Start Legacy Version
```bash
sudo ./bin/blue_hydra
# Or as service
sudo systemctl start blue-hydra
```

### Full Rollback (with database restore)

If database compatibility issues arise:

#### Step 1: Complete Quick Rollback First
Follow all steps in Quick Rollback above.

#### Step 2: Restore Database Backup
```bash
# Stop Blue Hydra
sudo systemctl stop blue-hydra

# Backup current database (just in case)
cp blue_hydra.db blue_hydra.db.modern

# Restore legacy database
cp ~/blue_hydra_backup/*/blue_hydra.db.backup ./blue_hydra.db
```

#### Step 3: Verify Database
```bash
# Test with legacy version
sudo ./bin/blue_hydra

# Check device count
echo "SELECT COUNT(*) FROM devices;" | sqlite3 blue_hydra.db
```

## Debug Mode Operations

### Enable Verbose Logging

```bash
# Edit blue_hydra.yml
log_level: "debug"

# Or set environment variable
BLUE_HYDRA_LOG_LEVEL=debug ./bin/blue_hydra
```

### Test Individual Components

```ruby
# Test database connection
ruby -e "require './lib/blue_hydra'; p BlueHydra::Device.db"

# Test D-Bus connection
ruby -e "require './lib/blue_hydra'; p BlueHydra::DbusManager.new.connected?"

# Test discovery service
ruby -e "require './lib/blue_hydra'; ds = BlueHydra::DiscoveryService.new; p ds.available?"
```

### Common Log Locations

```bash
# Main application log
tail -f blue_hydra.log

# RSSI log
tail -f blue_hydra_rssi.log

# System logs
journalctl -u bluetooth -f
journalctl -u blue-hydra -f
```

## Getting Additional Help

If these solutions don't resolve your issue:

1. **Collect Debug Information**:
```bash
# Create debug bundle
mkdir blue_hydra_debug
cd blue_hydra_debug

# System info
ruby --version > system_info.txt
gem list >> system_info.txt
uname -a >> system_info.txt

# Blue Hydra logs
cp ../blue_hydra*.log ./

# Database info
echo ".schema devices" | sqlite3 ../blue_hydra.db > schema.txt

# Create tarball
tar -czf blue_hydra_debug.tar.gz *
```

2. **Check Documentation**:
   - Review [Breaking Changes](breaking-changes.md)
   - Re-read [Step-by-Step Guide](step-by-step-guide.md)
   - Check [FAQ](faq.md)

3. **File an Issue**:
   - Include debug bundle
   - Describe steps to reproduce
   - Include error messages
   - Mention migration method used 