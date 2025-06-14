require 'thread'
require 'monitor'

module BlueHydra
  # Thread Manager provides centralized thread management and monitoring
  # capabilities for Blue Hydra, enhancing thread safety and reliability
  # for Ruby 3.x compatibility
  class ThreadManager
    include MonitorMixin
    
    attr_reader :threads, :thread_errors, :shutdown_in_progress
    
    def initialize
      super() # Initialize Monitor
      @threads = {}
      @thread_errors = {}
      @thread_monitors = {}
      @shutdown_in_progress = false
      @thread_error_handlers = {}
      @restart_policies = {}
      @health_check_interval = 30 # seconds
      
      # Start health monitoring thread
      start_health_monitor
    end
    
    # Register a thread with monitoring and error handling
    def register_thread(name, restart_policy: :none, error_handler: nil, &block)
      synchronize do
        raise "Thread #{name} already registered" if @threads[name]
        
        @restart_policies[name] = restart_policy
        @thread_error_handlers[name] = error_handler
        
        thread = create_monitored_thread(name, &block)
        @threads[name] = thread
        @thread_monitors[name] = {
          started_at: Time.now,
          restarts: 0,
          last_error: nil
        }
        
        BlueHydra.logger.info("Thread registered: #{name}")
        thread
      end
    end
    
    # Create a thread with proper error handling and monitoring
    def create_monitored_thread(name, &block)
      Thread.new do
        Thread.current[:name] = name
        Thread.current.report_on_exception = false # We handle errors ourselves
        
        begin
          block.call
        rescue Exception => e
          handle_thread_error(name, e)
        ensure
          synchronize do
            @threads.delete(name)
            BlueHydra.logger.info("Thread #{name} terminated")
          end
        end
      end
    end
    
    # Handle thread errors with configurable policies
    def handle_thread_error(name, error)
      synchronize do
        @thread_errors[name] ||= []
        @thread_errors[name] << {
          error: error,
          timestamp: Time.now,
          backtrace: error.backtrace
        }
        
        # Keep only last 10 errors per thread
        @thread_errors[name] = @thread_errors[name].last(10)
        
        if @thread_monitors[name]
          @thread_monitors[name][:last_error] = error
        end
        
        BlueHydra.logger.error("Thread #{name} error: #{error.message}")
        error.backtrace[0..5].each { |line| BlueHydra.logger.error("  #{line}") }
        
        # Call custom error handler if provided
        if @thread_error_handlers[name]
          @thread_error_handlers[name].call(error)
        end
        
        # Handle restart policy
        unless @shutdown_in_progress
          case @restart_policies[name]
          when :always
            restart_thread(name)
          when :on_error
            restart_thread(name) unless error.is_a?(SystemExit)
          when :limited
            if @thread_monitors[name][:restarts] < 3
              restart_thread(name)
            else
              BlueHydra.logger.error("Thread #{name} exceeded restart limit")
            end
          end
        end
      end
    end
    
    # Restart a thread
    def restart_thread(name)
      synchronize do
        return if @shutdown_in_progress
        
        if @thread_monitors[name]
          @thread_monitors[name][:restarts] += 1
          BlueHydra.logger.info("Restarting thread #{name} (attempt #{@thread_monitors[name][:restarts]})")
        end
        
        # Get the original block from the dead thread
        # This would need to be stored during registration
        # For now, this is a placeholder
        BlueHydra.logger.warn("Thread restart not implemented for #{name}")
      end
    end
    
    # Get thread status
    def thread_status(name = nil)
      synchronize do
        if name
          thread = @threads[name]
          return nil unless thread
          
          {
            name: name,
            alive: thread.alive?,
            status: thread.status,
            monitor: @thread_monitors[name],
            recent_errors: @thread_errors[name]&.last(3)
          }
        else
          # Return status for all threads
          @threads.map { |n, _| thread_status(n) }.compact
        end
      end
    end
    
    # Check health of all threads
    def healthy?
      synchronize do
        @threads.all? { |_, thread| thread.alive? }
      end
    end
    
    # Graceful shutdown of all threads
    def shutdown(timeout: 30)
      synchronize do
        @shutdown_in_progress = true
        BlueHydra.logger.info("ThreadManager shutdown initiated")
        
        # First, send shutdown signal to all threads
        @threads.each do |name, thread|
          if thread.alive?
            BlueHydra.logger.info("Stopping thread: #{name}")
            thread[:shutdown] = true
          end
        end
      end
      
      # Wait for threads to finish gracefully
      start_time = Time.now
      while (Time.now - start_time) < timeout
        all_dead = synchronize { @threads.all? { |_, t| !t.alive? } }
        break if all_dead
        sleep 0.1
      end
      
      # Force kill any remaining threads
      synchronize do
        @threads.each do |name, thread|
          if thread.alive?
            BlueHydra.logger.warn("Force killing thread: #{name}")
            thread.kill
          end
        end
        
        @threads.clear
      end
      
      BlueHydra.logger.info("ThreadManager shutdown complete")
    end
    
    # Kill a specific thread
    def kill_thread(name)
      synchronize do
        thread = @threads[name]
        if thread && thread.alive?
          thread.kill
          @threads.delete(name)
          BlueHydra.logger.info("Thread killed: #{name}")
        end
      end
    end
    
    private
    
    # Health monitoring thread
    def start_health_monitor
      Thread.new do
        Thread.current[:name] = "thread_health_monitor"
        Thread.current.report_on_exception = false
        
        loop do
          sleep @health_check_interval
          
          break if @shutdown_in_progress
          
          synchronize do
            @threads.each do |name, thread|
              unless thread.alive?
                BlueHydra.logger.warn("Dead thread detected: #{name}")
                
                # Check restart policy
                case @restart_policies[name]
                when :always, :on_error
                  # Thread should have restarted itself
                  BlueHydra.logger.error("Thread #{name} failed to restart")
                end
              end
            end
          end
        end
      end
    end
  end
  
  # Thread-safe configuration accessor
  class ThreadSafeConfig
    include MonitorMixin
    
    def initialize(config)
      super()
      @config = config.dup
    end
    
    def [](key)
      synchronize { @config[key] }
    end
    
    def []=(key, value)
      synchronize { @config[key] = value }
    end
    
    def to_h
      synchronize { @config.dup }
    end
    
    def update(hash)
      synchronize { @config.update(hash) }
    end
  end
  
  # Thread pool for work distribution
  class ThreadPool
    include MonitorMixin
    
    def initialize(size: 5)
      super()
      @size = size
      @queue = Queue.new
      @workers = []
      @running = false
      
      start
    end
    
    def submit(&block)
      raise "ThreadPool is not running" unless @running
      @queue << block
    end
    
    def shutdown(wait: true)
      synchronize do
        @running = false
        @size.times { @queue << :shutdown }
      end
      
      @workers.each(&:join) if wait
    end
    
    def queue_size
      @queue.size
    end
    
    private
    
    def start
      synchronize do
        @running = true
        
        @size.times do |i|
          @workers << Thread.new do
            Thread.current[:name] = "pool_worker_#{i}"
            
            loop do
              work = @queue.pop
              break if work == :shutdown
              
              begin
                work.call
              rescue => e
                BlueHydra.logger.error("ThreadPool worker error: #{e.message}")
              end
            end
          end
        end
      end
    end
  end
  
  # Exception classes for thread management
  class ThreadError < StandardError; end
  class ThreadRestartError < ThreadError; end
  class ThreadShutdownError < ThreadError; end
  
  # Custom error for discovery disabled
  class DiscoveryDisabledError < StandardError; end
end 