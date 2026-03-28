module Lore
  class GitHttpAuthMiddleware
    WRITE_SERVICE = "git-receive-pack"
    READ_SERVICE = "git-upload-pack"
    REPO_PATH_FORMAT = %r{\A/(?<owner>[a-z0-9-]+)/(?<name>[a-z0-9-]+)\.git(?:/|\z)}

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      repo = resolve_repo(request.path_info)
      return not_found unless repo

      env["lore.repo"] = repo

      if write_request?(request)
        user = Lore::Auth.user_from_basic_header(request.get_header("HTTP_AUTHORIZATION"))
        return unauthorized unless user

        env["lore.git_user"] = user
      end

      @app.call(env)
    end

    private

    def resolve_repo(path_info)
      match = path_info.to_s.match(REPO_PATH_FORMAT)
      return unless match

      Repo.joins(:owner).find_by(users: { username: match[:owner] }, name: match[:name])
    end

    def write_request?(request)
      service = request.params["service"]

      service == WRITE_SERVICE || request.path_info.to_s.end_with?("/#{WRITE_SERVICE}")
    end

    def unauthorized
      [
        401,
        {
          "Content-Type" => "text/plain; charset=utf-8",
          "WWW-Authenticate" => 'Basic realm="Lore Git"'
        },
        [ "Authentication required\n" ]
      ]
    end

    def not_found
      [ 404, { "Content-Type" => "text/plain; charset=utf-8" }, [ "Not found\n" ] ]
    end
  end
end
