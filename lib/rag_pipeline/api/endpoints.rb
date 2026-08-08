# frozen_string_literal: true

require_relative '../models/document'
require_relative '../models/query'
require_relative '../services/rag_service'

module RagPipeline
  module Api
    # Small API facade over the RAG application service.
    class Endpoints
      def initialize(service: Services::RagService.new)
        @service = service
      end

      def ingest(id:, content:, source:)
        document = Models::Document.new(id:, content:, source:)
        @service.ingest(document)
      end

      def ask(question:, top_k: 5)
        @service.query(Models::Query.new(text: question, top_k:))
      end
    end
  end
end
