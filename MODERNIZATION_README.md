# Blue Hydra Modernization Project

## Overview

This repository contains the Blue Hydra Bluetooth discovery service and its ongoing modernization effort to update from Ruby 2.7.8/DataMapper to Ruby 3.2+/Sequel ORM.

## Project Status

- **Current State**: Legacy codebase using deprecated DataMapper ORM (since 2012)
- **Target State**: Modern Ruby 3.2+ with Sequel ORM
- **Timeline**: 8-10 weeks estimated
- **Phase**: Planning Complete, Ready for Implementation

## Quick Start

### Running Current Version (Ruby 2.7.8)

```bash
# Install Ruby 2.7.8
rbenv install 2.7.8
rbenv local 2.7.8

# Install dependencies
./install-deps.sh

# Run Blue Hydra (requires root)
sudo ./bin/blue_hydra
```

### Using Docker (Recommended)

```bash
# Build the container
docker build -f Dockerfile.hardware-test -t blue-hydra .

# Run with Bluetooth access
docker run --privileged --net=host -v /var/run/dbus:/var/run/dbus blue-hydra
```

## Modernization Documentation

### 📋 Planning Documents
- [Product Requirements Document](scripts/prd.txt) - Comprehensive PRD for modernization
- [Modernization Plan](docs/modernization-plan.md) - High-level strategy and timeline
- [Task Tracker](tasks/tasks.json) - 13 detailed tasks for the migration

### 📚 Technical Guides
- [Technical Migration Guide](docs/technical-migration-guide.md) - Step-by-step instructions
- [Lessons Learned](docs/lessons-learned.md) - Insights and best practices

### 🔧 Key Changes

| Component | Current | Target |
|-----------|---------|--------|
| Ruby | 2.7.8 | 3.2.4 |
| ORM | DataMapper | Sequel |
| Testing | Minimal | RSpec with 80%+ coverage |
| Deployment | Manual | Docker + CI/CD |

## Migration Phases

### Phase 1: Assessment (Week 1) ✅ COMPLETE
- [x] Analyze DataMapper usage patterns
- [x] Document database schema
- [x] Create comprehensive test suite plan

### Phase 2: ORM Migration (Weeks 2-4) 🔄 READY
- [ ] Set up Sequel environment
- [ ] Migrate Device model
- [ ] Create database migration scripts

### Phase 3: Ruby Update (Weeks 5-6) 📅 PLANNED
- [ ] Fix Ruby 3.x compatibility
- [ ] Improve thread safety
- [ ] Update all dependencies

### Phase 4: Integration (Week 7) 📅 PLANNED
- [ ] Modernize D-Bus integration
- [ ] Update Docker configuration
- [ ] System testing

### Phase 5: Testing & Docs (Weeks 8-9) 📅 PLANNED
- [ ] Performance benchmarking
- [ ] Migration documentation
- [ ] CI/CD pipeline setup

## Task Management

This project uses Task Master AI for task tracking. To view tasks:

```bash
# View all tasks
npx task-master-ai get-tasks

# View next task to work on
npx task-master-ai next-task

# Update task status
npx task-master-ai set-task-status --id 1 --status in-progress
```

## Technical Challenges

1. **DataMapper Deprecation**: 12-year old ORM with no Ruby 3.x support
2. **Thread Safety**: Critical for Bluetooth monitoring operations
3. **Hardware Access**: Requires root privileges and D-Bus integration
4. **Data Migration**: Preserving years of collected Bluetooth data

## Contributing

1. Start with Task #1: Analyze DataMapper Usage Patterns
2. Follow the [Technical Migration Guide](docs/technical-migration-guide.md)
3. Run tests before submitting changes
4. Update documentation as needed

## Resources

- [Original Blue Hydra README](README.md)
- [DataMapper to Sequel Migration Guide](docs/technical-migration-guide.md#step-6-query-pattern-migration)
- [Ruby 3.x Compatibility Guide](docs/technical-migration-guide.md#step-7-ruby-3x-compatibility)

## Support

For questions about:
- **Current functionality**: See [README.md](README.md)
- **Migration process**: See [Technical Migration Guide](docs/technical-migration-guide.md)
- **Task details**: Check [tasks/](tasks/) directory

---

**Note**: This is a major modernization effort. Always backup your data before testing migration scripts. 