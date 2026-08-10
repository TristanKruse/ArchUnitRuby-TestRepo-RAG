# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'ArchUnitRuby source metrics' do
  let(:fixture_root) { File.expand_path('..', __dir__).tr('\\', '/') }
  let(:service_scope) do
    ArchUnit.metrics(fixture_root)
            .in_path('lib/rag_pipeline/services/rag_service.rb')
            .for_classes_matching('RagPipeline::Services::RagService')
  end

  it 'extracts real class and file counts from the RAG service' do
    analysis = service_scope.analyze
    method_count = service_scope.count.method_count.measure.fetch(0)
    field_count = service_scope.count.field_count.measure.fetch(0)
    file_class_count = service_scope.count.classes.measure.fetch(0)

    expect(analysis.files.map(&:path)).to eq(['lib/rag_pipeline/services/rag_service.rb'])
    expect(analysis.classes.map(&:name)).to eq(['RagPipeline::Services::RagService'])
    expect(method_count).to have_attributes(value: 3, metric_name: :method_count)
    expect(field_count).to have_attributes(value: 3, metric_name: :field_count)
    expect(file_class_count).to have_attributes(value: 1, metric_name: :classes)
  end

  it 'calculates all eight LCOM variants over the extracted method-field graph' do
    measurements = ArchUnit::LCOMMetrics::CALCULATIONS.each_key.to_h do |name|
      [name, service_scope.lcom.public_send(name).measure.fetch(0).value]
    end

    expect(measurements.keys).to eq(
      %i[lcom96a lcom96b lcom1 lcom2 lcom3 lcom4 lcom5 lcom_star]
    )
    expect(measurements).to include(lcom1: 0, lcom4: 1)
    expect(measurements.values_at(:lcom96a, :lcom3, :lcom5, :lcom_star))
      .to all(be_within(0.000_001).of(1.0 / 3.0))
    expect(measurements.values_at(:lcom96b, :lcom2))
      .to all(be_within(0.000_001).of(2.0 / 9.0))
  end

  it 'derives distance and coupling values from the real RAG dependency graph' do
    measurements = ArchUnit::DistanceMetrics::CALCULATIONS.each_key.to_h do |name|
      [name, service_scope.distance.public_send(name).measure.fetch(0).value]
    end

    expect(measurements).to include(
      abstractness: 0.0,
      instability: 0.625,
      distance_from_main_sequence: 0.375,
      coupling_factor: 0.25
    )
    expect(measurements[:normalized_distance]).to be_between(0.0, 0.375)
    expect(service_scope.distance.not_in_zone_of_pain.check).to be_empty
    expect(service_scope.distance.not_in_zone_of_uselessness.check).to be_empty
  end

  it 'measures and asserts a custom metric with full RAG ClassInfo evidence' do
    custom = service_scope.custom_metric(
      'member count', 'RAG services should remain focused',
      ->(class_info) { class_info.methods.length + class_info.fields.length }
    )
    measurement = custom.measure.fetch(0)
    passing_rule = custom.should_satisfy(lambda do |value, class_info|
      value <= 6 && class_info.name.end_with?('RagService')
    end)

    expect(measurement).to have_attributes(metric_name: 'member count', value: 6)
    expect(passing_rule.check).to be_empty
  end

  it 'enforces exact count, cohesion, distance, and custom metric thresholds' do
    custom = service_scope.custom_metric(
      'member count', 'RAG services should remain focused',
      ->(class_info) { class_info.methods.length + class_info.fields.length }
    )
    rules = [
      service_scope.count.method_count.should_be_below_or_equal(3),
      service_scope.lcom.lcom4.should_be(1),
      service_scope.distance.instability.should_be_above(0.5),
      custom.should_be_above_or_equal(6),
      service_scope.count.field_count.should_satisfy(
        ->(value, class_info) { value == 3 && class_info.name.end_with?('RagService') }
      )
    ]

    expect(rules).to all(be_a(ArchUnit::Checkable))
    expect(rules.flat_map(&:check)).to be_empty
    expect(service_scope.count.method_count.should_be_below(3).check).to contain_exactly(
      have_attributes(
        metric_name: :method_count, value: 3, threshold: 3, comparison: :below
      )
    )
  end

  it 'exports real scoped metrics and arbitrary summaries as offline HTML' do
    Dir.mktmpdir do |root|
      options = ArchUnit::MetricsExportOptions.new(
        title: 'RAG Architecture Metrics', include_timestamp: false
      )
      reports = {
        count: service_scope.count,
        lcom: service_scope.lcom,
        distance: service_scope.distance
      }

      reports.each do |name, builder|
        output = File.join(root, name.to_s)
        expect(builder.export_as_html(output, options)).to be_nil
        identifier = if name == :distance
                       'lib/rag_pipeline/services/rag_service.rb'
                     else
                       'RagPipeline::Services::RagService'
                     end
        expect(File.read("#{output}.html")).to include(
          'RAG Architecture Metrics', identifier
        )
      end

      summary = ArchUnit::MetricsExporter.export_as_html(
        { 'RAG service member count' => 6 }, options
      )
      expect(summary).to include('RAG service member count', '>6<')
      expect(summary).not_to include('Generated:')
    end
  end
end
