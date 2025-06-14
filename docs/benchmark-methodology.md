# Blue Hydra Benchmark Methodology

This document describes the performance benchmarking approach used to compare the legacy and modernized versions of Blue Hydra.

## Overview

The benchmark suite is designed to provide comprehensive performance metrics across all major subsystems of Blue Hydra, enabling data-driven decisions about migration and optimization.

## Benchmark Components

### 1. Benchmark Runner Framework

**File**: `lib/blue_hydra/benchmark_runner.rb`

Core framework providing:
- Automatic timing and measurement
- Resource monitoring (memory, CPU, threads)
- Result persistence in JSON format
- Comparison capabilities
- CSV export for graphing

### 2. Benchmark Scripts

#### Full System Benchmark
**File**: `scripts/run_benchmarks.rb`

Comprehensive benchmark testing:
- Startup performance
- Database operations (1000 devices)
- Discovery simulation
- Resource usage patterns
- Workload simulation

**Usage**:
```bash
ruby scripts/run_benchmarks.rb -n "test_name" -d 1000 -t 30
```

#### Discovery Benchmark
**File**: `scripts/benchmark_discovery.rb`

Compares discovery methods:
- Python subprocess discovery
- Native Ruby D-Bus discovery
- Simulated discovery (fallback)

**Metrics**:
- Startup time
- Discovery rate (devices/second)
- Latency
- Resource overhead

#### Database Benchmark
**File**: `scripts/benchmark_database.rb`

Tests database performance:
- Create operations (single and bulk)
- Update operations (single and bulk)
- Query operations (simple and complex)
- Concurrent operations
- Transaction handling

**Test Data**:
- Configurable device count (default: 1000)
- Realistic device attributes
- Various query patterns

#### Resource Benchmark
**File**: `scripts/benchmark_resources.rb`

Monitors system resources:
- Startup resource allocation
- Idle resource usage
- Load test (60 seconds)
- Memory allocation patterns
- Garbage collection impact

**Monitoring**:
- Memory usage via `/proc/self/status`
- CPU usage via `/proc/PID/stat`
- Thread count via `Thread.list`

### 3. Automated Test Suite

**File**: `scripts/run_all_benchmarks.sh`

Executes all benchmarks in sequence:
1. Comprehensive system benchmark
2. Discovery performance test
3. Database operations test
4. Resource usage test
5. Summary report generation

## Measurement Methodology

### Timing

- Uses Ruby's `Benchmark.realtime` for accurate measurements
- Warm-up periods excluded from results
- Multiple iterations for statistical significance

### Memory Measurement

```ruby
# Read from /proc filesystem
VmRSS from /proc/self/status
```

- Resident Set Size (RSS) for actual memory usage
- Measured before and after operations
- Garbage collection forced for accurate readings

### CPU Measurement

```ruby
# Calculate from process stats
CPU% = (utime + stime) / elapsed_time * 100
```

- User and system time from `/proc/PID/stat`
- Calculated as percentage of elapsed time
- Averaged over measurement period

### Database Metrics

- Operations per second (throughput)
- Query response time (latency)
- Concurrent operation success rate
- Error frequency

## Test Environment

### Hardware Requirements

- Minimum 4GB RAM
- Multi-core processor
- SSD storage recommended
- Linux with /proc filesystem

### Software Requirements

- Ruby (2.7.x for legacy, 3.x for modern)
- SQLite 3
- BlueZ 5.x
- D-Bus (optional)

### Test Isolation

- Fresh database for each test run
- Cleanup between tests
- Minimal background processes
- Consistent system state

## Result Analysis

### Output Format

JSON structure:
```json
{
  "metadata": {
    "test_name": "benchmark",
    "ruby_version": "3.2.0",
    "orm": "Sequel 5.70",
    "timestamp": 1234567890
  },
  "metrics": {
    "metric_name": {
      "value": 123.45,
      "unit": "seconds"
    }
  }
}
```

### Comparison Method

1. Run benchmarks on legacy version
2. Run identical benchmarks on modern version
3. Use comparison feature:
   ```bash
   ruby scripts/run_benchmarks.rb -c legacy_results.json
   ```

### Key Performance Indicators

1. **Throughput**: Operations per second
2. **Latency**: Response time in milliseconds
3. **Resource Efficiency**: Memory/CPU per operation
4. **Scalability**: Performance under load
5. **Stability**: Error rate and variance

## Best Practices

### Running Benchmarks

1. **System Preparation**:
   - Close unnecessary applications
   - Disable system updates
   - Ensure thermal throttling won't occur

2. **Multiple Runs**:
   - Run benchmarks 3+ times
   - Discard outliers
   - Report median values

3. **Consistent Environment**:
   - Same hardware for all tests
   - Same OS and kernel version
   - Same background services

### Interpreting Results

1. **Consider Variance**:
   - ±5% is normal variance
   - >10% improvement is significant
   - Watch for regression in any metric

2. **Holistic View**:
   - Don't optimize for single metric
   - Consider resource/performance trade-offs
   - Real-world usage patterns matter

3. **Validate Improvements**:
   - Confirm in production-like environment
   - Monitor over extended periods
   - Check edge cases

## Benchmark Automation

### Continuous Benchmarking

Consider integrating benchmarks into CI/CD:

```yaml
# Example GitHub Actions workflow
benchmark:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Run benchmarks
      run: ./scripts/run_all_benchmarks.sh
    - name: Upload results
      uses: actions/upload-artifact@v2
      with:
        name: benchmark-results
        path: benchmarks/
```

### Performance Regression Detection

Set thresholds for key metrics:
- Database operations: >1000 ops/sec
- Memory usage: <250MB under load
- Startup time: <2 seconds

## Conclusion

This benchmarking methodology provides comprehensive, reproducible performance measurements for Blue Hydra. Regular benchmarking helps:

- Validate optimization efforts
- Detect performance regressions
- Guide capacity planning
- Support migration decisions

For detailed results, see the [Performance Comparison Report](performance-comparison-report.md). 