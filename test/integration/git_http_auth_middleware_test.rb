require "test_helper"
require "base64"
require "fileutils"
require "rack/mock"
require "securerandom"

class GitHttpAuthMiddlewareTest < ActiveSupport::TestCase
  setup do
    @repo_root = Rails.application.config.x.lore.repo_root
    suffix = SecureRandom.hex(4)
    @owner = User.create!(username: "owner-#{suffix}")
    @contributor = User.create!(username: "agent-#{suffix}")
    @repo = Lore::RepoProvisioner.create(
      owner: @owner,
      params: {
        name: "tool",
        description: "Demo tool",
        tags: [ "demo" ]
      }
    )
    @app = Rack::Builder.parse_file(Rails.root.join("config.ru").to_s)
  end

  teardown do
    FileUtils.rm_rf(File.join(@repo_root, @owner.username))
  end

  test "allows anonymous upload-pack discovery" do
    response = Rack::MockRequest.new(@app).get(
      "/git/#{@owner.username}/tool.git/info/refs?service=git-upload-pack"
    )

    assert_equal 200, response.status
    assert_includes response["content-type"], "application/x-git-upload-pack-advertisement"
    assert_includes response.body, "# service=git-upload-pack"
  end

  test "requires basic auth for receive-pack discovery" do
    response = Rack::MockRequest.new(@app).get(
      "/git/#{@owner.username}/tool.git/info/refs?service=git-receive-pack"
    )

    assert_equal 401, response.status
    assert_equal 'Basic realm="Lore Git"', response["WWW-Authenticate"]
  end

  test "allows any authenticated user to negotiate receive-pack" do
    response = Rack::MockRequest.new(@app).get(
      "/git/#{@owner.username}/tool.git/info/refs?service=git-receive-pack",
      "HTTP_AUTHORIZATION" => basic_auth_for(@contributor)
    )

    assert_equal 200, response.status
    assert_includes response["content-type"], "application/x-git-receive-pack-advertisement"
    assert_includes response.body, "# service=git-receive-pack"
  end

  test "returns not found for repos missing from Lore metadata" do
    response = Rack::MockRequest.new(@app).get(
      "/git/#{@owner.username}/missing.git/info/refs?service=git-upload-pack"
    )

    assert_equal 404, response.status
  end

  private

  def basic_auth_for(user)
    credentials = Base64.strict_encode64("#{user.username}:#{user.plain_pat}")
    "Basic #{credentials}"
  end
end
