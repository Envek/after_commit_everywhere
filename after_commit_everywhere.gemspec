# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'after_commit_everywhere/version'

Gem::Specification.new do |spec|
  spec.name          = 'after_commit_everywhere'
  spec.version       = AfterCommitEverywhere::VERSION
  spec.authors       = ['Andrey Novikov']
  spec.email         = ['envek@envek.name']

  spec.summary       = <<-MSG.strip
    Executes code after database commit wherever you want in your application
  MSG

  spec.description = <<-MSG.strip
    Brings before_commit, after_commit, and after_rollback transactional \
    callbacks outside of your ActiveRecord models.
  MSG
  spec.homepage      = 'https://github.com/Envek/after_commit_everywhere'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 3.2'
  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'isolator'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rspec-rails'
end
