module Api
  class ReposController < ApplicationController
    skip_forgery_protection
    before_action :require_api_user!

    def create
      repo = Lore::RepoProvisioner.create(owner: current_api_user, params: repo_params.to_h.symbolize_keys)

      if repo.persisted?
        render json: { repo: serialize_repo(repo) }, status: :created
      else
        render json: { errors: repo.errors.to_hash(true) }, status: error_status_for(repo)
      end
    end

    private

    def repo_params
      params.permit(:name, :description, tags: [])
    end

    def error_status_for(repo)
      repo.errors.of_kind?(:name, :taken) ? :conflict : :unprocessable_entity
    end

    def serialize_repo(repo)
      {
        owner: repo.owner.username,
        name: repo.name,
        description: repo.description,
        tags: repo.tags,
        clone_url: repo.clone_url,
        web_url: repo.web_url,
        default_branch: "main",
        stars: repo.stars_count,
        created_at: repo.created_at.iso8601,
        last_pushed_at: repo.last_pushed_at&.iso8601
      }
    end
  end
end
