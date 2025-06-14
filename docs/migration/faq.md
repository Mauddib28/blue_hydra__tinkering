# Migration FAQ & Quick Reference

## Frequently Asked Questions

### General Questions

**Q: Why migrate to Ruby 3.x?**  
A: Ruby 2.7.x reached end-of-life in March 2023. Ruby 3.x provides:
- Better performance (up to 3x faster in some operations)
- Improved memory management
- Modern language features
- Continued security updates
- Better ecosystem support

**Q: Is the database format changing?**  
A: No, the SQLite database format remains identical. Your existing data is preserved.

**Q: Will I lose any features?**  
A: No, all features are maintained with the same command-line interface and functionality.

**Q: How long does migration take?**  
A: Typically 30-60 minutes, depending on your database size and system performance.

**Q: Can I run both versions simultaneously?**  
A: Not recommended on the same system due to database locking, but possible with separate databases.

### Ruby & Dependencies

**Q: Which Ruby version should I use?**  
A: Ruby 3.2.0 or higher is recommended. Minimum supported is Ruby 3.0.0.

**Q: Do I need to remove Ruby 2.7.x?**  
A: No, you can keep it installed. Use rbenv to switch between versions as needed.

**Q: What about system Ruby?**  
A: Don't modify system Ruby. Use rbenv or rvm to manage Ruby versions separately.

**Q: Why use Sequel instead of DataMapper?**  
A: DataMapper is abandoned and incompatible with Ruby 3.x. Sequel is:
- Actively maintained
- More performant
- Has better documentation
- Supports modern Ruby features

### D-Bus & Bluetooth

**Q: Do I need to install new Bluetooth packages?**  
A: No, the same BlueZ packages work. Optionally install libdbus-dev for native D-Bus support.

**Q: What if ruby-dbus gem fails to load?**  
A: Blue Hydra automatically falls back to Python scripts. No manual intervention needed.

**Q: Will discovery performance change?**  
A: Native D-Bus is slightly faster by avoiding subprocess overhead, but discovery rates remain similar.

**Q: Do I need Python installed?**  
A: Only if ruby-dbus fails to load. Python remains as a fallback option.

### Migration Process

**Q: What if migration fails halfway?**  
A: Your original database is untouched until migration completes. You can safely retry.

**Q: Should I migrate during peak hours?**  
A: No, migrate during maintenance windows as the service will be offline during migration.

**Q: How do I know migration succeeded?**  
A: Run the verification tests in the migration guide. Check device count matches pre-migration.

**Q: What about custom scripts?**  
A: Review them for DataMapper usage and update to Sequel API. See API mapping in breaking changes doc.

### Performance & Operations

**Q: Will CPU usage increase?**  
A: No, CPU usage typically decreases due to Ruby 3.x optimizations.

**Q: Memory usage changes?**  
A: Memory usage is generally lower with Ruby 3.x's improved garbage collection.

**Q: Thread count differences?**  
A: Thread count remains similar, but thread management is more efficient.

**Q: Database query performance?**  
A: Sequel queries are generally faster than DataMapper, especially for complex operations.

### Troubleshooting

**Q: What if devices aren't being discovered?**  
A: Check:
1. Bluetooth adapter status (`hciconfig -a`)
2. Running as root/sudo
3. D-Bus/BlueZ services running
4. No rfkill blocks

**Q: Database locked errors?**  
A: Ensure no other Blue Hydra instances are running. Check for stale lock files.

**Q: High memory usage after migration?**  
A: Run `VACUUM` on the SQLite database to reclaim space after migration.

**Q: Logs showing "method missing" errors?**  
A: Likely DataMapper methods in custom code. Update to use Sequel API.

### Rollback

**Q: How quickly can I rollback?**  
A: Quick rollback takes < 1 hour. Full rollback with database restore takes < 2 hours.

**Q: Will rollback lose data?**  
A: Only data collected after migration. Pre-migration data is preserved in backups.

**Q: Can I test rollback procedure?**  
A: Yes, recommended to test in a non-production environment first.

**Q: When is rollback not possible?**  
A: If you've been running for weeks and don't have recent legacy backups.

## Quick Reference Guide

### Pre-Migration Checklist
```bash
□ Backup database: cp blue_hydra.db blue_hydra.db.backup
□ Backup config: cp blue_hydra.yml blue_hydra.yml.backup  
□ Document Ruby version: ruby --version > pre_migration.txt
□ Stop service: sudo systemctl stop blue-hydra
□ Check disk space: df -h (need 500MB free)
```

### Migration Commands
```bash
# Install Ruby 3.2.0
rbenv install 3.2.0
rbenv local 3.2.0

# Install dependencies
gem install bundler:2.4.22
bundle install

# Test database migration
ruby scripts/migrate_database.rb

# Start service
sudo ./bin/blue_hydra
```

### Verification Commands
```bash
# Check Ruby version
ruby --version  # Should show 3.2.0

# Check database
echo "SELECT COUNT(*) FROM devices;" | sqlite3 blue_hydra.db

# Check service
sudo systemctl status blue-hydra

# Check discovery
sudo ./bin/blue_hydra --info 2>&1 | grep "Discovery"
```

### Common Fixes
```bash
# Fix Bluetooth adapter
sudo hciconfig hci0 reset
sudo hciconfig hci0 up

# Fix D-Bus connection
sudo systemctl restart dbus
sudo systemctl restart bluetooth

# Fix database locks
rm -f blue_hydra.db-journal
rm -f blue_hydra.db-wal

# Force Python discovery
echo "use_python_discovery: true" >> blue_hydra.yml
```

### Emergency Rollback
```bash
# Quick rollback
rbenv local 2.7.8
cd /opt/blue_hydra_legacy
bundle install
sudo ./bin/blue_hydra

# Full rollback with data
cp ~/blue_hydra_backup/*/blue_hydra.db.backup ./blue_hydra.db
```

### Monitoring Commands
```bash
# Check threads
ps -eLf | grep blue_hydra | wc -l

# Check memory
ps aux | grep blue_hydra

# Check logs
tail -f blue_hydra.log

# Check API endpoints
echo "bluetooth" | nc localhost 1124  # RSSI API
cat /dev/shm/blue_hydra.json         # Mohawk API
```

### Configuration Changes
```yaml
# New in blue_hydra.yml
use_python_discovery: false  # Use native Ruby D-Bus

# Environment variables (optional)
BLUE_HYDRA_LOG_LEVEL=debug  # Enable debug logging
```

### Support Resources
- Breaking Changes: `docs/migration/breaking-changes.md`
- Step-by-Step Guide: `docs/migration/step-by-step-guide.md`
- Troubleshooting: `docs/migration/troubleshooting.md`
- GitHub Issues: `https://github.com/your-repo/issues`

### Version Information
- Legacy: Ruby 2.7.8 + DataMapper 1.2.0
- Modern: Ruby 3.2.0+ + Sequel 5.70+
- Database: SQLite 3 (unchanged)
- BlueZ: 5.x (unchanged) 