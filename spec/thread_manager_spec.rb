require 'spec_helper'
require_relative '../lib/blue_hydra/thread_manager'

RSpec.describe BlueHydra::ThreadManager do
  let(:manager) { described_class.new }
  
  after(:each) do
    # Ensure all threads are cleaned up
    manager.shutdown(timeout: 1)
  end
  
  describe '#initialize' do
    it 'creates an empty thread registry' do
      expect(manager.threads).to be_empty
      expect(manager.thread_errors).to be_empty
    end
    
    it 'starts health monitor thread' do
      # Give health monitor time to start
      sleep 0.1
      # Should have at least the health monitor running
      expect(Thread.list.size).to be > 1
    end
  end
  
  describe '#register_thread' do
    it 'registers and starts a new thread' do
      thread = manager.register_thread(:test_thread) do
        sleep 10
      end
      
      expect(thread).to be_a(Thread)
      expect(thread.alive?).to be true
      expect(manager.threads[:test_thread]).to eq(thread)
    end
    
    it 'raises error if thread name already registered' do
      manager.register_thread(:duplicate) { sleep 10 }
      
      expect {
        manager.register_thread(:duplicate) { sleep 10 }
      }.to raise_error("Thread duplicate already registered")
    end
    
    it 'applies restart policy on error' do
      restart_count = 0
      
      manager.register_thread(:restart_test, restart_policy: :limited) do
        restart_count += 1
        raise "Test error"
      end
      
      # Give time for error handling
      sleep 0.5
      
      # Should have recorded the error
      errors = manager.thread_errors[:restart_test]
      expect(errors).not_to be_nil
      expect(errors.first[:error].message).to eq("Test error")
    end
    
    it 'calls custom error handler' do
      handler_called = false
      error_received = nil
      
      handler = ->(error) {
        handler_called = true
        error_received = error
      }
      
      manager.register_thread(:error_test, error_handler: handler) do
        raise "Custom error"
      end
      
      sleep 0.2
      
      expect(handler_called).to be true
      expect(error_received.message).to eq("Custom error")
    end
  end
  
  describe '#thread_status' do
    it 'returns status for specific thread' do
      manager.register_thread(:status_test) { sleep 10 }
      
      status = manager.thread_status(:status_test)
      
      expect(status[:name]).to eq(:status_test)
      expect(status[:alive]).to be true
      expect(status[:monitor][:restarts]).to eq(0)
    end
    
    it 'returns nil for non-existent thread' do
      expect(manager.thread_status(:non_existent)).to be_nil
    end
    
    it 'returns status for all threads when no name given' do
      manager.register_thread(:thread1) { sleep 10 }
      manager.register_thread(:thread2) { sleep 10 }
      
      all_status = manager.thread_status
      
      expect(all_status).to be_an(Array)
      expect(all_status.size).to eq(2)
      expect(all_status.map { |s| s[:name] }).to contain_exactly(:thread1, :thread2)
    end
  end
  
  describe '#healthy?' do
    it 'returns true when all threads are alive' do
      manager.register_thread(:healthy1) { sleep 10 }
      manager.register_thread(:healthy2) { sleep 10 }
      
      expect(manager.healthy?).to be true
    end
    
    it 'returns false when a thread has died' do
      manager.register_thread(:dying) { raise "Dead" }
      
      sleep 0.2
      
      expect(manager.healthy?).to be false
    end
  end
  
  describe '#kill_thread' do
    it 'kills a specific thread' do
      thread = manager.register_thread(:to_kill) { sleep 10 }
      
      expect(thread.alive?).to be true
      
      manager.kill_thread(:to_kill)
      sleep 0.1
      
      expect(thread.alive?).to be false
      expect(manager.threads[:to_kill]).to be_nil
    end
  end
  
  describe '#shutdown' do
    it 'gracefully shuts down all threads' do
      threads = []
      shutdown_received = []
      
      3.times do |i|
        threads << manager.register_thread("thread_#{i}".to_sym) do
          loop do
            break if Thread.current[:shutdown]
            sleep 0.1
          end
          shutdown_received << i
        end
      end
      
      expect(threads.all?(&:alive?)).to be true
      
      manager.shutdown(timeout: 2)
      
      expect(threads.none?(&:alive?)).to be true
      expect(shutdown_received.size).to eq(3)
    end
    
    it 'force kills threads that do not respond to shutdown' do
      thread = manager.register_thread(:stubborn) do
        loop { sleep 1 }
      end
      
      expect(thread.alive?).to be true
      
      manager.shutdown(timeout: 0.5)
      
      expect(thread.alive?).to be false
    end
  end
  
  describe 'thread monitoring' do
    it 'tracks thread lifecycle' do
      start_time = Time.now
      
      manager.register_thread(:lifecycle) do
        sleep 0.5
      end
      
      sleep 0.1
      status = manager.thread_status(:lifecycle)
      
      expect(status[:monitor][:started_at]).to be_between(start_time, Time.now)
      expect(status[:alive]).to be true
      
      sleep 0.6
      
      # Thread should have finished
      expect(manager.threads[:lifecycle]).to be_nil
    end
  end
end

RSpec.describe BlueHydra::ThreadSafeConfig do
  let(:config) { described_class.new({ 'key1' => 'value1', 'key2' => 'value2' }) }
  
  describe 'thread-safe accessors' do
    it 'provides thread-safe read access' do
      results = []
      threads = []
      
      10.times do
        threads << Thread.new do
          100.times do
            results << config['key1']
          end
        end
      end
      
      threads.each(&:join)
      
      expect(results).to all(eq('value1'))
      expect(results.size).to eq(1000)
    end
    
    it 'provides thread-safe write access' do
      threads = []
      
      10.times do |i|
        threads << Thread.new do
          config["thread_#{i}"] = i
        end
      end
      
      threads.each(&:join)
      
      # All writes should have succeeded
      10.times do |i|
        expect(config["thread_#{i}"]).to eq(i)
      end
    end
    
    it 'provides thread-safe update' do
      threads = []
      
      5.times do |i|
        threads << Thread.new do
          config.update("batch_#{i}" => i)
        end
      end
      
      threads.each(&:join)
      
      5.times do |i|
        expect(config["batch_#{i}"]).to eq(i)
      end
    end
  end
end

RSpec.describe BlueHydra::ThreadPool do
  let(:pool) { described_class.new(size: 3) }
  
  after(:each) do
    pool.shutdown(wait: true)
  end
  
  describe '#submit' do
    it 'executes submitted work' do
      results = Queue.new
      
      10.times do |i|
        pool.submit { results << i }
      end
      
      # Wait for work to complete
      sleep 0.5
      
      expect(results.size).to eq(10)
      expect(results.to_a.sort).to eq((0..9).to_a)
    end
    
    it 'handles errors in submitted work' do
      error_count = 0
      
      5.times do
        pool.submit { raise "Test error" }
        pool.submit { error_count += 1 }
      end
      
      sleep 0.5
      
      # Error tasks should not prevent other tasks
      expect(error_count).to eq(5)
    end
  end
  
  describe '#queue_size' do
    it 'reports pending work' do
      # Submit work that blocks
      3.times { pool.submit { sleep 1 } }
      
      # Submit more work than workers
      5.times { pool.submit { sleep 0.1 } }
      
      expect(pool.queue_size).to be > 0
    end
  end
  
  describe '#shutdown' do
    it 'completes pending work before shutdown' do
      completed = []
      
      10.times do |i|
        pool.submit { completed << i; sleep 0.1 }
      end
      
      pool.shutdown(wait: true)
      
      expect(completed.size).to eq(10)
    end
  end
end 