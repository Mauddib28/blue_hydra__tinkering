FactoryBot.define do
  factory :device, class: 'BlueHydra::Device' do
    sequence(:address) { |n| "AA:BB:CC:DD:EE:%02X" % (n % 256) }
    name { Faker::Device.model_name }
    vendor { Faker::Company.name }
    status { 'online' }
    last_seen { Time.now.to_i }
    
    trait :classic do
      classic_mode { true }
      classic_major_class { "Phone (cellular, cordless, payphone, modem)" }
      classic_minor_class { "Smart phone" }
      classic_rssi { JSON.generate(["-36 dBm (0xdc)"]) }
    end
    
    trait :le do
      le_mode { true }
      le_address_type { "Public" }
      le_rssi { JSON.generate(["-42 dBm"]) }
    end
    
    trait :offline do
      status { 'offline' }
      last_seen { Time.now.to_i - 3600 }
    end
    
    trait :with_services do
      classic_service_uuids { JSON.generate([
        "PnP Information (0x1200)",
        "Audio Source (0x110a)",
        "A/V Remote Control Target (0x110c)"
      ]) }
    end
    
    trait :ibeacon do
      le_mode { true }
      le_proximity_uuid { "f7826da6-4fa2-4e98-8024-bc5b71e0893e" }
      le_major_num { "1" }
      le_minor_num { "100" }
      company { "Apple, Inc." }
      le_company_data { "0215f7826da64fa24e988024bc5b71e0893e00010064c5" }
    end
    
    factory :classic_device, traits: [:classic]
    factory :le_device, traits: [:le]
    factory :dual_mode_device, traits: [:classic, :le]
    factory :ibeacon_device, traits: [:ibeacon]
  end
  
  factory :sync_version, class: 'BlueHydra::SyncVersion' do
    version { SecureRandom.uuid }
  end
end 