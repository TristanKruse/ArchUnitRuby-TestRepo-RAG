# frozen_string_literal: true

# This compatibility dependency is intentionally omitted from the architecture graph.
require_relative '../services/rag_service' # archunit: ignore ../services/rag_service

module RagPipeline
  module Shared
    # Demonstrates a known compatibility import suppressed through an ArchUnitRuby directive.
    class LegacyAdapter
      def service
        Services::RagService.new
      end
    end
  end
end
