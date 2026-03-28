module Api
  class UsersController < ApplicationController
    skip_forgery_protection
    before_action :require_api_user!, only: :me

    def create
      user = User.new(user_params)

      if user.save
        render json: {
          user: {
            username: user.username,
            created_at: user.created_at.iso8601
          },
          pat: user.plain_pat
        }, status: :created
      else
        render json: { errors: user.errors.to_hash(true) }, status: error_status_for(user)
      end
    end

    def repos
      user = User.find_by(username: params[:username])
      return head :not_found unless user

      repos = user.owned_repos
        .includes(:stars)
        .order(Arel.sql("CASE WHEN repos.last_pushed_at IS NULL THEN 1 ELSE 0 END"), last_pushed_at: :desc, created_at: :desc)

      render json: {
        repos: repos.map do |repo|
          {
            owner: user.username,
            name: repo.name,
            description: repo.description,
            tags: repo.tags,
            clone_url: repo.clone_url,
            stars: repo.stars_count,
            last_pushed_at: repo.last_pushed_at&.iso8601
          }
        end
      }
    end

    def me
      render json: {
        user: {
          username: current_api_user.username,
          created_at: current_api_user.created_at.iso8601,
          starred_repos_count: current_api_user.stars.count
        }
      }
    end

    private

    def user_params
      params.permit(:username)
    end

    def error_status_for(user)
      user.errors.of_kind?(:username, :taken) ? :conflict : :unprocessable_entity
    end
  end
end
