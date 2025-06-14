# Model shim to allow DataMapper and Sequel models to coexist
# This provides a smooth migration path from DataMapper to Sequel

module BlueHydra
  # Check if we're using Sequel (Ruby 3.x) or DataMapper (Ruby 2.x)
  def self.using_sequel?
    RUBY_VERSION >= '3.0.0' && defined?(BlueHydra::SequelDB) && BlueHydra::SequelDB.db
  end
  
  # Load appropriate models based on Ruby version
  if RUBY_VERSION >= '3.0.0'
    # Ruby 3.x: Load Sequel models
    require_relative 'sequel_db'
    require_relative 'models/device' if defined?(BlueHydra::SequelDB) && BlueHydra::SequelDB.db
    require_relative 'models/sync_version' if defined?(BlueHydra::SequelDB) && BlueHydra::SequelDB.db
  
  # Create aliases for backward compatibility
    if defined?(BlueHydra::Models::Device)
      Device = Models::Device
    
      # Add DataMapper compatibility methods to Device class
      class Models::Device
        def self.all(conditions = {})
          if conditions.empty?
            super()
          else
            dataset = self
            conditions.each do |key, value|
              if key.to_s.include?('.')
                # Handle special DataMapper syntax like :updated_at.gte
                field, operator = key.to_s.split('.')
                case operator
                when 'gte'
                  dataset = dataset.where(Sequel.lit("#{field} >= ?", value))
                when 'lte'
                  dataset = dataset.where(Sequel.lit("#{field} <= ?", value))
                when 'gt'
                  dataset = dataset.where(Sequel.lit("#{field} > ?", value))
                when 'lt'
                  dataset = dataset.where(Sequel.lit("#{field} < ?", value))
                else
                  dataset = dataset.where(key => value)
                end
              else
                dataset = dataset.where(key => value)
              end
            end
            dataset.all
          end
        end
        
        def self.first_or_create(conditions = {})
          where(conditions).first || create(conditions)
        end
        
        def self.get(id)
          self[id]
        end
        
        def destroy
          delete
        end
        
        def update(attributes)
          set(attributes)
          save
        end
        
        # Make attribute_dirty? work like DataMapper
        def attribute_dirty?(attr)
          column_changed?(attr)
        end
        
        # Add errors compatibility
        def errors
          @errors_wrapper ||= ErrorsWrapper.new(self)
        end
        
        # Simple errors wrapper for DataMapper compatibility
        class ErrorsWrapper
          def initialize(model)
            @model = model
          end
          
          def keys
            @model.errors.keys
          end
          
          def [](key)
            @model.errors[key]
          end
        end
      end
    end
    
    if defined?(BlueHydra::Models::SyncVersion)
      SyncVersion = Models::SyncVersion
      
      # Add DataMapper compatibility methods to SyncVersion class
      class Models::SyncVersion
        def self.all(conditions = {})
          if conditions.empty?
            super()
          else
            where(conditions).all
          end
        end
        
        def self.first
          super
        end
        
        def self.count
          super
        end
        
        def self.new(attrs = {})
          super(attrs)
        end
        
        def destroy
          delete
        end
      end
    end
  else
    # Ruby 2.x: Load DataMapper models
    require_relative 'device'
    require_relative 'sync_version'
  end
  
  # Set up model aliases based on Ruby version
  def self.setup_model_aliases
    if RUBY_VERSION >= '3.0.0'
      # Ruby 3.x: Alias Sequel models to the main namespace
      const_set(:Device, Models::Device)
      const_set(:SyncVersion, Models::SyncVersion)
    else
      # Ruby 2.x: Models are already in the main namespace (DataMapper)
      # No aliasing needed
    end
  end
end 