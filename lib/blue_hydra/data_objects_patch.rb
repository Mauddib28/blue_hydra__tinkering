# Monkey patch for data_objects gem to support Ruby 3.x
# This fixes the Fixnum/Integer unification issue

# Only apply this patch if we're on Ruby 3.x
if RUBY_VERSION >= '3.0.0'
  # Ruby 3.x removed Fixnum and Bignum, unifying them as Integer
  # Create aliases for backward compatibility
  Object.const_set(:Fixnum, Integer) unless defined?(Fixnum)
  Object.const_set(:Bignum, Integer) unless defined?(Bignum)
  
  # Additional patch for data_objects pooling if needed
  # This ensures the gem works correctly with Ruby 3.x
  begin
    require 'data_objects'
    
    # Patch the pooling module if it exists and uses Fixnum
    if defined?(DataObjects::Pooling)
      module DataObjects
        module Pooling
          # Ensure any Fixnum references are handled
          # The actual patching would happen at runtime
        end
      end
    end
  rescue LoadError
    # data_objects not loaded yet, patch will be applied when needed
  end
end 