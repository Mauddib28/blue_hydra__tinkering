# Base model module for Sequel models in Blue Hydra
require 'sequel'
require 'json'

module BlueHydra
  module Models
    # Base module with common functionality for all Sequel models
    module SequelBase
      def self.included(base)
        base.class_eval do
      # Common plugins for all models
      plugin :timestamps, update_on_create: true
      plugin :validation_helpers
      plugin :json_serializer
      plugin :dirty
      
      # Custom setter for JSON array fields
      # Mimics DataMapper behavior of storing arrays as JSON
      def self.json_array_field(field_name)
        define_method("#{field_name}=") do |value|
          if value.is_a?(Array)
            # For RSSI fields, limit to last 100 values
            if field_name.to_s.include?('rssi')
              existing = begin
                JSON.parse(self[field_name] || '[]')
              rescue
                []
              end
              combined = existing + value
              value = combined.last(100)
            end
            super(JSON.generate(value))
          elsif value.is_a?(String)
            # Already JSON, store as-is
            super(value)
          elsif value.nil?
            super(nil)
          else
            super(JSON.generate([value]))
          end
        end
        
        # Getter that always returns an array
        define_method(field_name) do
          value = super()
          return [] if value.nil? || value.empty?
          
          begin
            parsed = JSON.parse(value)
            parsed.is_a?(Array) ? parsed : [parsed]
          rescue JSON::ParserError
            []
          end
        end
      end
      
      # Custom setter for JSON object fields
      def self.json_object_field(field_name)
        define_method("#{field_name}=") do |value|
          if value.is_a?(Hash)
            super(JSON.generate(value))
          elsif value.is_a?(String)
            # Already JSON, store as-is
            super(value)
          elsif value.nil?
            super(nil)
          else
            super(JSON.generate(value))
          end
        end
        
        # Getter that always returns a hash
        define_method(field_name) do
          value = super()
          return {} if value.nil? || value.empty?
          
          begin
            parsed = JSON.parse(value)
            parsed.is_a?(Hash) ? parsed : {}
          rescue JSON::ParserError
            {}
          end
        end
      end
        end
        
        # Add class methods
        base.extend(ClassMethods)
      end
      
      # Class methods to be added to including classes
      module ClassMethods
        # DataMapper compatibility method
        def get(id)
          self[id]
        end
        
        # DataMapper compatibility method
        def all(conditions = {})
          dataset = self.dataset
          
          conditions.each do |key, value|
            dataset = if value.is_a?(Array)
              dataset.where(key => value)
            elsif value.is_a?(Hash) && value.key?(:not)
              dataset.exclude(key => value[:not])
            elsif key.to_s.end_with?('.not')
              actual_key = key.to_s.sub('.not', '').to_sym
              dataset.exclude(actual_key => value)
            else
              dataset.where(key => value)
            end
          end
          
          dataset.all
        end
        
        # DataMapper compatibility method
        def first(conditions = {})
          all(conditions).first
        end
        
        # DataMapper compatibility method
        def last(conditions = {})
          all(conditions).last
        end
        
        # DataMapper compatibility method
        def count(conditions = {})
          dataset = self.dataset
          conditions.each do |key, value|
            dataset = dataset.where(key => value)
          end
          dataset.count
        end
        
        # DataMapper compatibility method for create
        def create(attributes = {})
          new(attributes).save
        end
        
        # DataMapper compatibility method
        def destroy
          dataset.destroy
        end
        
        # DataMapper compatibility method
        def first_or_create(conditions = {})
          first(conditions) || create(conditions)
        end
      end
      
      # Instance methods
      
      # Helper method to check if a field has changed
      # Provides DataMapper-like dirty tracking
      def attribute_dirty?(attr)
        column_changed?(attr)
      end
      
      # Get original value of an attribute
      def attribute_was(attr)
        initial_value(attr)
      end
      
      # Get all dirty attributes
      def dirty_attributes
        changed_columns
      end
      
      # DataMapper compatibility method
      def destroy
        delete
      end
      
      # DataMapper compatibility method
      def update(attributes)
        set(attributes)
        save
      end
      
      # Before save hook for common operations
      def before_save
        super
        # Can be overridden in subclasses
      end
      
      # After save hook for common operations
      def after_save
        super
        # Can be overridden in subclasses
      end
    end
  end
end 