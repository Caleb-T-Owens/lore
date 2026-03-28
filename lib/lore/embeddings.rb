require "json"
require "net/http"

module Lore
  module Embeddings
    class Error < StandardError; end

    ENDPOINT = URI("https://api.openai.com/v1/embeddings")
    MODEL = "text-embedding-3-small"

    module_function

    def embed(text)
      api_key = ENV["OPENAI_API_KEY"].presence
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
  end
end
