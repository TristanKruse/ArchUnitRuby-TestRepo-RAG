# frozen_string_literal: true

# Intentional violation: API bypasses the service layer and reaches into retrieval.
require_relative '../retrieval/embedder'
require_relative '../retrieval/vector_store'

module RagPipeline
  module Api
    # Deliberately bypasses the service layer for architecture-test demonstrations.
    class BadShortcut
      def call(text)
        embedding = Retrieval::Embedder.new.embed(text)
        Retrieval::VectorStore.new.search(embedding)
      end
    end
  end
end
