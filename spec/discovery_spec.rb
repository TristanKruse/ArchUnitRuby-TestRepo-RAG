# frozen_string_literal: true

RSpec.describe 'ArchUnitRuby project discovery' do
  let(:fixture_root) { File.expand_path('..', __dir__).tr('\\', '/') }

  it 'locates the fixture from a nested source directory' do
    nested_directory = File.join(fixture_root, 'lib', 'rag_pipeline', 'api')

    expect(ArchUnit::Extraction.locate_project(working_directory: nested_directory))
      .to eq(fixture_root)
  end

  it 'enumerates every real Ruby source with project-relative identifiers' do
    files = ArchUnit::Extraction.enumerate_source_files(fixture_root)

    expect(files).to include(
      'lib/rag_pipeline/api/bad_shortcut.rb',
      'lib/rag_pipeline/api/endpoints.rb',
      'lib/rag_pipeline/services/rag_service.rb',
      'lib/rag_pipeline/shared/leaky.rb',
      'spec/discovery_spec.rb'
    )
  end

  it 'excludes dependency, cache, and build-output decoys' do
    files = ArchUnit::Extraction.enumerate_source_files(fixture_root)

    expect(files).not_to include(
      '.cache/cached.rb',
      'coverage/generated.rb',
      'pkg/generated.rb',
      'tmp/generated.rb',
      'vendor/dependency.rb'
    )
  end
end
