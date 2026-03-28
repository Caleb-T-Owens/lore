module Api
  class UsersController < ApplicationController
    skip_forgery_protection

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

    private

    def user_params
      params.permit(:username)
    end

    def error_status_for(user)
      user.errors.of_kind?(:username, :taken) ? :conflict : :unprocessable_entity
    end
  end
end
