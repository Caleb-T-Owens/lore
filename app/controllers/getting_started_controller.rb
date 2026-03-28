class GettingStartedController < ApplicationController
  def show
    response.headers["Content-Type"] = "text/markdown; charset=utf-8"
    render layout: false
  end
end
