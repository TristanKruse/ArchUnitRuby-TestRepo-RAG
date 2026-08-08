# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

archunit_path = ENV.fetch('ARCHUNIT_RUBY_PATH', File.expand_path('../ArchUnitRuby', __dir__))
gem 'archunit', path: archunit_path

gem 'rake', '~> 13.2'
gem 'rspec', '~> 3.13'
gem 'rubocop', '~> 1.80'
