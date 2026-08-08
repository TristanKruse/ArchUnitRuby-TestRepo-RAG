# frozen_string_literal: true

require_relative '../llm/client'
require_relative '../models/document'
require_relative '../models/query'
require_relative '../retrieval/embedder'
require_relative '../retrieval/vector_store'

module RagPipeline
  module Services
    # Coordinates document ingestion, retrieval, and response generation.
    class RagService
      def initialize(
        embedder: Retrieval::Embedder.new,
        store: Retrieval::VectorStore.new,
        client: Llm::Client.new
      )
        @embedder = embedder
        @store = store
        @client = client
      end

      def ingest(document)
        @store.insert(document.chunks)
      end

      def query(query)
        sources = @store.search(@embedder.embed(query.text), top_k: query.top_k)
        @client.generate(query, sources)
      end
    end
  end
end
