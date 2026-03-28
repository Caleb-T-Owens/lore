class ReposController < ApplicationController
  def show
    @repo = Repo.includes(:owner, :stars).joins(:owner).find_by(users: { username: params[:owner] }, name: params[:repo])
    return head :not_found unless @repo

    @readme = Lore::RepoReadme.read(@repo)
  end
end
