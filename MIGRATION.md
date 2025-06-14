# Blue Hydra Migration Guide - Legacy to Modern

This guide provides comprehensive documentation for migrating Blue Hydra from the legacy version (Ruby 2.7.x with DataMapper) to the modernized version (Ruby 3.x with Sequel).

## Table of Contents

1. [Overview](#overview)
2. [Before You Begin](#before-you-begin)
3. [Migration Documentation](#migration-documentation)
4. [Quick Start](#quick-start)
5. [Support](#support)

## Overview

The Blue Hydra modernization project updates the codebase to work with Ruby 3.x while maintaining full backward compatibility with existing databases and configurations. This migration is necessary because Ruby 2.7.x reached end-of-life in March 2023.

### Key Changes

- **Ruby Version**: 2.7.x → 3.2.0+
- **ORM**: DataMapper → Sequel
- **D-Bus**: Python subprocess → Native Ruby (with automatic fallback)
- **Performance**: Improved query performance and memory usage
- **Compatibility**: Database format unchanged, all features preserved

### Migration Time

- **Typical Duration**: 30-60 minutes
- **Database Size Impact**: Large databases (>1GB) may take longer
- **Downtime Required**: Yes, service must be stopped during migration

## Before You Begin

### Prerequisites

- Root or sudo access
- 500MB free disk space  
- Backup capability
- Test environment (recommended)

### Pre-Flight Checklist

- [ ] Read the [Breaking Changes](docs/migration/breaking-changes.md) document
- [ ] Review the [FAQ](docs/migration/faq.md) for common questions
- [ ] Schedule a maintenance window
- [ ] Notify users of planned downtime
- [ ] Have rollback plan ready

## Migration Documentation

The migration documentation is organized into four main documents:

### 1. [Breaking Changes](docs/migration/breaking-changes.md)
Comprehensive list of all changes that may affect your installation:
- Ruby version requirements
- API changes
- Dependency updates
- Configuration changes
- Performance implications

### 2. [Step-by-Step Guide](docs/migration/step-by-step-guide.md)
Detailed walkthrough of the migration process:
- System preparation
- Backup procedures
- Migration execution
- Verification steps
- Service configuration

### 3. [Troubleshooting Guide](docs/migration/troubleshooting.md)
Solutions for common issues and rollback procedures:
- Error resolution
- Debug procedures
- Quick rollback steps
- Full rollback with database restore

### 4. [FAQ & Quick Reference](docs/migration/faq.md)
Frequently asked questions and command reference:
- Common concerns addressed
- Quick command reference
- Monitoring commands
- Support resources

## Quick Start

For experienced users, here's the condensed migration process:

```bash
# 1. Backup current installation
sudo systemctl stop blue-hydra
cp blue_hydra.db blue_hydra.db.backup
cp blue_hydra.yml blue_hydra.yml.backup

# 2. Install Ruby 3.2.0 (using rbenv)
rbenv install 3.2.0
rbenv local 3.2.0

# 3. Update code and dependencies
git pull  # or clone modernized version
bundle install

# 4. Run migration
ruby scripts/migrate_database.rb

# 5. Update configuration
echo "use_python_discovery: false" >> blue_hydra.yml

# 6. Start service
sudo ./bin/blue_hydra

# 7. Verify operation
tail -f blue_hydra.log
```

For detailed instructions, see the [Step-by-Step Guide](docs/migration/step-by-step-guide.md).

## Support

### Getting Help

1. **Documentation First**: Review all migration documents thoroughly
2. **Check Logs**: Most issues are evident in `blue_hydra.log`
3. **Debug Mode**: Enable with `log_level: debug` in configuration
4. **Community**: File issues with debug information

### Reporting Issues

When reporting migration issues, include:
- Ruby version (`ruby --version`)
- Error messages from logs
- Database size and device count
- System specifications
- Migration method used

### Quick Rollback

If you need to rollback quickly:

```bash
# Stop modernized version
sudo killall -INT blue_hydra

# Switch Ruby version
rbenv local 2.7.8

# Restore legacy code
cd /opt/blue_hydra_legacy
bundle install

# Start legacy version
sudo ./bin/blue_hydra
```

See [Troubleshooting Guide](docs/migration/troubleshooting.md) for complete rollback procedures.

## Post-Migration

After successful migration:

1. **Monitor**: Watch logs for 24-48 hours
2. **Performance**: Compare metrics with legacy version
3. **Cleanup**: Remove legacy installation after stability confirmed
4. **Document**: Update internal runbooks and procedures

## Acknowledgments

This migration guide was created as part of the Blue Hydra modernization project. Special thanks to all contributors and testers who helped ensure a smooth migration path.

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Modernization Project**: Ruby 3.x + Sequel ORM Migration 