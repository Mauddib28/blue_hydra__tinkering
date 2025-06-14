# Sequel version of the SyncVersion model
require_relative 'sequel_base'
require 'securerandom'

module BlueHydra
  module Models
    class SyncVersion < Sequel::Model(:blue_hydra_sync_versions)
      include SequelBase
      
      # Validations
      def validate
        super
        # Generate version before validation if needed
        generate_version if version.nil? || version.empty?
        validates_presence :version
      end
      
      # Before save hook to generate version (keep for safety)
      def before_save
        super
        generate_version if version.nil? || version.empty?
      end
      
      # Generate a new UUID version
      def generate_version
        self.version = SecureRandom.uuid
      end
      
      # Get or create the singleton sync version
      def self.current
        first || create
      end
      
      # Update to a new version
      def self.update_version!
        current.tap do |sv|
          sv.generate_version
          sv.save
        end
      end
    end
  end
end 