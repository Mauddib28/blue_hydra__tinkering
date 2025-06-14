require_relative 'sequel_base'

module BlueHydra
  module Models
    class Device < Sequel::Model(:blue_hydra_devices)
      include SequelBase

      # DataMapper-style accessor
      attr_accessor :filthy_attributes

      # Use the Sequel validation plugin
      plugin :validation_helpers

      # MAC address regex for validation
      MAC_REGEX = /^((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})$/i

      # Validations
      def validate
        super
        validates_format MAC_REGEX, :address, message: 'is not a valid MAC address'
        validates_includes ['online', 'offline'], :status, allow_nil: true
        
        # Normalize address to uppercase before validation
        self.address = address.upcase if address
      end

      # Before save hooks (in order)
      def before_save
        super
        set_vendor
        set_uap_lap
        set_uuid
        prepare_the_filth
      end

      # After save hook
      def after_save
        super
        sync_to_pulse
      end

      # Class method to sync all devices to pulse
      def self.sync_all_to_pulse(since = Time.at(Time.now.to_i - 604800))
        where(Sequel.lit('updated_at >= ?', since)).each do |dev|
          dev.sync_to_pulse(true)
        end
      end

      # Mark hosts as 'offline' if we haven't seen them for a while
      def self.mark_old_devices_offline(startup = false)
        if startup
          # Unknown mode devices have 15 min timeout (SHOULD NOT EXIST, BUT WILL CLEAN OLD DBS)
          where(le_mode: false, classic_mode: false, status: 'online').each do |device|
            if device.last_seen < (Time.now.to_i - (15 * 60))
              device.update(status: 'offline')
            end
          end
        end

        # Mark old devices as offline without deleting (2 weeks old)
        where(Sequel.lit('updated_at <= ?', Time.at(Time.now.to_i - 604800 * 2))).each do |dev|
          if dev.status != 'offline'
            dev.update(status: 'offline')
          end
        end

        # Classic mode devices have 15 min timeout
        where(classic_mode: true, status: 'online').each do |device|
          if device.last_seen < (Time.now.to_i - (15 * 60))
            device.update(status: 'offline')
          end
        end

        # LE mode devices have 3 min timeout
        where(le_mode: true, status: 'online').each do |device|
          if device.last_seen < (Time.now.to_i - (60 * 3))
            device.update(status: 'offline')
          end
        end
      end

      # Create or update a device from parser result
      def self.update_or_create_from_result(result)
        result = result.dup
        address = result[:address].first

        lpu = result[:le_proximity_uuid].first if result[:le_proximity_uuid]
        lmn = result[:le_major_num].first if result[:le_major_num]
        lmn2 = result[:le_minor_num].first if result[:le_minor_num]

        c = result[:company].first if result[:company]
        d = result[:le_company_data].first if result[:le_company_data]

        # Find existing record using various strategies
        record = where(address: address).first ||
                 find_by_uap_lap(address) ||
                 (lpu && lmn && lmn2 && where(
                   le_proximity_uuid: lpu,
                   le_major_num: lmn,
                   le_minor_num: lmn2
                 ).first) ||
                 (c && d && c =~ /Gimbal/i && where(
                   le_company_data: d
                 ).first) ||
                 new

        # Mark as online since we're processing it
        record.status = 'online'

        # Set last_seen
        if result[:last_seen] &&
           result[:last_seen].class == Array &&
           !result[:last_seen].empty?
          record.last_seen = result[:last_seen].sort.last
        else
          record.last_seen = Time.now.to_i
        end

        # Update normal attributes
        %w[
          address name manufacturer short_name lmp_version firmware
          classic_major_class classic_minor_class le_tx_power classic_tx_power
          le_address_type company appearance
          le_random_address_type le_company_uuid le_company_data le_proximity_uuid
          le_major_num le_minor_num classic_mode le_mode
        ].map(&:to_sym).each do |attr|
          if result[attr]
            if result[attr].uniq.count > 1
              BlueHydra.logger.debug(
                "#{address} multiple values detected for #{attr}: #{result[attr].inspect}. Using first value..."
              )
            end
            record.send("#{attr}=", result.delete(attr).uniq.sort.first)
          end
        end

        # Handle company_type special case
        if result[:company_type]
          data = result.delete(:company_type).uniq.sort.first
          if data =~ /Unknown/
            data = 'Unknown'
            record.company_type = data
          end
        end

        # Update array attributes
        %w[
          classic_features le_features le_flags classic_channels classic_class le_rssi
          classic_rssi le_service_uuids classic_service_uuids le_features_bitmap classic_features_bitmap
        ].map(&:to_sym).each do |attr|
          if result[attr]
            record.send("#{attr}=", result.delete(attr))
          end
        end

        if record.valid?
          record.save
          if where(uap_lap: record.uap_lap).count > 1
            BlueHydra.logger.warn("Duplicate UAP/LAP detected: #{record.uap_lap}.")
          end
        else
          BlueHydra.logger.warn("#{address} can not save.")
          record.errors.each do |attr, msgs|
            msgs.each do |msg|
              BlueHydra.logger.warn("#{attr}: #{msg} (#{record.send(attr)})")
            end
          end
        end

        record
      end

      # Set vendor from Louis lookup
      def set_vendor(force = false)
        if le_address_type == 'Random'
          self.vendor = 'N/A - Random Address'
        elsif vendor.nil? || vendor == 'Unknown' || force
          vendor_info = Louis.lookup(address)
          self.vendor = vendor_info['long_vendor'] || vendor_info['short_vendor']
        end
      end

      # Set UUID if not present
      def set_uuid
        return if uuid

        new_uuid = SecureRandom.uuid
        until self.class.where(uuid: new_uuid).empty?
          new_uuid = SecureRandom.uuid
        end
        self.uuid = new_uuid
      end

      # Set the last 4 octets of the MAC as the uap_lap values
      def set_uap_lap
        self.uap_lap = address.split(':')[2, 4].join(':')
      end

      # Lookup helper method for uap_lap
      def self.find_by_uap_lap(address)
        uap_lap = address.split(':')[2, 4].join(':')
        where(uap_lap: uap_lap).first
      end

      # List of attributes that should be synced to pulse
      def syncable_attributes
        %i[
          name vendor appearance company le_company_data company_type
          lmp_version manufacturer le_features_bitmap firmware
          classic_mode classic_features_bitmap classic_major_class
          classic_minor_class le_mode le_address_type
          le_random_address_type le_tx_power last_seen classic_tx_power
          le_features classic_features le_service_uuids
          classic_service_uuids classic_channels classic_class classic_rssi
          le_flags le_rssi le_company_uuid
        ]
      end

      # Check if attribute stores JSON data
      def is_serialized?(attr)
        %i[
          classic_channels
          classic_class
          classic_features
          le_features
          le_flags
          le_service_uuids
          classic_service_uuids
          classic_rssi
          le_rssi
        ].include?(attr)
      end

      # Track changed attributes for sync
      def prepare_the_filth
        @filthy_attributes ||= []
        syncable_attributes.each do |attr|
          @filthy_attributes << attr if column_changed?(attr)
        end
      end

      # Sync record to pulse
      def sync_to_pulse(sync_all = false)
        return unless BlueHydra.pulse || BlueHydra.pulse_debug

        send_data = {
          type: 'bluetooth',
          source: 'blue-hydra',
          version: BlueHydra::VERSION,
          data: {}
        }

        # Always include uuid, address, status
        send_data[:data][:sync_id] = uuid
        send_data[:data][:status] = status
        send_data[:data][:sync_version] = BlueHydra::SYNC_VERSION

        send_data[:data][:le_proximity_uuid] = le_proximity_uuid if le_proximity_uuid
        send_data[:data][:le_major_num] = le_major_num if le_major_num
        send_data[:data][:le_minor_num] = le_minor_num if le_minor_num

        # Include both if they are both set
        if le_company_data && company
          send_data[:data][:le_company_data] = le_company_data
          send_data[:data][:company] = company
        end

        send_data[:data][:address] = address

        @filthy_attributes ||= []

        syncable_attributes.each do |attr|
          next unless @filthy_attributes.include?(attr) || sync_all

          val = send(attr)
          next if [nil, '[]'].include?(val)

          send_data[:data][attr] = if is_serialized?(attr)
                                      JSON.parse(val)
                                    else
                                      val
                                    end
        end

        # Create and send the JSON
        json_msg = JSON.generate(send_data)
        BlueHydra::Pulse.do_send(json_msg)
      end

      # Custom setter for short_name
      def short_name=(new_name)
        return if ['', nil].include?(new_name) || name
        self.name = new_name
      end

      # Custom setter for classic_channels with merging
      def classic_channels=(channels)
        new_channels = channels.map { |x| x.split(', ').reject { |y| y =~ /^0x/ } }.flatten.sort.uniq
        current = parse_json_field(:classic_channels, [])
        self[:classic_channels] = JSON.generate((new_channels + current).uniq)
      end

      # Custom setter for classic_class with merging
      def classic_class=(new_classes)
        new_data = new_classes.flatten.uniq.reject { |x| x =~ /^0x/ }
        current = parse_json_field(:classic_class, [])
        self[:classic_class] = JSON.generate((new_data + current).uniq)
      end

      # Custom setter for classic_features with merging
      def classic_features=(new_features)
        new_data = new_features.map { |x| x.split(', ').reject { |y| y =~ /^0x/ } }.flatten.sort.uniq
        current = parse_json_field(:classic_features, [])
        self[:classic_features] = JSON.generate((new_data + current).uniq)
      end

      # Custom setter for le_features with merging
      def le_features=(new_features)
        new_data = new_features.map { |x| x.split(', ').reject { |y| y =~ /^0x/ } }.flatten.sort.uniq
        current = parse_json_field(:le_features, [])
        self[:le_features] = JSON.generate((new_data + current).uniq)
      end

      # Custom setter for le_flags with merging
      def le_flags=(flags)
        new_data = flags.map { |x| x.split(', ').reject { |y| y =~ /^0x/ } }.flatten.sort.uniq
        current = parse_json_field(:le_flags, [])
        self[:le_flags] = JSON.generate((new_data + current).uniq)
      end

      # Custom setter for le_service_uuids with merging
      def le_service_uuids=(new_uuids)
        current = parse_json_field(:le_service_uuids, [])

        # Fix old data if needed
        current_fixed = current.map do |x|
          if x.split(':')[1]
            x.split(':')[0].scan(/\(([^)]+)\)/).flatten[0].split('UUID ')[1]
          else
            x
          end
        end

        new_data = (new_uuids + current_fixed).map do |uuid|
          if uuid =~ /\(/
            uuid
          else
            "Unknown (#{ uuid })"
          end
        end

        self[:le_service_uuids] = JSON.generate(new_data.uniq)
      end

      # Custom setter for classic_service_uuids with merging
      def classic_service_uuids=(new_uuids)
        current = parse_json_field(:classic_service_uuids, [])
        new_data = (new_uuids + current).map do |uuid|
          if uuid =~ /\(/
            uuid
          else
            "Unknown (#{ uuid })"
          end
        end

        self[:classic_service_uuids] = JSON.generate(new_data.uniq)
      end

      # Custom setter for classic_rssi with limit
      def classic_rssi=(rssis)
        current = parse_json_field(:classic_rssi, [])
        new_data = current + rssis

        # Limit to last 100 entries
        new_data.shift while new_data.count > 100

        self[:classic_rssi] = JSON.generate(new_data)
      end

      # Custom setter for le_rssi with limit
      def le_rssi=(rssis)
        current = parse_json_field(:le_rssi, [])
        new_data = current + rssis

        # Limit to last 100 entries
        new_data.shift while new_data.count > 100

        self[:le_rssi] = JSON.generate(new_data)
      end

      # Custom setter for le_address_type
      def le_address_type=(type)
        type = type.split(' ')[0]
        if type =~ /Public/
          self[:le_address_type] = type
          self[:le_random_address_type] = nil if le_address_type
        elsif type =~ /Random/
          self[:le_address_type] = type
        end
      end

      # Custom setter for le_random_address_type
      def le_random_address_type=(type)
        return if le_address_type && le_address_type =~ /Public/
        self[:le_random_address_type] = type
      end

      # Custom setter for address with vendor lookup
      def address=(new_address)
        return unless new_address

        current = address
        # Normalize address to uppercase
        self[:address] = new_address.upcase

        # Update vendor if appropriate
        if current =~ /^00:00/ || new_address !~ /^00:00/
          set_vendor(true)
        end
      end

      # Custom setter for le_features_bitmap
      def le_features_bitmap=(arr)
        current = parse_json_field(:le_features_bitmap, {})
        arr.each do |(page, bitmap)|
          current[page] = bitmap
        end
        self[:le_features_bitmap] = JSON.generate(current)
      end

      # Custom setter for classic_features_bitmap
      def classic_features_bitmap=(arr)
        current = parse_json_field(:classic_features_bitmap, {})
        arr.each do |(page, bitmap)|
          current[page] = bitmap
        end
        self[:classic_features_bitmap] = JSON.generate(current)
      end

      private

      # Helper to parse JSON fields with default
      def parse_json_field(field, default)
        value = self[field]
        return default if value.nil? || value.empty?
        JSON.parse(value)
      rescue JSON::ParserError
        default
      end
    end
  end
end 