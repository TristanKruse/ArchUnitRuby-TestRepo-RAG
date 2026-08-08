# frozen_string_literal: true

require 'rag_pipeline'

RSpec.describe RagPipeline::Services::RagService do
  it 'runs the mock RAG flow end to end' do
    service = described_class.new
    document = RagPipeline::Models::Document.new(
      id: 'architecture',
      content: 'Architecture tests keep dependency rules executable.',
      source: 'fixture'
    )

    expect(service.ingest(document)).to eq(1)

    response = service.query(RagPipeline::Models::Query.new(text: 'Why test architecture?'))
    expect(response.answer).to include('Why test architecture?')
    expect(response.sources.map(&:source)).to eq(['fixture'])
  end
end
