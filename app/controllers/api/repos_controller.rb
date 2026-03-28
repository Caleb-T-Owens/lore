module Api
  class ReposController < ApplicationController
    skip_forgery_protection
    before_action :require_api_user!, only: %i[create star unstar]
    before_action :set_repo, only: %i[show star unstar]

    def create
      repo = Lore::RepoProvisioner.create(owner: current_api_user, params: repo_params.to_h.symbolize_keys)

      if repo.persisted?
        render json: { repo: serialize_repo(repo) }, status: :created
      else
        render json: { errors: repo.errors.to_hash(true) }, status: error_status_for(repo)
      end
    end

    def show
      render json: { repo: serialize_repo(repo) }
    end

    def star
      Star.find_or_create_by!(user: current_api_user, repo: repo)

      render json: { repo: serialize_star_payload(repo), starred: true }
    end

    def unstar
      repo.stars.where(user: current_api_user).delete_all

      render json: { repo: serialize_star_payload(repo), starred: false }
    end

    private

    attr_reader :repo

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

    def serialize_star_payload(repo)
      {
        owner: repo.owner.username,
        name: repo.name,
        stars: repo.stars.reload.count
      }
    end

    def set_repo
      @repo = Repo.includes(:owner, :stars).joins(:owner).find_by(users: { username: params[:owner] }, name: params[:name])
      return head :not_found unless @repo
    end
  end
end
