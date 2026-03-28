require "json"
require "net/http"
require "digest"

module Lore
  module Embeddings
    class Error < StandardError; end

    ENDPOINT = URI("https://api.openai.com/v1/embeddings")
    MODEL = "text-embedding-3-small"

    module_function

    def embed(text)
      api_key = ENV["OPENAI_API_KEY"].presence
      return deterministic_test_embedding(text) if api_key.blank? && Rails.env.test?
      raise Error, "OPENAI_API_KEY is not configured" if api_key.blank?

      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(model: MODEL, input: text)

      response = Net::HTTP.start(ENDPOINT.hostname, ENDPOINT.port, use_ssl: true) do |http|
        http.request(request)
      end

      raise Error, "Embedding request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig("data", 0, "embedding") || raise(Error, "Embedding response was missing data")
    end

    def deterministic_test_embedding(text)
      Digest::SHA256.digest(text.to_s).bytes.each_slice(4).map do |chunk|
        integer = chunk.reduce(0) { |value, byte| (value << 8) + byte }
        (integer / 2_147_483_647.0).round(6)
      end
    end
  end
end
