# This file is used by Rack-based servers to start the application.

require_relative "config/environment"
require "grack/app"
require "grack/git_adapter"
require "lore/git_http_auth_middleware"

map "/git" do
  use Lore::GitHttpAuthMiddleware
  run Grack::App.new(
    root: Lore::Application.config.x.lore.repo_root,
    allow_pull: true,
    allow_push: true,
    git_adapter_factory: -> { Grack::GitAdapter.new }
  )
end

run Rails.application
Rails.application.load_server
