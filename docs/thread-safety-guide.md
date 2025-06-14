# Thread Safety Guide for Blue Hydra

This guide documents the thread safety improvements made to Blue Hydra for Ruby 3.x compatibility.

## Overview

Blue Hydra uses multiple threads for concurrent Bluetooth device discovery, monitoring, and data processing. The modernization effort has enhanced thread safety through:

1. **Centralized Thread Management** - ThreadManager class for monitoring and control
2. **Enhanced Synchronization** - Proper mutex usage and monitor patterns
3. **Graceful Shutdown** - Coordinated thread termination
4. **Error Recovery** - Automatic thread restart with configurable policies
5. **Health Monitoring** - Continuous thread health checks

## Architecture

### Thread Inventory

Blue Hydra spawns the following threads:

| Thread | Purpose | Restart Policy |
|--------|---------|----------------|
| btmon | Captures Bluetooth monitor data | limited (3 attempts) |
| chunker | Breaks raw data into device chunks | always |
| parser | Parses chunks into structured data | always |
| result | Processes and stores results | always |
| discovery | Manages device discovery via D-Bus | limited |
| cui | Command-line UI (when not daemon) | none |
| api | File API server | always |
| signal_spitter | RSSI data API server | always |
| empty_spittoon | RSSI data cleanup | always |
| ubertooth | Ubertooth hardware interface | limited |

### Thread Communication

Threads communicate via thread-safe Queue objects:

```
btmon -> raw_queue -> chunker -> chunk_queue -> parser -> result_queue -> result
                                                              |
                                                              v
                                                    info_scan_queue -> discovery
                                                              |
                                                              v
                                                      l2ping_queue
```

## Thread Manager

The `ThreadManager` class provides centralized thread lifecycle management:

```ruby
# Create thread manager
manager = BlueHydra::ThreadManager.new

# Register a thread with monitoring
manager.register_thread(:worker, 
  restart_policy: :always,
  error_handler: ->(e) { log_error(e) }
) do
  # Thread work here
  until Thread.current[:shutdown]
    process_work
    sleep 0.1
  end
end

# Check thread health
status = manager.thread_status(:worker)
puts "Thread alive: #{status[:alive]}"
puts "Restarts: #{status[:monitor][:restarts]}"

# Graceful shutdown
manager.shutdown(timeout: 30)
```

### Restart Policies

- **`:none`** - Thread is not restarted on failure
- **`:always`** - Thread is always restarted on failure
- **`:on_error`** - Thread is restarted unless it exited normally
- **`:limited`** - Thread is restarted up to 3 times

## Synchronization Patterns

### 1. Monitor Pattern

For complex synchronization needs, use the Monitor mixin:

```ruby
class ThreadSafeResource
  include MonitorMixin
  
  def initialize
    super() # Initialize Monitor
    @data = {}
  end
  
  def update(key, value)
    synchronize do
      @data[key] = value
      # Multiple operations are atomic
      @data[:updated_at] = Time.now
      @data[:update_count] ||= 0
      @data[:update_count] += 1
    end
  end
end
```

### 2. Mutex Pattern

For simple critical sections:

```ruby
class RssiManager
  def initialize
    @rssi_data = {}
    @rssi_mutex = Mutex.new
  end
  
  def add_reading(device, rssi)
    @rssi_mutex.synchronize do
      @rssi_data[device] ||= []
      @rssi_data[device] << rssi
      # Limit to last 100 readings
      @rssi_data[device] = @rssi_data[device].last(100)
    end
  end
end
```

### 3. Queue Pattern

For producer-consumer communication:

```ruby
# Producer thread
queue = Queue.new
Thread.new do
  loop do
    data = capture_data
    queue << data
  end
end

# Consumer thread
Thread.new do
  loop do
    data = queue.pop  # Blocks until data available
    process(data)
  end
end
```

## Thread-Safe Configuration

The configuration system uses thread-safe accessors:

```ruby
# Thread-safe config wrapper
config = BlueHydra::ThreadSafeConfig.new(original_config)

# Safe from any thread
value = config['key']
config['key'] = 'new_value'
config.update(multiple: 'values')
```

## Error Handling

### Thread-Local Error Recovery

Each thread should handle its own errors:

```ruby
Thread.new do
  Thread.current[:name] = "worker"
  Thread.current.report_on_exception = false
  
  begin
    # Main work loop
    loop do
      process_work
      break if Thread.current[:shutdown]
    end
  rescue StandardError => e
    # Log error
    BlueHydra.logger.error("#{Thread.current[:name]}: #{e.message}")
    # Optionally re-raise for ThreadManager to handle
    raise
  ensure
    # Cleanup
    close_resources
  end
end
```

### Global Error Handling

The ThreadManager tracks errors across all threads:

```ruby
# Get recent errors for a thread
errors = manager.thread_errors[:parser]
errors.each do |error_info|
  puts "Error at #{error_info[:timestamp]}: #{error_info[:error].message}"
end

# Check overall health
if manager.healthy?
  puts "All threads running"
else
  dead_threads = manager.thread_status.reject { |s| s[:alive] }
  puts "Dead threads: #{dead_threads.map { |s| s[:name] }}"
end
```

