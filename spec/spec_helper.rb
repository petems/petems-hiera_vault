# frozen_string_literal: true

require 'rspec-puppet'
require 'rspec-puppet-utils'
require 'puppetlabs_spec_helper/module_spec_helper'

require 'simplecov'
require 'simplecov-console'

class FakeFunction
  def self.dispatch(name, &block); end
end

module Puppet
  module Functions
    def self.create_function(_name, &block)
      FakeFunction.class_eval(&block)
    end
  end
end

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Console
]

SimpleCov.start do
  track_files 'lib/**/*.rb'

  add_filter 'lib/puppet/resource_api/version.rb'

  add_filter '/spec'

  # do not track vendored files
  add_filter '/vendor'
  add_filter '/.bundle'
  add_filter 'Rakefile'
  add_filter 'Gemfile'

  # do not track gitignored files
  # this adds about 4 seconds to the coverage check
  # this could definitely be optimized
  add_filter do |f|
    # system returns true if exit status is 0, which with git-check-ignore means file is ignored
    system("git check-ignore --quiet #{f.filename}")
  end
end

RSpec.configure do |config|
  config.expect_with :rspec
  # Enable rpec-mocks
  config.mock_with :rspec

  begin
    config.warnings = false
  end
end
