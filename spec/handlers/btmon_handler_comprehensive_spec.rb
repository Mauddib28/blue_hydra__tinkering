require 'spec_helper'

describe BlueHydra::BtmonHandler do
  let(:handler) { BlueHydra::BtmonHandler.new(nil) }
  
  describe "#initialize" do
    it "initializes with default values" do
      expect(handler.buffer).to eq([])
      expect(handler.devices).to eq({})
      expect(handler.connection_stats).to eq({})
    end
  end
  
  describe "#process_line" do
    it "processes HCI Event lines" do
      line = "> HCI Event: LE Meta Event (0x3e) plen 42"
      handler.process_line(line)
      expect(handler.buffer.last).to eq(line)
    end
    
    it "processes Device Found events" do
      lines = [
        "> HCI Event: Extended Inquiry Result (0x2f) plen 255",
        "        Num responses: 1",
        "        Address: AA:BB:CC:DD:EE:FF (OUI AA-BB-CC)",
        "        Page scan repetition mode: R1 (0x01)",
        "        Reserved: 0x00",
        "        Class: 0x5a020c",
        "          Major class: Phone (cellular, cordless, payphone, modem)",
        "          Minor class: Smart phone",
        "        Clock offset: 0x1234",
        "        RSSI: -42 dBm (0xd6)",
        "        Name (complete): iPhone"
      ]
      
      lines.each { |line| handler.process_line(line) }
      
      expect(handler.devices).to have_key("AA:BB:CC:DD:EE:FF")
      device = handler.devices["AA:BB:CC:DD:EE:FF"]
      expect(device[:name]).to include("iPhone")
      expect(device[:address]).to include("AA:BB:CC:DD:EE:FF")
      expect(device[:classic_rssi]).to include("-42 dBm (0xd6)")
    end
    
    it "processes LE Advertisement events" do
      lines = [
        "> HCI Event: LE Meta Event (0x3e) plen 42",
        "      LE Advertising Report (0x02)",
        "        Num reports: 1",
        "        Event type: Connectable undirected - ADV_IND (0x00)",
        "        Address type: Random (0x01)",
        "        Address: 44:55:66:77:88:99 (Static)",
        "        Data length: 31",
        "        Flags: 0x06",
        "          LE General Discoverable Mode",
        "          BR/EDR Not Supported",
        "        Company: Apple, Inc. (76)",
        "          Type: iBeacon (2)",
        "          UUID: f7826da6-4fa2-4e98-8024-bc5b71e0893e",
        "          Version: 1.100",
        "          TX power: -59 dB",
        "        RSSI: -48 dBm (0xd0)"
      ]
      
      lines.each { |line| handler.process_line(line) }
      
      expect(handler.devices).to have_key("44:55:66:77:88:99")
      device = handler.devices["44:55:66:77:88:99"]
      expect(device[:le_address_type]).to include("Random (0x01)")
      expect(device[:company]).to include("Apple, Inc.")
      expect(device[:le_proximity_uuid]).to include("f7826da6-4fa2-4e98-8024-bc5b71e0893e")
    end
  end
  
  describe "#parse_extended_inquiry_result" do
    let(:event_lines) do
      [
        "> HCI Event: Extended Inquiry Result (0x2f) plen 255",
        "        Num responses: 1",
        "        Address: AA:BB:CC:DD:EE:FF (OUI AA-BB-CC)",
        "        Class: 0x5a020c",
        "          Major class: Phone",
        "          Minor class: Smart phone",
        "        RSSI: -42 dBm (0xd6)"
      ]
    end
    
    it "parses device information correctly" do
      handler.buffer = event_lines
      result = handler.send(:parse_extended_inquiry_result)
      
      expect(result[:address]).to eq(["AA:BB:CC:DD:EE:FF"])
      expect(result[:classic_major_class]).to eq(["Phone"])
      expect(result[:classic_minor_class]).to eq(["Smart phone"])
      expect(result[:classic_rssi]).to eq(["-42 dBm (0xd6)"])
    end
  end
  
  describe "#parse_le_advertising_report" do
    let(:event_lines) do
      [
        "> HCI Event: LE Meta Event (0x3e) plen 42",
        "      LE Advertising Report (0x02)",
        "        Address: 44:55:66:77:88:99 (Static)",
        "        Address type: Random (0x01)",
        "        RSSI: -48 dBm (0xd0)",
        "        Name (complete): BLE Device"
      ]
    end
    
    it "parses LE device information" do
      handler.buffer = event_lines
      result = handler.send(:parse_le_advertising_report)
      
      expect(result[:address]).to eq(["44:55:66:77:88:99"])
      expect(result[:le_address_type]).to eq(["Random (0x01)"])
      expect(result[:le_rssi]).to eq(["-48 dBm (0xd0)"])
      expect(result[:name]).to eq(["BLE Device"])
    end
  end
  
  describe "#handle_device" do
    it "creates or updates device records" do
      device_data = {
        address: ["AA:BB:CC:DD:EE:FF"],
        name: ["Test Device"],
        classic_mode: [true]
      }
      
      expect {
        handler.send(:handle_device, device_data)
      }.to change(BlueHydra::Device, :count).by(1)
      
      device = BlueHydra::Device.last
      expect(device.address).to eq("AA:BB:CC:DD:EE:FF")
      expect(device.name).to eq("Test Device")
    end
    
    it "handles device creation errors" do
      device_data = {
        address: ["invalid-mac"],
        name: ["Test Device"]
      }
      
      expect {
        handler.send(:handle_device, device_data)
      }.not_to change(BlueHydra::Device, :count)
    end
  end
  
  describe "connection handling" do
    it "tracks connection attempts" do
      lines = [
        "< HCI Command: Create Connection (0x01|0x0005) plen 13",
        "        Address: AA:BB:CC:DD:EE:FF (OUI AA-BB-CC)",
        "> HCI Event: Command Status (0x0f) plen 4",
        "      Create Connection (0x01|0x0005) ncmd 1",
        "        Status: Success (0x00)"
      ]
      
      lines.each { |line| handler.process_line(line) }
      
      expect(handler.connection_stats).to have_key("AA:BB:CC:DD:EE:FF")
      expect(handler.connection_stats["AA:BB:CC:DD:EE:FF"][:attempts]).to eq(1)
    end
    
    it "tracks successful connections" do
      lines = [
        "> HCI Event: Connection Complete (0x03) plen 11",
        "        Status: Success (0x00)",
        "        Handle: 256",
        "        Address: AA:BB:CC:DD:EE:FF (OUI AA-BB-CC)",
        "        Link type: ACL (0x01)",
        "        Encryption: Disabled (0x00)"
      ]
      
      lines.each { |line| handler.process_line(line) }
      
      expect(handler.connection_stats["AA:BB:CC:DD:EE:FF"][:successes]).to eq(1)
    end
  end
  
  describe "error handling" do
    it "handles malformed lines gracefully" do
      expect {
        handler.process_line(nil)
        handler.process_line("")
        handler.process_line("malformed data")
      }.not_to raise_error
    end
    
    it "recovers from parsing errors" do
      lines = [
        "> HCI Event: Extended Inquiry Result (0x2f) plen 255",
        "malformed line",
        "        Address: AA:BB:CC:DD:EE:FF",
        nil,
        "        RSSI: -42 dBm"
      ]
      
      expect {
        lines.each { |line| handler.process_line(line) if line }
      }.not_to raise_error
    end
  end
  
  describe "buffer management" do
    it "clears buffer after processing events" do
      handler.buffer = ["line1", "line2", "line3"]
      handler.send(:clear_buffer)
      expect(handler.buffer).to be_empty
    end
    
    it "maintains buffer size limits" do
      # Add many lines to test buffer overflow handling
      1000.times do |i|
        handler.process_line("Test line #{i}")
      end
      
      expect(handler.buffer.size).to be <= 500 # Assuming 500 line limit
    end
  end
end 