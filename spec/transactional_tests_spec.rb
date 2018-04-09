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
require "webmock/rspec"
require "isolator"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end

RSpec.describe "use_transactional_tests=true" do
  include AfterCommitEverywhere

  before(:all) do
    Isolator.enable!
    Isolator.transactions_threshold = 2
  end

  after(:all) do
    Isolator.disable!
  end

  before do
    stub_request(:get, "http://example.com/").to_return(body: "Badaboom")
  end

  subject { Net::HTTP.get(URI("http://example.com/")) }

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
