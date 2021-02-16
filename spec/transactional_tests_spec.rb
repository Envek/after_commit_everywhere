# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "rails"
require "action_controller/railtie"

class TestApp < Rails::Application
  config.eager_load = true
  config.logger = Logger.new("/dev/null")
end
TestApp.initialize!

require "rspec/rails"
require "isolator"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end

RSpec.describe "use_transactional_tests=true" do
  include AfterCommitEverywhere

  before(:all) do
    Isolator.enable!
  end

  after(:all) do
    Isolator.disable!
  end

  subject do
    # workaround for lazy transactions https://github.com/rails/rails/pull/32647
    ActiveRecord::Base.connection.execute("SELECT 1")
    # Boom or not to boom?
    raise Isolator::UnsafeOperationError if Isolator.within_transaction?
  end

  it "doesn't raise when no transaction" do
    expect { subject }.not_to raise_error
  end

  it "raises with transaction without after_commit" do
    expect { ActiveRecord::Base.transaction { subject } }.to \
      raise_error(Isolator::UnsafeOperationError)
  end

  it "doesn't raise with transaction and after_commit" do
    expect { ActiveRecord::Base.transaction { after_commit { subject } } }
      .not_to raise_error
  end
end
