# frozen_string_literal: true

require_relative '../models/query'

module RagPipeline
  module Retrieval
    # Minimal in-memory vector store used by the fixture application.
    class VectorStore
      def initialize
        @chunks = []
      end

      def insert(chunks)
        @chunks.concat(chunks)
        chunks.length
      end

      def search(_embedding, top_k: 5)
        @chunks.first(top_k).map.with_index do |chunk, index|
          Models::RetrievalResult.new(
            text: chunk.text,
            score: 1.0 - (index * 0.1),
            source: chunk.source
          )
        end
      end
    end
  end
end
