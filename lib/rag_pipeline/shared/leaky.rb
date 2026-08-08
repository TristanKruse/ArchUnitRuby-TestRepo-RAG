# frozen_string_literal: true

# Intentional violation: the lowest layer reaches upward into services.
require_relative '../services/rag_service'

module RagPipeline
  module Shared
    # Deliberately reaches upward into services for architecture-test demonstrations.
    class Leaky
      def service
        Services::RagService.new
      end
    end
  end
end
