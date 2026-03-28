module Lore
  class RepoIndexer
    class << self
      def refresh!(repo)
        repo.update!(embedding: Lore::Embeddings.embed(repo.embedding_input))
      end
    end
  end
end
