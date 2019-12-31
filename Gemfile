source 'http://rubygems.org'

group :test do
  if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion, :require => false
  else
    gem 'puppet', ENV['PUPPET_VERSION'] || '~> 6'
  end

  gem 'json_pure'
  gem 'safe_yaml'

  gem 'rake'
  gem 'puppet-lint'
  gem 'rspec-puppet'
  gem 'puppet-syntax'
  gem 'puppetlabs_spec_helper'
  gem 'simplecov'
  gem 'simplecov-console'
  gem 'metadata-json-lint'
  gem 'vault', '>= 0.13.0'
  gem 'debouncer'
end

group :development do
  gem 'puppet-blacksmith'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'github_changelog_generator'
  gem 'activesupport', '< 5'
  gem 'pdk'
  gem 'pry'
  gem 'rb-readline'
end
