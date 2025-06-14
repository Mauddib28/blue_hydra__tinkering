# encoding: UTF-8
require 'rubygems'
require 'rspec'
require 'rspec/its'
require 'simplecov'
require 'factory_bot'
require 'faker'
require 'database_cleaner'
require 'timecop'
require 'webmock/rspec'

# Start code coverage
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_group 'Models', 'lib/blue_hydra/device'
  add_group 'Models', 'lib/blue_hydra/sync_version'
  add_group 'Core', 'lib/blue_hydra/runner'
  add_group 'Parsers', 'lib/blue_hydra/parser'
  add_group 'Handlers', 'lib/blue_hydra/btmon_handler'
  add_group 'Utils', 'lib/blue_hydra/command'
end

$:.unshift(File.dirname(File.expand_path('../../lib/blue_hydra.rb',__FILE__)))

# Set test environment
ENV["BLUE_HYDRA"] = "test"

# Apply Ruby 3.x compatibility patches before loading any gems
require 'blue_hydra/data_objects_patch'

# Load Blue Hydra
require 'blue_hydra'

# Test configuration
BlueHydra.daemon_mode = true
BlueHydra.pulse = false

# Load support files
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Database cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
  
  # Reset time after time-sensitive tests
  config.after(:each) do
    Timecop.return
  end
  
  # Disable external HTTP requests
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
  
  # Focus on specific tests with :focus
  config.filter_run_when_matching :focus
  
  # Run specs in random order
  config.order = :random
  
  # Seed for randomization
  Kernel.srand config.seed
end

# Helper methods for tests
module BlueHydraTestHelpers
  def create_test_device(attrs = {})
    default_attrs = {
      address: generate_mac_address,
      name: Faker::Device.model_name,
      vendor: Faker::Company.name,
      status: 'online',
      last_seen: Time.now.to_i
    }
    
    BlueHydra::Device.create(default_attrs.merge(attrs))
  end
  
  def generate_mac_address
    6.times.map { '%02X' % rand(256) }.join(':')
  end
  
  def fixture_path(filename)
    File.expand_path("../fixtures/#{filename}", __FILE__)
  end
  
  def load_fixture(filename)
    File.read(fixture_path(filename))
  end
end

RSpec.configure do |config|
  config.include BlueHydraTestHelpers
end

