Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
source 'http://rubygems.org'

# Current DataMapper dependencies (to be phased out)
gem 'dm-migrations'
gem 'dm-sqlite-adapter'
gem 'dm-timestamps'
gem 'dm-validations'

# New Sequel ORM dependencies
gem 'sequel', '~> 5.75'
# gem 'sequel_pg' # PostgreSQL adapter (optional) - not needed for SQLite
gem 'sqlite3', '~> 1.6'  # Updated for Ruby 3.x compatibility

# Other dependencies
gem 'louis'
gem 'ruby-dbus', '~> 0.23.0'  # D-Bus integration for BlueZ communication

group :development do
  gem 'pry'
  gem 'sequel-annotate' # For model annotations
end

group :test, :development do
  gem 'rake'
  gem 'rspec', '~> 3.12'
  gem 'rspec-its'
  gem 'simplecov', require: false
  gem 'factory_bot', '~> 6.2'
  gem 'faker', '~> 3.2'  # Updated for Ruby 3.x compatibility
  gem 'database_cleaner', '~> 2.0'
  gem 'database_cleaner-sequel' # Sequel adapter for database_cleaner
  gem 'timecop', '~> 0.9'
  gem 'webmock', '~> 3.18'
end
