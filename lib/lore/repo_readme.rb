require "open3"

module Lore
  class RepoReadme
    CANDIDATES = %w[README.md README README.txt readme.md].freeze

    class << self
      def read(repo)
        CANDIDATES.each do |candidate|
          content = read_candidate(repo.path, candidate)
          return content if content.present?
        end

        nil
      end

      private

      def read_candidate(repo_path, candidate)
        stdout, _stderr, status = Open3.capture3(
          "git", "--git-dir", repo_path, "show", "refs/heads/main:#{candidate}"
        )
        return unless status.success?

        stdout.presence
      end
    end
  end
end
