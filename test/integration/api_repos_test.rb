require "test_helper"
require "fileutils"

class ApiReposTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "hazel")
    @repo_root = Rails.application.config.x.lore.repo_root
  end

  teardown do
    FileUtils.rm_rf(File.join(@repo_root, @user.username))
  end

  test "creates a bare repo for the authenticated user" do
    post api_repos_path,
      params: {
        name: "Slack-Notify",
        description: "Posts a message to a Slack webhook",
        tags: ["slack", "notifications", "SLACK"]
      },
      headers: { "Authorization" => "Bearer #{@user.plain_pat}" },
      as: :json

    assert_response :created

    payload = response.parsed_body.fetch("repo")
    repo = Repo.find_by!(owner: @user, name: "slack-notify")

    assert_equal "hazel", payload.fetch("owner")
    assert_equal "slack-notify", payload.fetch("name")
    assert_equal ["slack", "notifications"], payload.fetch("tags")
    assert_equal repo.clone_url, payload.fetch("clone_url")
    assert_equal repo.web_url, payload.fetch("web_url")
    assert_equal "main", payload.fetch("default_branch")
    assert_equal 0, payload.fetch("stars")
    assert_nil payload.fetch("last_pushed_at")
    assert_equal repo.created_at.iso8601, payload.fetch("created_at")
    assert_equal File.join(@repo_root, "hazel", "slack-notify.git"), repo.path
    assert Dir.exist?(repo.path)
    assert_equal "refs/heads/main", `git --git-dir="#{repo.path}" symbolic-ref HEAD`.strip
  end

  test "requires bearer authentication" do
    post api_repos_path,
      params: { name: "slack-notify", description: "Posts a message to a Slack webhook" },
      as: :json

    assert_response :unauthorized
  end

  test "returns conflict for a duplicate repo name under the same owner" do
    Repo.create!(
      owner: @user,
      name: "slack-notify",
      description: "Existing repo",
      path: File.join(@repo_root, "hazel", "slack-notify.git")
    )

    post api_repos_path,
      params: { name: "slack-notify", description: "Another repo" },
      headers: { "Authorization" => "Bearer #{@user.plain_pat}" },
      as: :json

    assert_response :conflict
    assert_includes response.parsed_body.fetch("errors").fetch("name"), "Name has already been taken"
  end

  test "returns unprocessable entity for invalid repo attributes" do
    post api_repos_path,
      params: { name: "9bad", description: "" },
      headers: { "Authorization" => "Bearer #{@user.plain_pat}" },
      as: :json

    assert_response :unprocessable_entity

    errors = response.parsed_body.fetch("errors")
    assert_includes errors.fetch("name"), "Name is invalid"
    assert_includes errors.fetch("description"), "Description can't be blank"
  end
end
