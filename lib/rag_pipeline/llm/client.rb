# frozen_string_literal: true

require_relative '../models/query'
require_relative '../shared/config'

module RagPipeline
  module Llm
    # Deterministic stand-in for an external language-model client.
    class Client
      def generate(query, sources)
        Models::Response.new(
          answer: "Mock answer for: #{query.text}",
          sources:,
          model: Shared::Config::LLM_MODEL
        )
      end
    end
  end
end
