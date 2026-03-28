module Lore
  class RepoSearch
    Result = Struct.new(:repo, :score, keyword_init: true)

    class << self
      def search(query)
        query_embedding = Lore::Embeddings.embed(query)

        Repo.includes(:owner, :stars).filter_map do |repo|
          repo_embedding = repo.embedding
          next if repo_embedding.blank?

          Result.new(repo: repo, score: cosine_similarity(query_embedding, repo_embedding))
        end.sort_by { |result| -result.score }.first(10)
      end

      private

      def cosine_similarity(left, right)
        left_vector = left.map(&:to_f)
        right_vector = right.map(&:to_f)
        return 0.0 if left_vector.size != right_vector.size || left_vector.empty?

        dot_product = left_vector.zip(right_vector).sum { |a, b| a * b }
        left_norm = Math.sqrt(left_vector.sum { |value| value * value })
        right_norm = Math.sqrt(right_vector.sum { |value| value * value })
        return 0.0 if left_norm.zero? || right_norm.zero?

        dot_product / (left_norm * right_norm)
      end
    end
  end
end
