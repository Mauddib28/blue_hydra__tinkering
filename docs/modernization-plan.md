# Blue Hydra Modernization Plan

## Executive Summary

Blue Hydra is a Bluetooth device discovery service that requires modernization due to its dependency on DataMapper ORM (deprecated since 2012) and Ruby 2.7.8. This plan outlines a systematic approach to update the codebase for compatibility with modern Ruby versions (3.2+) while maintaining all existing functionality.

## Current State Analysis

### Technical Stack
- **Ruby Version**: 2.7.8 (required for DataMapper compatibility)
- **ORM**: DataMapper (deprecated, incompatible with Ruby 3.x)
- **Database**: SQLite
- **System Dependencies**: bluez 5+, D-Bus, Python 3
- **Optional Hardware**: Ubertooth One for enhanced discovery

### Key Challenges
1. DataMapper ORM has been deprecated since 2012
2. Ruby 3.x introduces breaking changes (Fixnum/Integer unification)
3. Thread safety concerns with modern Ruby
4. D-Bus integration requires root privileges
5. Complex Bluetooth hardware interactions

## Modernization Strategy

### Phase 1: Assessment and Preparation (Week 1)
**Goal**: Understand the current codebase and establish a testing baseline

**Tasks**:
- Task #1: Analyze DataMapper usage patterns
- Task #2: Create comprehensive test suite
- Task #3: Document current database schema

**Key Activities**:
- Map all DataMapper-specific features to Sequel equivalents
- Establish baseline performance metrics
- Create test fixtures for Bluetooth operations

### Phase 2: ORM Migration (Weeks 2-4)
**Goal**: Replace DataMapper with Sequel ORM

**Tasks**:
- Task #4: Set up Sequel ORM environment
- Task #5: Migrate Device model to Sequel
- Task #8: Create database migration scripts

**Technical Approach**:
```ruby
# DataMapper (Old)
class Device
  include DataMapper::Resource
  property :id, Serial
  property :address, String, :index => true
  timestamps :created_at, :updated_at
end

# Sequel (New)
class Device < Sequel::Model
  plugin :timestamps
  plugin :validation_helpers
  
  def validate
    super
    validates_presence [:address]
    validates_unique :address
  end
end
```

### Phase 3: Ruby 3.x Compatibility (Weeks 5-6)
**Goal**: Update codebase for Ruby 3.2+ compatibility

**Tasks**:
- Task #6: Fix Ruby 3.x compatibility issues
- Task #10: Improve thread safety

**Key Changes**:
- Replace all Fixnum references with Integer
- Update string encoding handling
- Fix keyword argument syntax
- Modernize thread synchronization

### Phase 4: System Integration (Week 7)
**Goal**: Modernize system-level integrations

**Tasks**:
- Task #7: Modernize D-Bus integration
- Task #9: Ensure Interactive and Daemonized Mode Support (Updated Focus)

**Improvements**:
- Better error handling for D-Bus failures
- **Primary Focus**: Ensure both interactive and daemonized modes work correctly
- Verify verification flags (--rssi-api, --mohawk-api) function properly
- Docker containerization as secondary priority
- Improved privilege management

### Phase 5: Testing and Documentation (Weeks 8-9)
**Goal**: Ensure reliability and ease migration

**Tasks**:
- Task #11: Create migration documentation
- Task #12: Performance benchmarking
- ~~Task #13: Set up CI/CD pipeline~~ **(Marked as Not Required)**

**Note**: CI/CD pipeline has been deprioritized as negligible importance. Focus remains on ensuring the core functionality works in both interactive and daemonized modes.

## Verification Methods

Blue Hydra provides several methods for verifying proper operation:

1. **Interactive Mode**: Direct UI output for real-time monitoring
2. **Daemonized Mode**: Background operation with logging to `blue_hydra.log`
3. **RSSI API**: Use `--rssi-api` flag to enable RSSI output on port 1124
4. **Mohawk API**: Use `--mohawk-api` flag to generate JSON output at `/dev/shm/blue_hydra.json`
5. **Log Monitoring**: Check `blue_hydra.log` for runtime verification

## Technical Implementation Details

### Database Migration Strategy

1. **Backup Existing Data**
   ```bash
   sqlite3 blue_hydra.db ".backup blue_hydra_backup.db"
   ```

2. **Schema Migration**
   - Export DataMapper schema
   - Generate Sequel migrations
   - Validate data integrity

3. **Data Transformation**
   - Handle timestamp formats
   - Update query patterns
   - Preserve RSSI history

### Dependency Updates

| Component | Current | Target |
|-----------|---------|--------|
| Ruby | 2.7.8 | 3.2+ |
| DataMapper | 1.2.0 | Sequel 5.x |
| SQLite | 3.x | 3.x (unchanged) |
| Bluez | 5.x | 5.x (unchanged) |

### Risk Mitigation

1. **Data Loss Prevention**
   - Automated backups before migration
   - Rollback procedures at each phase
   - Data validation checksums

2. **Performance Regression**
   - Baseline benchmarks before changes
   - Performance testing at each milestone
   - Query optimization for Sequel

3. **Hardware Compatibility**
   - Test with multiple Bluetooth adapters
   - Verify Ubertooth integration
   - Docker-based testing environment

## Success Metrics

- ✅ All tests passing on Ruby 3.2+
- ✅ Zero data loss during migration
- ✅ Performance within 10% of original
- ✅ Successfully discovers BT devices
- ✅ Docker deployment working
- ✅ CI/CD pipeline operational

## Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Assessment | 1 week | Test suite, documentation |
| ORM Migration | 3 weeks | Sequel models, migration scripts |
| Ruby Update | 2 weeks | Ruby 3.x compatible code |
| Integration | 1 week | Updated Docker, D-Bus fixes |
| Testing | 2 weeks | Benchmarks, documentation |
| **Total** | **9 weeks** | **Modernized Blue Hydra** |

## Next Steps

1. Begin with Task #1: Analyze DataMapper usage patterns
2. Set up development environment with Ruby 2.7.8
3. Create feature branch for modernization work
4. Establish CI/CD pipeline early
5. Regular progress reviews at phase boundaries 