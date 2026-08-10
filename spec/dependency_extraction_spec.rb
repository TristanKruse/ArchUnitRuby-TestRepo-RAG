# frozen_string_literal: true

RSpec.describe 'ArchUnitRuby dependency extraction' do
  let(:fixture_root) { File.expand_path('..', __dir__).tr('\\', '/') }
  let(:edges) { ArchUnit::Extraction.extract_graph(fixture_root) }

  around do |example|
    ArchUnit.clear_graph_cache
    example.run
    ArchUnit.clear_graph_cache
  end

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

  def layer_for(path)
    path[%r{\Alib/rag_pipeline/([^/]+)/}, 1]
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

  it 'represents every source and keeps source-target pairs unique' do
    source_files = ArchUnit::Extraction.enumerate_source_files(fixture_root)
    self_edge_sources = edges.select { |edge| edge.source == edge.target }.map(&:source)
    pairs = edges.map { |edge| [edge.source, edge.target] }

    expect(self_edge_sources).to contain_exactly(*source_files)
    expect(pairs.uniq).to eq(pairs)
  end

  it 'reuses the graph until the public cache escape hatch is called' do
    cached = ArchUnit::Extraction.extract_graph(fixture_root)

    expect(cached).to equal(edges)
    ArchUnit.clear_graph_cache
    expect(ArchUnit::Extraction.extract_graph(fixture_root)).not_to equal(edges)
  end

  it 'honors a scoped ignore directive without removing its source node' do
    source = 'lib/rag_pipeline/shared/legacy_adapter.rb'

    expect(edges).to include(
      ArchUnit::Edge.new(source: source, target: source, external: false)
    )
    expect(edges).not_to include_edge(
      source: source,
      target: 'lib/rag_pipeline/services/rag_service.rb',
      external: false,
      import_kind: :require_relative
    )
  end

  it 'projects concrete dependencies into layer-level evidence' do
    projected = ArchUnit::Common::Projection.project_edges(edges) do |edge|
      source_layer = layer_for(edge.source)
      target_layer = layer_for(edge.target)
      next if edge.external || edge.source == edge.target || !source_layer || !target_layer

      ArchUnit::MappedEdge.new(source_label: source_layer, target_label: target_layer)
    end

    api_to_retrieval = projected.find do |edge|
      edge.source_label == 'api' && edge.target_label == 'retrieval'
    end
    shared_to_services = projected.find do |edge|
      edge.source_label == 'shared' && edge.target_label == 'services'
    end

    expect(api_to_retrieval.cumulated_edges.length).to eq(2)
    expect(shared_to_services.cumulated_edges.length).to eq(1)
  end
end
