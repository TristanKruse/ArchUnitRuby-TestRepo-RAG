# frozen_string_literal: true

RSpec.describe 'ArchUnitRuby dependency extraction' do
  let(:fixture_root) { File.expand_path('..', __dir__).tr('\\', '/') }
  let(:edges) { ArchUnit::Extraction.extract_dependencies(fixture_root) }

  def include_edge(source:, target:, external:, import_kind:)
    include(
      ArchUnit::Edge.new(
        source: source,
        target: target,
        external: external,
        import_kinds: [import_kind]
      )
    )
  end

  it 'extracts the intended dependencies between application layers' do
    expect(edges).to include_edge(
      source: 'lib/rag_pipeline/services/rag_service.rb',
      target: 'lib/rag_pipeline/retrieval/embedder.rb',
      external: false,
      import_kind: :require_relative
    )
    expect(edges).to include_edge(
      source: 'lib/rag_pipeline/models/document.rb',
      target: 'lib/rag_pipeline/shared/config.rb',
      external: false,
      import_kind: :require_relative
    )
  end

  it 'makes both deliberate architecture violations observable' do
    expect(edges).to include_edge(
      source: 'lib/rag_pipeline/api/bad_shortcut.rb',
      target: 'lib/rag_pipeline/retrieval/embedder.rb',
      external: false,
      import_kind: :require_relative
    )
    expect(edges).to include_edge(
      source: 'lib/rag_pipeline/shared/leaky.rb',
      target: 'lib/rag_pipeline/services/rag_service.rb',
      external: false,
      import_kind: :require_relative
    )
  end

  it 'keeps standard-library dependencies external and named as written' do
    expect(edges).to include_edge(
      source: 'lib/rag_pipeline/retrieval/embedder.rb',
      target: 'digest',
      external: true,
      import_kind: :require
    )
  end

  it 'only points internal edges at source files enumerated by ArchUnitRuby' do
    source_files = ArchUnit::Extraction.enumerate_source_files(fixture_root)
    internal_targets = edges.reject(&:external).map(&:target)

    expect(internal_targets).to all(satisfy { |target| source_files.include?(target) })
    expect(edges.flat_map { |edge| [edge.source, edge.target] }).not_to include(
      'coverage/generated.rb', 'pkg/generated.rb', 'tmp/generated.rb', 'vendor/dependency.rb'
    )
  end
end
