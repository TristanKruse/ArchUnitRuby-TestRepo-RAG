# frozen_string_literal: true

require 'digest'
require_relative '../shared/config'

module RagPipeline
  module Retrieval
    # Produces deterministic byte-vector embeddings for fixture text.
    class Embedder
      def embed(text)
        Digest::SHA256.digest(text).bytes.first(Shared::Config::EMBEDDING_DIMENSION)
      end
    end
  end
end
