# frozen_string_literal: true

require_relative '../shared/config'

module RagPipeline
  module Models
    Chunk = Data.define(:text, :source)

    Document = Data.define(:id, :content, :source) do
      def chunks
        content.scan(/.{1,#{Shared::Config::CHUNK_SIZE}}/m).map do |text|
          Chunk.new(text:, source:)
        end
      end
    end
  end
end
