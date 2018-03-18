# frozen_string_literal: true

require 'bundler/setup'
require 'after_commit_everywhere'
require 'pry'

log = Logger.new('tmp/db.log')
log.sev_threshold = Logger::DEBUG
ActiveRecord::Base.logger = log
ActiveRecord::Base.establish_connection('sqlite3::memory:')

# Emulates models stored in another database
class AnotherDb < ActiveRecord::Base
  establish_connection 'sqlite3::memory:'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
