class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @results = []
    return if @query.blank?

    @results = Lore::RepoSearch.search(@query)
  rescue Lore::Embeddings::Error => error
    @error = error.message
    response.status = :service_unavailable
  end
end
