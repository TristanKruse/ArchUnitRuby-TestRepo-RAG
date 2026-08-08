# frozen_string_literal: true

module RagPipeline
  module Models
    Query = Data.define(:text, :top_k) do
      def initialize(text:, top_k: 5)
        super
      end
    end

    RetrievalResult = Data.define(:text, :score, :source)
    Response = Data.define(:answer, :sources, :model)
  end
end
