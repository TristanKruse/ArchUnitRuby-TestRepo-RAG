# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

if ENV['ARCHUNIT_RUBY_PATH']
  gem 'archunit', path: ENV.fetch('ARCHUNIT_RUBY_PATH')
else
  gem 'archunit', path: '../ArchUnitRuby'
end

gem 'rake', '~> 13.2'
gem 'rspec', '~> 3.13'
gem 'rubocop', '~> 1.80'
