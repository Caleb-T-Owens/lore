class OwnersController < ApplicationController
  def show
    @owner = User.find_by(username: params[:owner])
    return head :not_found unless @owner

    @repos = @owner.owned_repos
      .includes(:stars)
      .order(Arel.sql("CASE WHEN repos.last_pushed_at IS NULL THEN 1 ELSE 0 END"), last_pushed_at: :desc, created_at: :desc)
  end
end
