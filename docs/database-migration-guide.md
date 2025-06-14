# Database Migration Guide: DataMapper to Sequel

This guide explains how to migrate your existing Blue Hydra database from DataMapper to Sequel.

## Overview

The migration process creates a new Sequel-compatible database from your existing DataMapper database while preserving all data and ensuring zero data loss.

## Prerequisites

- Ruby 3.2.2 installed (check with `ruby -v`)
- Blue Hydra dependencies installed (`bundle install`)
- Existing Blue Hydra database file (default: `blue_hydra.db`)
- Sufficient disk space for backup and new database

## Migration Tools

### 1. Migration Script

The primary migration tool is located at `scripts/migrate_to_sequel.rb`.

**Basic Usage:**
```bash
ruby scripts/migrate_to_sequel.rb
```

**Options:**
- `-s, --source DATABASE` - Source database path (default: blue_hydra.db)
- `-b, --backup-dir DIR` - Backup directory (default: db/backups)
- `-d, --dry-run` - Perform a dry run without making changes
- `-v, --verbose` - Enable verbose logging
- `-r, --restore BACKUP` - Restore from a backup file
- `-h, --help` - Show help message

### 2. Rake Tasks

Alternative rake tasks are available:

```bash
# Migrate database
rake db:migrate_to_sequel

# Dry run
DRY_RUN=true rake db:migrate_to_sequel

# Backup database
rake db:backup

# Restore from backup
BACKUP=db/backups/blue_hydra_backup_20240115_120000.db rake db:restore
```

## Migration Process

### Step 1: Backup Your Database

**Always backup before migrating!**

```bash
# Using rake task
rake db:backup

# Or using script
ruby scripts/migrate_to_sequel.rb --source blue_hydra.db --backup-dir db/backups
```

The backup creates:
- `blue_hydra_backup_YYYYMMDD_HHMMSS.db` - Database copy
- `blue_hydra_backup_YYYYMMDD_HHMMSS.db.json` - Metadata file

### Step 2: Test with Dry Run

Test the migration without making changes:

```bash
# Using script
ruby scripts/migrate_to_sequel.rb --dry-run

# Using rake
DRY_RUN=true rake db:migrate_to_sequel
```

This will:
- Validate the source database
- Test the migration process
- Report any potential issues
- Show migration statistics

### Step 3: Perform Migration

Run the actual migration:

```bash
# Using script (recommended)
ruby scripts/migrate_to_sequel.rb

# Using rake
rake db:migrate_to_sequel
```

The migration will:
1. Create a backup automatically
2. Create new Sequel database (`blue_hydra_sequel.db`)
3. Migrate all devices and sync versions
4. Validate data integrity
5. Generate a migration report

### Step 4: Verify Migration

Check the migration report in `db/backups/migration_report_YYYYMMDD_HHMMSS.json`:

```json
{
  "timestamp": "2024-01-15T12:00:00Z",
  "source_database": "blue_hydra.db",
  "statistics": {
    "devices": {
      "datamapper_count": 1234,
      "sequel_count": 1234
    },
    "sync_versions": {
      "datamapper_count": 1,
      "sequel_count": 1
    }
  },
  "validation": {
    "status": "passed",
    "sample_size": 12
  }
}
```

### Step 5: Update Blue Hydra Configuration

After successful migration, update Blue Hydra to use Sequel:

1. **Update database configuration:**
   ```ruby
   # In your configuration file
   database_path = "blue_hydra_sequel.db"
   ```

2. **Switch to Sequel models:**
   ```ruby
   # Use new Sequel models instead of DataMapper
   require 'blue_hydra/models/device'  # Sequel version
   ```

## Data Validation

The migration performs several validation checks:

1. **Record Count Validation** - Ensures all records are migrated
2. **Sample Data Validation** - Verifies data integrity for sample records
3. **Field Mapping Validation** - Confirms all fields are correctly mapped

## Rollback Procedure

If issues occur after migration:

### Option 1: Restore from Backup

```bash
# List available backups
ls -la db/backups/

# Restore specific backup
ruby scripts/migrate_to_sequel.rb --restore db/backups/blue_hydra_backup_20240115_120000.db

# Or using rake
BACKUP=db/backups/blue_hydra_backup_20240115_120000.db rake db:restore
```

### Option 2: Keep Using DataMapper

Simply continue using the original `blue_hydra.db` file - it remains unchanged during migration.

## Migration Details

### Data Type Conversions

| DataMapper Type | Sequel Type | Notes |
|----------------|-------------|-------|
| Serial | primary_key | Auto-incrementing integer |
| String | String | With size constraints |
| Text | Text | For large text fields |
| Boolean | TrueClass | Stored as 't'/'f' in SQLite |
| DateTime | DateTime | Timezone preserved |
| Integer | Integer | Direct mapping |

### JSON Field Handling

JSON-encoded fields are preserved as-is:
- `*_rssi` arrays
- `*_service_uuids` arrays
- `*_features` arrays
- `*_features_bitmap` objects

### Index Creation

The Sequel migration adds performance indexes:
- `address` - For device lookups
- `uap_lap` - For partial MAC matching
- `status` - For filtering queries
- `[status, last_seen]` - For cleanup operations

## Troubleshooting

### Common Issues

1. **"Source database not found"**
   - Verify database path: `ls -la blue_hydra.db`
   - Use absolute path: `ruby scripts/migrate_to_sequel.rb -s /path/to/blue_hydra.db`

2. **"Permission denied"**
   - Ensure write permissions: `chmod 644 blue_hydra.db`
   - Run with appropriate user permissions

3. **"Disk space error"**
   - Check available space: `df -h`
   - Clean old backups if needed

4. **"Migration validation failed"**
   - Check migration report for details
   - Try verbose mode: `ruby scripts/migrate_to_sequel.rb -v`
   - Consider restoring from backup

### Debug Mode

For detailed debugging:

```bash
# Maximum verbosity
ruby scripts/migrate_to_sequel.rb --verbose --dry-run

# Check Ruby 3.x compatibility first
ruby scripts/verify_ruby3_compatibility.rb
```

## Performance Considerations

- **Large Databases**: Migration processes in batches of 1000 records
- **Memory Usage**: Dry run uses in-memory database
- **Disk I/O**: Ensure fast storage for better performance
- **Migration Time**: Approximately 1-2 minutes per 10,000 devices

## Best Practices

1. **Always backup first** - Even though migration creates backups
2. **Test with dry run** - Verify process before actual migration
3. **Monitor disk space** - Ensure 2x database size available
4. **Schedule during downtime** - Stop Blue Hydra during migration
5. **Keep backups** - Retain for at least 30 days after migration

## Support

If you encounter issues:

1. Check the migration log output
2. Review the migration report in `db/backups/`
3. Verify Ruby 3.x compatibility: `ruby scripts/verify_ruby3_compatibility.rb`
4. Consult test suite: `bundle exec rspec spec/migration_manager_spec.rb` 