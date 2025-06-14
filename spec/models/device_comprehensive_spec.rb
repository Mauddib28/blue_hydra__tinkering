require 'spec_helper'

describe BlueHydra::Device do
  describe "attributes and properties" do
    it "has all expected attributes" do
      device = BlueHydra::Device.new
      
      # Core attributes
      expect(device).to respond_to(:id)
      expect(device).to respond_to(:uuid)
      expect(device).to respond_to(:name)
      expect(device).to respond_to(:status)
      expect(device).to respond_to(:address)
      expect(device).to respond_to(:uap_lap)
      expect(device).to respond_to(:vendor)
      expect(device).to respond_to(:last_seen)
      expect(device).to respond_to(:created_at)
      expect(device).to respond_to(:updated_at)
      
      # Classic mode attributes
      expect(device).to respond_to(:classic_mode)
      expect(device).to respond_to(:classic_service_uuids)
      expect(device).to respond_to(:classic_channels)
      expect(device).to respond_to(:classic_major_class)
      expect(device).to respond_to(:classic_minor_class)
      expect(device).to respond_to(:classic_rssi)
      
      # LE mode attributes
      expect(device).to respond_to(:le_mode)
      expect(device).to respond_to(:le_service_uuids)
      expect(device).to respond_to(:le_address_type)
      expect(device).to respond_to(:le_rssi)
      expect(device).to respond_to(:le_proximity_uuid)
      expect(device).to respond_to(:le_major_num)
      expect(device).to respond_to(:le_minor_num)
    end
    
    it "has correct default values" do
      device = BlueHydra::Device.new
      expect(device.classic_mode).to eq(false)
      expect(device.le_mode).to eq(false)
    end
  end
  
  describe "validations" do
    it "validates MAC address format" do
      device = build(:device, address: "invalid")
      expect(device).not_to be_valid
      expect(device.errors[:address]).not_to be_empty
      
      device.address = "AA:BB:CC:DD:EE:FF"
      expect(device).to be_valid
    end
    
    it "accepts various MAC address formats" do
      ["AA:BB:CC:DD:EE:FF", "aa:bb:cc:dd:ee:ff", "AA-BB-CC-DD-EE-FF"].each do |mac|
        device = build(:device, address: mac)
        expect(device).to be_valid
      end
    end
  end
  
  describe "callbacks" do
    describe "#set_uuid" do
      it "generates a UUID on save" do
        device = build(:device, uuid: nil)
        expect(device.uuid).to be_nil
        device.save
        expect(device.uuid).to match(/^[0-9a-z]{8}-([0-9a-z]{4}-){3}[0-9a-z]{12}$/)
      end
      
      it "does not override existing UUID" do
        existing_uuid = SecureRandom.uuid
        device = create(:device, uuid: existing_uuid)
        device.name = "Updated"
        device.save
        expect(device.uuid).to eq(existing_uuid)
      end
    end
    
    describe "#set_uap_lap" do
      it "extracts UAP/LAP from MAC address" do
        device = create(:device, address: "D5:AD:B5:5F:CA:F5")
        expect(device.uap_lap).to eq("B5:5F:CA:F5")
      end
    end
    
    describe "#set_vendor" do
      it "looks up vendor from MAC address" do
        device = build(:device, address: "00:1B:44:11:3A:B7")
        device.save
        expect(device.vendor).not_to be_nil
      end
      
      it "sets N/A for random LE addresses" do
        device = create(:device, le_address_type: "Random")
        expect(device.vendor).to eq("N/A - Random Address")
      end
    end
  end
  
  describe ".update_or_create_from_result" do
    let(:result_hash) do
      {
        address: ["AA:BB:CC:DD:EE:FF"],
        name: ["Test Device"],
        classic_mode: [true],
        classic_major_class: ["Phone"],
        classic_minor_class: ["Smart phone"],
        classic_rssi: ["-36 dBm"],
        last_seen: [Time.now.to_i]
      }
    end
    
    it "creates a new device from result hash" do
      expect {
        BlueHydra::Device.update_or_create_from_result(result_hash)
      }.to change(BlueHydra::Device, :count).by(1)
      
      device = BlueHydra::Device.last
      expect(device.address).to eq("AA:BB:CC:DD:EE:FF")
      expect(device.name).to eq("Test Device")
      expect(device.classic_mode).to eq(true)
    end
    
    it "updates existing device" do
      existing = create(:device, address: "AA:BB:CC:DD:EE:FF", name: "Old Name")
      
      BlueHydra::Device.update_or_create_from_result(result_hash)
      
      existing.reload
      expect(existing.name).to eq("Test Device")
      expect(existing.classic_mode).to eq(true)
    end
    
    it "finds device by UAP/LAP if address not found" do
      # Create device with different NAP but same UAP/LAP
      existing = create(:device, address: "11:22:CC:DD:EE:FF")
      
      BlueHydra::Device.update_or_create_from_result(result_hash)
      
      existing.reload
      expect(existing.address).to eq("AA:BB:CC:DD:EE:FF")
    end
    
    it "handles iBeacon devices" do
      ibeacon_result = {
        address: ["AA:BB:CC:DD:EE:FF"],
        le_proximity_uuid: ["f7826da6-4fa2-4e98-8024-bc5b71e0893e"],
        le_major_num: ["1"],
        le_minor_num: ["100"],
        company: ["Apple, Inc."],
        le_company_data: ["0215f7826da64fa24e988024bc5b71e0893e00010064c5"]
      }
      
      device = BlueHydra::Device.update_or_create_from_result(ibeacon_result)
      expect(device.le_proximity_uuid).to eq("f7826da6-4fa2-4e98-8024-bc5b71e0893e")
      expect(device.le_major_num).to eq("1")
      expect(device.le_minor_num).to eq("100")
    end
  end
  
  describe ".mark_old_devices_offline" do
    before do
      # Clear all devices
      BlueHydra::Device.destroy
    end
    
    it "marks classic devices offline after 15 minutes" do
      old_device = create(:classic_device, 
        last_seen: Time.now.to_i - (16 * 60),
        status: "online"
      )
      recent_device = create(:classic_device,
        last_seen: Time.now.to_i - (10 * 60),
        status: "online"
      )
      
      BlueHydra::Device.mark_old_devices_offline
      
      old_device.reload
      recent_device.reload
      
      expect(old_device.status).to eq("offline")
      expect(recent_device.status).to eq("online")
    end
    
    it "marks LE devices offline after 3 minutes" do
      old_device = create(:le_device,
        last_seen: Time.now.to_i - (4 * 60),
        status: "online"
      )
      recent_device = create(:le_device,
        last_seen: Time.now.to_i - (2 * 60),
        status: "online"
      )
      
      BlueHydra::Device.mark_old_devices_offline
      
      old_device.reload
      recent_device.reload
      
      expect(old_device.status).to eq("offline")
      expect(recent_device.status).to eq("online")
    end
    
    it "marks very old devices as offline but does not delete them" do
      very_old = create(:device,
        updated_at: Time.now - (3 * 7 * 24 * 60 * 60), # 3 weeks old
        status: "online"
      )
      
      BlueHydra::Device.mark_old_devices_offline
      
      very_old.reload
      expect(very_old.status).to eq("offline")
      expect(BlueHydra::Device.get(very_old.id)).not_to be_nil
    end
  end
  
  describe "attribute setters" do
    let(:device) { create(:device) }
    
    describe "#classic_rssi=" do
      it "maintains last 100 RSSI values" do
        rssi_values = []
        105.times do |i|
          rssi_values << "-#{30 + i} dBm"
          device.classic_rssi = ["-#{30 + i} dBm"]
        end
        
        parsed = JSON.parse(device.classic_rssi)
        expect(parsed.length).to eq(100)
        expect(parsed.last).to eq("-134 dBm")
      end
    end
    
    describe "#le_service_uuids=" do
      it "merges and deduplicates UUIDs" do
        device.le_service_uuids = ["0x1234", "0x5678"]
        device.le_service_uuids = ["0x5678", "0x9ABC"]
        
        uuids = JSON.parse(device.le_service_uuids)
        expect(uuids).to include("Unknown (0x1234)")
        expect(uuids).to include("Unknown (0x5678)")
        expect(uuids).to include("Unknown (0x9ABC)")
        expect(uuids.count("Unknown (0x5678)")).to eq(1)
      end
    end
    
    describe "#address=" do
      it "updates vendor when address changes" do
        device = create(:device, address: "00:00:00:00:00:00")
        original_vendor = device.vendor
        
        device.address = "00:1B:44:11:3A:B7"
        expect(device.vendor).not_to eq(original_vendor)
      end
    end
  end
  
  describe "#sync_to_pulse" do
    before do
      BlueHydra.pulse = true
      allow(BlueHydra::Pulse).to receive(:do_send)
    end
    
    after do
      BlueHydra.pulse = false
    end
    
    it "sends device data to Pulse" do
      device = create(:device, name: "Test Device")
      
      expect(BlueHydra::Pulse).to receive(:do_send) do |json|
        data = JSON.parse(json)
        expect(data["type"]).to eq("bluetooth")
        expect(data["source"]).to eq("blue-hydra")
        expect(data["data"]["address"]).to eq(device.address)
        expect(data["data"]["name"]).to eq("Test Device")
      end
      
      device.sync_to_pulse
    end
    
    it "only syncs changed attributes" do
      device = create(:device)
      
      # Clear filthy attributes
      device.instance_variable_set(:@filthy_attributes, [])
      
      # Change only name
      device.name = "Updated Name"
      device.save
      
      expect(BlueHydra::Pulse).to receive(:do_send) do |json|
        data = JSON.parse(json)
        expect(data["data"]).to have_key("name")
        expect(data["data"]).not_to have_key("vendor")
      end
      
      device.sync_to_pulse
    end
  end
end 