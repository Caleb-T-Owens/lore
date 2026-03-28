require "test_helper"

module Lore
  class RepoSearchTest < ActiveSupport::TestCase
    test "ranks repos by cosine similarity" do
      owner = User.create!(username: "hazel")
      best = Repo.create!(owner: owner, name: "best-match", description: "Best", tags: ["one"], path: "/tmp/best-match.git", embedding: [1.0, 0.0])
      _other = Repo.create!(owner: owner, name: "other-match", description: "Other", tags: ["two"], path: "/tmp/other-match.git", embedding: [0.0, 1.0])
      Repo.create!(owner: owner, name: "no-embedding", description: "Missing", tags: ["three"], path: "/tmp/no-embedding.git")

      with_stubbed_embedding([1.0, 0.0]) do
        results = RepoSearch.search("slack notification")

        assert_equal [best.name, "other-match"], results.map { |result| result.repo.name }
        assert_in_delta 1.0, results.first.score, 0.0001
      end
    end

    private

    def with_stubbed_embedding(result)
      original = Lore::Embeddings.method(:embed)
      Lore::Embeddings.singleton_class.define_method(:embed) { |_query| result }
      yield
    ensure
      Lore::Embeddings.singleton_class.define_method(:embed, original)
    end
  end
end
