require "json"
require "net/http"
require "digest"

module Lore
  module Embeddings
    class Error < StandardError; end

    ENDPOINT = URI("https://api.openai.com/v1/embeddings")
    MODEL = "text-embedding-3-small"
    TEST_KEYWORD_GROUPS = [
      %w[slack webhook message messages notify notification notifications emoji post posts],
      %w[email smtp sendgrid mail inbox],
      %w[http https url fetch request response web],
      %w[json parse parser parsing key path keys data],
      %w[git commit commits history summary summarize summarise repo repository branch],
      %w[agent tool skill script automation],
      %w[deploy deployment finished release],
      %w[text stdout output body]
    ].freeze
    TEST_HASH_DIMENSIONS = 8

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
      tokens = normalized_tokens(text)
      keyword_features = TEST_KEYWORD_GROUPS.map do |group|
        tokens.count { |token| group.include?(token) }.to_f
      end

      hash_features = Array.new(TEST_HASH_DIMENSIONS, 0.0)
      tokens.each do |token|
        bucket = Digest::SHA256.hexdigest(token).to_i(16) % TEST_HASH_DIMENSIONS
        hash_features[bucket] += 1.0
      end

      keyword_features + hash_features
    end

    def normalized_tokens(text)
      text.to_s.downcase.scan(/[a-z0-9]+/).flat_map do |token|
        stripped = token.end_with?("s") && token.length > 3 ? token.delete_suffix("s") : token
        stripped == token ? [token] : [token, stripped]
      end
    end
  end
end