## Graceful Shutdown

### Shutdown Signal Pattern

Threads should check for shutdown signals:

```ruby
def run_worker_thread
  until Thread.current[:shutdown]
    # Do work
    process_batch
    
    # Check more frequently during long operations
    10.times do
      break if Thread.current[:shutdown]
      sleep 0.1
    end
  end
  
  # Cleanup before exit
  flush_buffers
  close_connections
end
```

### Queue Draining

Allow queues to drain before shutdown:

```ruby
def wait_for_queue_drain(queue, timeout: 30)
  start_time = Time.now
  
  until queue.empty? || (Time.now - start_time) > timeout
    BlueHydra.logger.info("Queue depth: #{queue.length}")
    sleep 1
  end
  
  unless queue.empty?
    BlueHydra.logger.warn("Queue not empty after timeout: #{queue.length} items remaining")
  end
end
```

## Ruby 3.x Specific Considerations

### 1. Thread.report_on_exception

Ruby 3.x enables this by default. Disable for managed threads:

```ruby
Thread.new do
  Thread.current.report_on_exception = false
  # ThreadManager will handle exceptions
end
```

### 2. Ractor Compatibility

While not using Ractors, ensure code is Ractor-safe for future:
- Avoid global variables
- Use thread-safe data structures
- Don't share mutable state

### 3. Fiber Scheduler

Ruby 3.x supports fiber schedulers. Current implementation uses threads, but could migrate to fibers for I/O operations.

## Testing Thread Safety

### 1. Concurrent Access Tests

```ruby
RSpec.describe "Thread Safety" do
  it "handles concurrent writes" do
    resource = ThreadSafeResource.new
    threads = []
    
    100.times do |i|
      threads << Thread.new do
        1000.times do |j|
          resource.update("key_#{i}", j)
        end
      end
    end
    
    threads.each(&:join)
    
    # Verify data integrity
    expect(resource.data.keys.size).to eq(100)
  end
end
```

### 2. Race Condition Detection

```ruby
it "prevents race conditions" do
  counter = ThreadSafeCounter.new
  threads = []
  
  10.times do
    threads << Thread.new do
      1000.times { counter.increment }
    end
  end
  
  threads.each(&:join)
  
  expect(counter.value).to eq(10_000)
end
```

### 3. Deadlock Detection

```ruby
it "avoids deadlocks" do
  Timeout.timeout(5) do
    # Test operations that could deadlock
    manager.shutdown
  end
end
```

## Performance Considerations

### 1. Lock Contention

Minimize time holding locks:

```ruby
# Bad - holds lock during I/O
@mutex.synchronize do
  data = fetch_from_network  # Slow!
  @cache[key] = data
end

# Good - only lock for update
data = fetch_from_network
@mutex.synchronize do
  @cache[key] = data
end
```

### 2. Thread Pool Usage

For CPU-bound work, use thread pools:

```ruby
pool = BlueHydra::ThreadPool.new(size: 4)

devices.each do |device|
  pool.submit do
    analyze_device(device)
  end
end

pool.shutdown(wait: true)
```

### 3. Queue Sizing

Monitor queue depths to detect bottlenecks:

```ruby
def log_queue_stats
  BlueHydra.logger.info("Queue depths:")
  @queues.each do |name, queue|
    BlueHydra.logger.info("  #{name}: #{queue.length}")
  end
end
```

## Debugging Thread Issues

### 1. Thread Dumps

```ruby
def dump_threads
  Thread.list.each do |thread|
    BlueHydra.logger.debug("Thread: #{thread[:name] || thread.object_id}")
    BlueHydra.logger.debug("  Status: #{thread.status}")
    BlueHydra.logger.debug("  Backtrace: #{thread.backtrace&.first(5)}")
  end
end
```

### 2. Deadlock Detection

Ruby can detect deadlocks automatically:

```ruby
begin
  # Code that might deadlock
rescue ThreadError => e
  if e.message.include?("deadlock")
    dump_threads
    raise
  end
end
```

### 3. Thread Sanitizer

For development, use thread sanitizer tools:

```bash
# Run with Ruby's built-in checks
RUBY_THREAD_MACHINE_STACK_SIZE=1048576 ruby -W2 blue_hydra.rb
```

## Best Practices

1. **Name Your Threads** - Always set `Thread.current[:name]`
2. **Handle Shutdown** - Check `Thread.current[:shutdown]` regularly
3. **Log Errors** - Include thread name in error logs
4. **Limit Shared State** - Prefer message passing via queues
5. **Test Concurrency** - Write tests that stress thread safety
6. **Monitor Health** - Regular health checks and metrics
7. **Document Synchronization** - Comment why locks are needed
8. **Avoid Nested Locks** - Prevent deadlock conditions

## Migration Checklist

When updating code for thread safety:

- [ ] Replace `Thread.new` with `thread_manager.register_thread`
- [ ] Add shutdown signal checks to loops
- [ ] Protect shared state with mutexes or monitors
- [ ] Set `report_on_exception = false` for managed threads
- [ ] Add thread name for debugging
- [ ] Implement proper error handling
- [ ] Test with concurrent access patterns
- [ ] Document synchronization requirements 