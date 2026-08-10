# frozen_string_literal: true

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
end
