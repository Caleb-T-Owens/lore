module Lore
  class RepoProvisioner
    class Error < StandardError; end

    class << self
      def create(owner:, params:)
        repo = owner.owned_repos.new(
          name: params[:name],
          description: params[:description],
          tags: params[:tags],
          path: repo_path(owner.username, params[:name])
        )

        Repo.transaction do
          repo.save!
          initialize_bare_repo!(repo.path)
          Lore::RepoHooks.install!(repo.path)
        end

        repo
      rescue ActiveRecord::RecordInvalid
        repo
      rescue Error, Errno::ENOENT, SystemCallError => error
        cleanup_repo_path(repo&.path)
        repo ||= owner.owned_repos.new(name: params[:name], description: params[:description], tags: params[:tags])
        repo.errors.add(:base, error.message)
        repo
      end

      private

      def repo_path(owner_name, repo_name)
        File.join(
          Lore::Application.config.x.lore.repo_root,
          normalize_slug(owner_name),
          "#{normalize_slug(repo_name)}.git"
        )
      end

      def normalize_slug(value)
        value.to_s.strip.downcase
      end

      def initialize_bare_repo!(path)
        raise Error, "repo path already exists" if File.exist?(path)

        FileUtils.mkdir_p(File.dirname(path))
        system("git", "init", "--bare", "--initial-branch=main", path, exception: true)
        system("git", "--git-dir", path, "symbolic-ref", "HEAD", "refs/heads/main", exception: true)
      end

      def cleanup_repo_path(path)
        return if path.blank?

        FileUtils.rm_rf(path)
      end
    end
  end
end
