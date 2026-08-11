# frozen_string_literal: true

require 'json'
require 'stringio'
require 'tmpdir'

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

  def rag_layer_policy
    definitions = rag_layer_names.reduce(ArchUnit.layers(fixture_root)) do |rule, name|
      rule.layer(name).defined_by_folder("lib/rag_pipeline/#{name}")
    end
    rag_layer_dependencies.reduce(definitions) do |rule, (source, targets)|
      rule.where_layer(source).may_only_depend_on_layers(*targets)
    end
  end

  def rag_layer_names
    %w[api services retrieval llm models shared]
  end

  def rag_layer_dependencies
    {
      'api' => %w[services models], 'services' => %w[retrieval llm models],
      'retrieval' => %w[models shared], 'llm' => %w[models shared],
      'models' => %w[shared], 'shared' => []
    }
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

  it 'enforces the complete named-layer policy and exposes every deliberate violation' do
    rule = rag_layer_policy
    violations = rule.check

    expect(violations.map do |violation|
      [
        violation.source_layer,
        violation.target_layer,
        violation.dependency.source_label,
        violation.dependency.target_label
      ]
    end).to contain_exactly(
      [
        'api', 'retrieval', 'lib/rag_pipeline/api/bad_shortcut.rb',
        'lib/rag_pipeline/retrieval/embedder.rb'
      ],
      [
        'api', 'retrieval', 'lib/rag_pipeline/api/bad_shortcut.rb',
        'lib/rag_pipeline/retrieval/vector_store.rb'
      ],
      [
        'shared', 'services', 'lib/rag_pipeline/shared/leaky.rb',
        'lib/rag_pipeline/services/rag_service.rb'
      ]
    )
    expect(rule).not_to pass
    expect { expect(rule).to pass }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      /Found 3 architecture violations:.*Layer dependency violation/m
    )
  end

  it 'reports the deliberate forbidden dependency through the public slices API' do
    rule = ArchUnit.project_slices(fixture_root)
                   .defined_by('lib/rag_pipeline/(**)/')
                   .should_not.contain_dependency('api', 'retrieval')

    expect(rule.check).to contain_exactly(
      have_attributes(
        source_slice: 'api', target_slice: 'retrieval',
        rule: :contain_dependency,
        dependency: have_attributes(cumulated_edges: have_attributes(length: 2))
      )
    )
  end

  it 'validates the real graph against the checked-in PlantUML architecture' do
    rule = ArchUnit.project_slices(fixture_root)
                   .defined_by('lib/rag_pipeline/(**)/')
                   .should
                   .ignoring_external_slices
                   .adhere_to_diagram_in_file(
                     File.join(fixture_root, 'docs', 'architecture.puml')
                   )

    expect(rule.check.map { |violation| [violation.source_slice, violation.target_slice] })
      .to contain_exactly(%w[api retrieval], %w[shared services])
  end

  it 'generates and exports the actual RAG slice diagram' do
    slices = ArchUnit.project_slices(fixture_root).defined_by('lib/rag_pipeline/(**)/')
    plantuml = slices.to_plantuml

    expect(plantuml).to include(
      'component [api]', 'component [services]',
      '[api] --> [retrieval]', '[shared] --> [services]'
    )
    Dir.mktmpdir do |directory|
      output = File.join(directory, 'nested', 'rag-architecture.puml')
      expect(slices.export_as_plantuml(output)).to be_nil
      expect(File.binread(output)).to eq(plantuml)
    end
  end

  it 'queries one immutable graph snapshot through all six report formats' do
    report = ArchUnit.project_graph(fixture_root)
                     .include_external_dependencies
                     .focus_on('lib/rag_pipeline/services/**', 2)
                     .titled('RAG service dependencies')
    snapshot = report.snapshot

    expect(snapshot).to be_frozen
    expect(snapshot.title).to eq('RAG service dependencies')
    expect(snapshot.nodes.map(&:label)).to include(
      'lib/rag_pipeline/services/rag_service.rb',
      'lib/rag_pipeline/retrieval/embedder.rb'
    )
    expect(snapshot.summary).to have_attributes(
      node_count: snapshot.nodes.length,
      edge_count: snapshot.edges.length
    )

    rendered = %i[dot mermaid d2 csv json html].to_h do |format|
      [format, report.public_send("to_#{format}")]
    end
    expect(rendered.values).to all(be_a(String))
    expect(rendered.values).to all(satisfy { |output| !output.empty? })
    expect(JSON.parse(rendered.fetch(:json))).to include(
      'title' => snapshot.title,
      'summary' => include(
        'node_count' => snapshot.summary.node_count,
        'edge_count' => snapshot.summary.edge_count
      )
    )
    expect(rendered.fetch(:html)).to include('Generated by ArchUnitRuby')
    expect(rendered.fetch(:html)).not_to match(%r{https?://|<script}i)

    Dir.mktmpdir do |directory|
      output = File.join(directory, 'nested', 'rag-graph.html')
      expect(report.export_as_html(output)).to be_nil
      expect(File.binread(output)).to eq(rendered.fetch(:html))
    end
  end

  it 'collapses fixture files into evidence-preserving layer dependencies' do
    snapshot = ArchUnit.project_graph(fixture_root)
                       .collapse_by_pattern(%r{\Alib/rag_pipeline/([^/]+)/.*}, '\\1')
                       .snapshot

    expect(snapshot.nodes.map(&:label)).to include(*rag_layer_names)
    api_to_retrieval = snapshot.edges.find do |edge|
      edge.source == 'api' && edge.target == 'retrieval'
    end
    expect(api_to_retrieval).to have_attributes(count: 2, external: false)
    expect(api_to_retrieval.import_kinds).to eq([:require_relative])
  end

  it 'partitions real dependencies through the built-in edge mappers' do
    internal = ArchUnit::Common::Projection.project_edges(
      edges, ArchUnit::Common::Projection.per_internal_edge
    )
    external = ArchUnit::Common::Projection.project_edges(
      edges, ArchUnit::Common::Projection.per_external_edge
    )

    expect(internal).not_to be_empty
    expect(external).not_to be_empty
    expect(internal.flat_map(&:cumulated_edges)).to all(have_attributes(external: false))
    expect(external.flat_map(&:cumulated_edges)).to all(have_attributes(external: true))
  end

  it 'has no internal dependency cycles' do
    expect(ArchUnit::Common::Projection.project_internal_cycles(edges)).to be_empty
  end

  it 'builds reusable immutable file scopes in both moods' do
    base = ArchUnit.files(fixture_root)
                   .in_folder('lib/rag_pipeline/**')
                   .with_name('*.rb')

    expect(base.should).to have_attributes(project_locator: fixture_root.to_s, negated?: false)
    expect(base.should_not).to have_attributes(project_locator: fixture_root.to_s, negated?: true)
    expect(base.filters.length).to eq(2)
    expect(base).to be_frozen
  end

  it 'executes cycle, filename, and location rules against the fixture' do
    cycles = ArchUnit.files(fixture_root)
                     .in_folder('lib/rag_pipeline/**')
                     .should.have_no_cycles
    service_names = ArchUnit.files(fixture_root)
                            .in_folder('lib/rag_pipeline/services')
                            .should.have_name('*_service.rb')
    model_paths = ArchUnit.files(fixture_root)
                          .in_folder('lib/rag_pipeline/models')
                          .should.be_in_path('lib/rag_pipeline/models/**')

    expect(cycles.check).to be_empty
    expect(service_names.check).to be_empty
    expect(model_paths.check).to be_empty
  end

  it 'excludes generated or exceptional paths in the selector call' do
    rule = ArchUnit.files(fixture_root)
                   .in_folder(
                     'lib/rag_pipeline/**',
                     except: { in_folder: 'lib/rag_pipeline/shared' }
                   )
                   .should_not.have_name('leaky.rb')
    graph = ArchUnit.project_graph(fixture_root).focus_on(
      'lib/rag_pipeline/**', 0, except: { with_name: 'leaky.rb' }
    )

    expect(rule.check).to be_empty
    expect(graph.snapshot.nodes.map(&:label)).not_to include(
      'lib/rag_pipeline/shared/leaky.rb'
    )
  end

  it 'logs one real check to isolated memory and timestamped file sinks' do
    rule = ArchUnit.files(fixture_root)
                   .in_folder('lib/rag_pipeline/api')
                   .with_name('bad_shortcut.rb')
                   .should_not.depend_on_files
                   .in_folder('lib/rag_pipeline/retrieval')

    Dir.mktmpdir('rag-archunit-logs') do |directory|
      output = StringIO.new
      logging = ArchUnit::LoggingOptions.new(
        level: :debug, io: output, output_directory: File.join(directory, 'nested')
      )
      violations = rule.check(ArchUnit::CheckOptions.new(logging:))
      files = Dir[File.join(directory, 'nested', 'archunit-*.log')]

      expect(violations.length).to eq(2)
      expect(output.string).to include(
        'start check:', 'log progress:', 'log violation:', '(2 violations)'
      )
      expect(files.length).to eq(1)
      expect(File.read(files.fetch(0))).to include('end check:')
    end
  end

  it 'returns structured data for a known negated filename violation' do
    rule = ArchUnit.files(fixture_root)
                   .in_folder('lib/rag_pipeline/shared')
                   .should_not.have_name('leaky.rb')

    expect(rule.check).to contain_exactly(
      an_instance_of(ArchUnit::FilePatternViolation).and(
        have_attributes(
          projected_node: have_attributes(label: 'lib/rag_pipeline/shared/leaky.rb'),
          negated?: true
        )
      )
    )
  end

  it 'reports both deliberate internal dependency violations through fluent rules' do
    api_rule = ArchUnit.files(fixture_root)
                       .in_folder('lib/rag_pipeline/api')
                       .with_name('bad_shortcut.rb')
                       .should_not.depend_on_files
                       .in_folder('lib/rag_pipeline/retrieval')
    shared_rule = ArchUnit.files(fixture_root)
                          .in_folder('lib/rag_pipeline/shared')
                          .with_name('leaky.rb')
                          .should_not.depend_on_files
                          .in_folder('lib/rag_pipeline/services')

    expect(api_rule.check.map { |violation| violation.dependency.target_label }).to contain_exactly(
      'lib/rag_pipeline/retrieval/embedder.rb',
      'lib/rag_pipeline/retrieval/vector_store.rb'
    )
    expect(shared_rule.check.map { |violation| violation.dependency.target_label }).to eq(
      ['lib/rag_pipeline/services/rag_service.rb']
    )
    expect([*api_rule.check, *shared_rule.check]).to all(
      be_a(ArchUnit::FileDependencyViolation).and(be_negated)
    )
  end

  it 'enforces an external-module allowlist and blocklist against the fixture' do
    allowed = ArchUnit.files(fixture_root)
                      .in_folder('lib/rag_pipeline/retrieval')
                      .should.depend_on_external_modules
                      .matching('digest')
    forbidden = ArchUnit.files(fixture_root)
                        .in_folder('lib/rag_pipeline/retrieval')
                        .should_not.depend_on_external_modules
                        .matching('digest')

    expect(allowed.check).to be_empty
    expect(forbidden.check).to contain_exactly(
      an_instance_of(ArchUnit::ExternalModuleDependencyViolation).and(
        have_attributes(
          dependency: have_attributes(
            source_label: 'lib/rag_pipeline/retrieval/embedder.rb',
            target_label: 'digest'
          ),
          negated?: true
        )
      )
    )
  end

  it 'evaluates custom FileInfo predicates and guards empty selections' do
    frozen_source_rule = ArchUnit.files(fixture_root)
                                 .in_folder('lib/rag_pipeline/**')
                                 .should.adhere_to(
                                   lambda do |file|
                                     file.content.start_with?('# frozen_string_literal: true')
                                   end,
                                   'Ruby sources must freeze string literals'
                                 )
    custom_violation_rule = ArchUnit.files(fixture_root)
                                    .with_name('leaky.rb')
                                    .should.adhere_to(
                                      ->(file) { file.name == 'config' },
                                      'shared files must be configuration'
                                    )
    empty_rule = ArchUnit.files(fixture_root)
                         .in_folder('missing/**')
                         .should.adhere_to(->(_file) { true }, 'must exist')

    expect(frozen_source_rule.check).to be_empty
    expect(custom_violation_rule.check).to contain_exactly(
      an_instance_of(ArchUnit::CustomFileViolation).and(
        have_attributes(
          message: 'shared files must be configuration',
          file_info: have_attributes(
            path: 'lib/rag_pipeline/shared/leaky.rb',
            name: 'leaky',
            extension: '.rb',
            directory: 'lib/rag_pipeline/shared'
          )
        )
      )
    )
    expect(empty_rule.check).to contain_exactly(an_instance_of(ArchUnit::EmptyTestViolation))
    expect(
      empty_rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))
    ).to be_empty
  end

  it 'formats and asserts real architecture results without framework-specific setup' do
    passing = ArchUnit.files(fixture_root)
                      .in_folder('lib/rag_pipeline/**')
                      .should.have_no_cycles
    failing = ArchUnit.files(fixture_root)
                      .in_folder('lib/rag_pipeline/api')
                      .with_name('bad_shortcut.rb')
                      .should_not.depend_on_files
                      .in_folder('lib/rag_pipeline/retrieval')

    expect(ArchUnit.assert_passes(passing)).to be_nil
    expect(passing).to pass
    expect(failing).not_to pass
    expect { ArchUnit.assert_passes(failing) }.to raise_error(
      ArchUnit::AssertionFailure,
      /Found 2 architecture violations:.*File dependency violation/m
    )

    result = ArchUnit::ResultFactory.from_violations(failing.check, color: false)
    expect(result).to be_failed
    expect(result.message).to include(
      "File 'lib/rag_pipeline/api/bad_shortcut.rb' depends on forbidden file " \
      "'lib/rag_pipeline/retrieval/embedder.rb'.",
      "File 'lib/rag_pipeline/api/bad_shortcut.rb' depends on forbidden file " \
      "'lib/rag_pipeline/retrieval/vector_store.rb'."
    )
  end
end
