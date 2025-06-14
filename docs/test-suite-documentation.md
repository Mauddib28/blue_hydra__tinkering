# Blue Hydra Test Suite Documentation

## Overview

This document describes the comprehensive test suite created for Blue Hydra to ensure safe migration from DataMapper/Ruby 2.7.8 to Sequel/Ruby 3.2+.

## Test Coverage Areas

### 1. Model Tests (`spec/models/`)

#### Device Model (`device_comprehensive_spec.rb`)
- **Attributes & Properties**: Validates all 40+ attributes are present and respond correctly
- **Validations**: MAC address format validation with various formats
- **Callbacks**: Tests for UUID generation, UAP/LAP extraction, vendor lookup
- **Class Methods**: `update_or_create_from_result`, `mark_old_devices_offline`
- **Attribute Setters**: Custom logic for RSSI arrays, UUID merging, address changes
- **Pulse Sync**: Verifies data synchronization functionality

**Key Test Scenarios:**
- Concurrent device creation and updates
- iBeacon device handling
- Device aging and offline marking
- JSON serialization/deserialization

### 2. Handler Tests (`spec/handlers/`)

#### BtmonHandler (`btmon_handler_comprehensive_spec.rb`)
- **Line Processing**: HCI events, device discoveries, LE advertisements
- **Event Parsing**: Extended inquiry results, LE advertising reports
- **Device Management**: Creation and update from parsed data
- **Connection Tracking**: Connection attempts and completions
- **Error Handling**: Malformed data recovery
- **Buffer Management**: Size limits and clearing

**Key Test Scenarios:**
- Classic Bluetooth device discovery
- BLE advertisement processing
- iBeacon detection
- Connection statistics tracking

### 3. Concurrency Tests (`spec/concurrency/`)

#### Thread Safety (`thread_safety_spec.rb`)
- **Model Concurrency**: Concurrent device creation/updates
- **Queue Handling**: Multi-threaded producer/consumer patterns
- **Connection Tracking**: Thread-safe statistics updates
- **Database Pooling**: Concurrent database operations
- **Signal Handling**: Multi-threaded signal processing
- **Synchronization**: Mutex usage and race condition prevention
- **Thread Pools**: Work distribution patterns

**Key Test Scenarios:**
- 10 threads creating devices simultaneously
- Concurrent RSSI updates maintaining data integrity
- Thread pool processing 100 work items

### 4. Integration Tests (`spec/integration/`)

#### Operation Modes (`operation_modes_spec.rb`)
- **Interactive Mode**: UI components, real-time updates
- **Daemonized Mode**: Background operation, log file output
- **RSSI API Mode**: Port 1124 API functionality
- **Mohawk API Mode**: JSON output to `/dev/shm/blue_hydra.json`
- **Signal Handling**: SIGINT graceful shutdown, SIGHUP log rotation
- **Startup Verification**: Database integrity, stale device cleanup

**Key Test Scenarios:**
- Mode switching between interactive/daemon
- API data generation and formatting
- Signal handling in various modes
- Log output verification

## Test Infrastructure

### Test Helpers (`spec/spec_helper.rb`)
- SimpleCov for code coverage reporting
- FactoryBot for test data generation
- DatabaseCleaner for test isolation
- Timecop for time-sensitive tests
- WebMock for external API mocking

### Factories (`spec/support/factories.rb`)
- `device`: Base device factory with MAC generation
- `classic_device`: Classic Bluetooth device
- `le_device`: BLE device
- `dual_mode_device`: Both classic and LE
- `ibeacon_device`: Apple iBeacon
- `sync_version`: Version tracking model

### Helper Methods
- `create_test_device`: Quick device creation
- `generate_mac_address`: Valid MAC generation
- `fixture_path`/`load_fixture`: Test data loading

## Running the Test Suite

### Full Test Suite
```bash
bundle exec rspec
```

### Specific Test Categories
```bash
# Model tests only
bundle exec rspec spec/models/

# Concurrency tests
bundle exec rspec spec/concurrency/

# Integration tests
bundle exec rspec spec/integration/
```

### With Coverage Report
```bash
COVERAGE=true bundle exec rspec
```

## Coverage Goals

- **Target**: 80%+ code coverage
- **Critical Paths**: 100% coverage for:
  - Device model CRUD operations
  - DataMapper query patterns
  - Thread synchronization code
  - Mode switching logic
  - Signal handlers

## Test Data Patterns

### MAC Addresses
- Sequential: `AA:BB:CC:DD:EE:00` through `AA:BB:CC:DD:EE:FF`
- Random: Generated using `SecureRandom`
- Special: `00:00:00:00:00:00` for edge cases

### RSSI Values
- Classic: `-30 dBm` to `-90 dBm`
- LE: `-40 dBm` to `-100 dBm`
- Arrays limited to 100 values

### Timing
- Classic timeout: 15 minutes
- LE timeout: 3 minutes
- Very old: 2+ weeks

## Mock Strategies

### Bluetooth Hardware
- No actual hardware required
- btmon output simulated via handler tests
- Connection events mocked

### External Services
- Louis vendor lookup stubbed
- Pulse sync mocked
- D-Bus operations isolated

### File System
- Temporary files for logs
- In-memory SQLite for tests
- `/dev/shm` writes mocked

## Continuous Integration

### Pre-commit Checks
1. Run RSpec tests
2. Check coverage > 80%
3. Verify no thread safety issues
4. Validate Ruby 3.x compatibility

### Test Environments
- Ruby 2.7.8 (baseline)
- Ruby 3.0.x (migration target)
- Ruby 3.2.x (final target)

## Future Test Additions

1. **Performance Benchmarks**
   - Device discovery rates
   - Database query performance
   - Memory usage under load

2. **Migration Tests**
   - DataMapper to Sequel data migration
   - Schema compatibility verification
   - Rollback procedures

3. **Hardware Integration**
   - Real btmon output parsing
   - Ubertooth integration
   - D-Bus communication

4. **API Client Tests**
   - RSSI API client examples
   - Mohawk integration tests
   - Rate limiting verification 