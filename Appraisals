# frozen_string_literal: true

appraise "activerecord-4-2" do
  gem "activerecord", "~> 4.2.0"
  gem "sqlite3", "~> 1.3.6"
end

appraise "activerecord-5-0" do
  gem "activerecord", "~> 5.0.0"
  gem "sqlite3", "~> 1.3.6"
end

appraise "activerecord-5-1" do
  gem "activerecord", "~> 5.1.0"
  gem "sqlite3", "~> 1.3", ">= 1.3.6"
end

appraise "activerecord-5-2" do
  gem "activerecord", "~> 5.2.0"
  gem "sqlite3", "~> 1.3", ">= 1.3.6"
end

appraise "activerecord-6-0" do
  gem "activerecord", "~> 6.0.0"
  gem "sqlite3", "~> 1.4"
end

appraise "activerecord-6-1" do
  gem "activerecord", "~> 6.1.0"
  gem "sqlite3", "~> 1.4"
  gem "rspec-rails", "~> 4.0"
end

appraise "activerecord-7-0" do
  gem "activerecord", "~> 7.0.0"
  gem "sqlite3", "~> 1.4"
  gem "rspec-rails", "~> 5.0"
end

appraise "activerecord-master" do
  git "https://github.com/rails/rails.git" do
    gem "rails"
    gem "activerecord"
  end

  gem "sqlite3", "~> 1.4"
  gem "rspec-rails", "~> 5.0"
end
