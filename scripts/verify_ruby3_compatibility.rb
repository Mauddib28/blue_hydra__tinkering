#!/usr/bin/env ruby

# Ruby 3.x Compatibility Verification Script
# This script checks for common compatibility issues when running Blue Hydra on Ruby 3.x

puts "Ruby 3.x Compatibility Verification"
puts "=" * 50
puts "Ruby Version: #{RUBY_VERSION}"
puts "Ruby Platform: #{RUBY_PLATFORM}"
puts

# Check for required Ruby version
if RUBY_VERSION < "3.0.0"
  puts "❌ ERROR: This script requires Ruby 3.0.0 or higher"
  exit 1
end

# Test Fixnum/Bignum patch
puts "Testing Fixnum/Bignum compatibility..."
begin
  require_relative '../lib/blue_hydra/data_objects_patch'
  
  # Test that the constants exist
  if defined?(Fixnum) && defined?(Bignum)
    puts "✅ Fixnum and Bignum constants are available"
  else
    puts "❌ Fixnum/Bignum constants missing"
  end
  
  # Test that they resolve to Integer
  if Fixnum == Integer && Bignum == Integer
    puts "✅ Fixnum and Bignum correctly resolve to Integer"
  else
    puts "❌ Fixnum/Bignum do not resolve to Integer"
  end
rescue => e
  puts "❌ Error loading data_objects patch: #{e.message}"
end
puts

# Test string encoding
puts "Testing string encoding..."
test_string = "test".dup
begin
  # Test that frozen string literal doesn't break
  test_string.upcase!
  puts "✅ String mutations work correctly"
rescue => e
  puts "❌ String mutation error: #{e.message}"
end
puts

# Test require paths
puts "Testing require paths..."
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

required_files = [
  'blue_hydra',
  'blue_hydra/device',
  'blue_hydra/sync_version'
]

required_files.each do |file|
  begin
    require file
    puts "✅ Successfully required: #{file}"
  rescue LoadError => e
    puts "❌ Failed to require #{file}: #{e.message}"
  rescue => e
    puts "⚠️  Required #{file} but got error: #{e.message}"
  end
end
puts

# Test DataMapper with patch
puts "Testing DataMapper with Ruby 3.x patch..."
begin
  require 'data_mapper'
  puts "✅ DataMapper loaded successfully"
  
  # Test basic DataMapper functionality
  DataMapper.setup(:default, 'sqlite::memory:')
  
  class TestModel
    include DataMapper::Resource
    property :id, Serial
    property :name, String
  end
  
  DataMapper.finalize
  DataMapper.auto_migrate!
  
  test_record = TestModel.create(name: "Test")
  if test_record.saved?
    puts "✅ DataMapper basic operations work"
  else
    puts "❌ DataMapper save failed"
  end
rescue => e
  puts "❌ DataMapper error: #{e.message}"
  puts "   #{e.backtrace.first}"
end
puts

# Test Sequel
puts "Testing Sequel compatibility..."
begin
  require 'sequel'
  
  db = Sequel.sqlite
  db.create_table :test do
    primary_key :id
    String :name
  end
  
  db[:test].insert(name: "Test")
  if db[:test].count == 1
    puts "✅ Sequel operations work correctly"
  else
    puts "❌ Sequel insert failed"
  end
rescue => e
  puts "❌ Sequel error: #{e.message}"
end
puts

# Check for deprecated features
puts "Checking for deprecated features..."
warnings = []

# Capture warnings
original_verbose = $VERBOSE
$VERBOSE = true
warning_count = 0

# Monkey patch warning to capture them
module Kernel
  alias_method :original_warn, :warn
  def warn(message)
    $warning_count ||= 0
    $warning_count += 1
    original_warn(message)
  end
end

# Load Blue Hydra to check for warnings
begin
  load File.expand_path('../bin/blue_hydra', __dir__)
rescue SystemExit
  # Expected when running with --help
end

$VERBOSE = original_verbose

if $warning_count && $warning_count > 0
  puts "⚠️  Found #{$warning_count} warnings (may include normal deprecations)"
else
  puts "✅ No warnings detected"
end
puts

# Summary
puts "Summary"
puts "=" * 50
puts "Ruby 3.x compatibility verification complete."
puts "Review any ❌ or ⚠️ items above for potential issues." 