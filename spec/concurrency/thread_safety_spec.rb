require 'spec_helper'

describe "Thread Safety" do
  describe "Device Model concurrency" do
    it "handles concurrent device creation safely" do
      addresses = 10.times.map { |i| "AA:BB:CC:DD:EE:%02X" % i }
      threads = []
      
      addresses.each do |addr|
        threads << Thread.new do
          5.times do
            BlueHydra::Device.update_or_create_from_result({
              address: [addr],
              name: ["Device #{addr}"],
              last_seen: [Time.now.to_i]
            })
          end
        end
      end
      
      threads.each(&:join)
      
      # Each address should have exactly one device
      addresses.each do |addr|
        devices = BlueHydra::Device.all(address: addr)
        expect(devices.count).to eq(1)
        expect(devices.first.name).to eq("Device #{addr}")
      end
    end
    
    it "handles concurrent updates to same device" do
      device = create(:device)
      threads = []
      
      10.times do |i|
        threads << Thread.new do
          5.times do
            device.reload
            device.name = "Updated #{i}"
            device.save
          end
        end
      end
      
      threads.each(&:join)
      
      device.reload
      expect(device.name).to match(/Updated \d+/)
    end
    
    it "handles concurrent RSSI updates" do
      device = create(:device)
      threads = []
      
      5.times do |i|
        threads << Thread.new do
          10.times do |j|
            device.reload
            device.classic_rssi = ["-#{30 + i + j} dBm"]
            device.save
          end
        end
      end
      
      threads.each(&:join)
      
      device.reload
      rssi_values = JSON.parse(device.classic_rssi)
      expect(rssi_values).not_to be_empty
      expect(rssi_values.length).to be <= 100
    end
  end
  
  describe "Queue handling" do
    it "processes items from multiple threads safely" do
      queue = Queue.new
      results = []
      mutex = Mutex.new
      
      # Producer threads
      producers = 3.times.map do |i|
        Thread.new do
          10.times do |j|
            queue << "producer-#{i}-item-#{j}"
          end
        end
      end
      
      # Consumer threads
      consumers = 2.times.map do |i|
        Thread.new do
          15.times do
            item = queue.pop(true) rescue nil
            if item
              mutex.synchronize { results << item }
            end
            sleep 0.001
          end
        end
      end
      
      producers.each(&:join)
      consumers.each(&:join)
      
      expect(results.size).to eq(30)
      expect(results.uniq.size).to eq(30)
    end
  end
  
  describe "Connection tracking" do
    it "handles concurrent connection stats updates" do
      stats = {}
      mutex = Mutex.new
      threads = []
      
      5.times do |i|
        threads << Thread.new do
          addr = "AA:BB:CC:DD:EE:%02X" % i
          10.times do
            mutex.synchronize do
              stats[addr] ||= { attempts: 0, successes: 0 }
              stats[addr][:attempts] += 1
              stats[addr][:successes] += 1 if rand > 0.5
            end
          end
        end
      end
      
      threads.each(&:join)
      
      stats.each do |addr, data|
        expect(data[:attempts]).to eq(10)
        expect(data[:successes]).to be <= data[:attempts]
      end
    end
  end
  
  describe "Database connection pooling" do
    it "handles concurrent database operations" do
      threads = []
      
      10.times do |i|
        threads << Thread.new do
          5.times do
            # Simulate database operations
            count = BlueHydra::Device.count
            device = BlueHydra::Device.first
            all_devices = BlueHydra::Device.all(status: "online")
          end
        end
      end
      
      expect { threads.each(&:join) }.not_to raise_error
    end
  end
  
  describe "Signal handling" do
    it "handles signals in multi-threaded environment" do
      threads = []
      stop = false
      
      # Worker threads
      3.times do |i|
        threads << Thread.new do
          until stop
            sleep 0.01
          end
        end
      end
      
      # Simulate signal handling
      Thread.new do
        sleep 0.1
        stop = true
      end.join
      
      threads.each(&:join)
      expect(stop).to be true
    end
  end
  
  describe "Mutex and synchronization" do
    it "prevents race conditions in shared data structures" do
      shared_hash = {}
      mutex = Mutex.new
      threads = []
      
      10.times do |i|
        threads << Thread.new do
          100.times do |j|
            mutex.synchronize do
              key = "key_#{j % 10}"
              shared_hash[key] = (shared_hash[key] || 0) + 1
            end
          end
        end
      end
      
      threads.each(&:join)
      
      shared_hash.each do |key, value|
        expect(value).to eq(100)
      end
    end
  end
  
  describe "Thread pool simulation" do
    it "processes work items through thread pool" do
      work_queue = Queue.new
      results = Queue.new
      workers = []
      
      # Create worker threads
      4.times do
        workers << Thread.new do
          loop do
            work = work_queue.pop
            break if work == :stop
            
            # Simulate processing
            result = work * 2
            results << result
          end
        end
      end
      
      # Add work items
      100.times { |i| work_queue << i }
      
      # Stop workers
      4.times { work_queue << :stop }
      workers.each(&:join)
      
      # Check results
      result_array = []
      result_array << results.pop until results.empty?
      
      expect(result_array.size).to eq(100)
      expect(result_array.sort).to eq((0...100).map { |i| i * 2 })
    end
  end
end 