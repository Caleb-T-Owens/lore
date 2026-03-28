class HomeController < ApplicationController
  def index
    @featured_repos = Repo.includes(:owner, :stars)
      .order(Arel.sql("CASE WHEN repos.last_pushed_at IS NULL THEN 1 ELSE 0 END"), last_pushed_at: :desc, created_at: :desc)
      .limit(6)

    @repo_count = Repo.count
    @owner_count = User.count
    @star_count = Star.count
  end
end
