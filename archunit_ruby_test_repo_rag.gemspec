# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'archunit_ruby_test_repo_rag'
  spec.version = '0.1.0'
  spec.authors = ['ArchUnitRuby contributors']
  spec.summary = 'Layered RAG fixture project for ArchUnitRuby'
  spec.required_ruby_version = '>= 3.3'
  spec.files = Dir['lib/**/*.rb', 'README.md', 'architecture.puml']
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
