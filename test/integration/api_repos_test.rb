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
    assert File.executable?(File.join(repo.path, "hooks", "post-receive"))
    assert_equal "refs/heads/main", `git --git-dir="#{repo.path}" symbolic-ref HEAD`.strip
  end

  test "requires bearer authentication" do
    post api_repos_path,
      params: { name: "slack-notify", description: "Posts a message to a Slack webhook" },
      as: :json

    assert_response :unauthorized
  end

  test "returns public repo metadata" do
    repo = Repo.create!(
      owner: @user,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack", "notifications"],
      path: File.join(@repo_root, "hazel", "slack-notify.git"),
      last_pushed_at: Time.zone.parse("2026-03-28 16:20:00 UTC")
    )

    get api_repo_path(owner: @user.username, name: repo.name)

    assert_response :success

    payload = response.parsed_body.fetch("repo")
    assert_equal "hazel", payload.fetch("owner")
    assert_equal "slack-notify", payload.fetch("name")
    assert_equal repo.clone_url, payload.fetch("clone_url")
    assert_equal repo.web_url, payload.fetch("web_url")
    assert_equal 0, payload.fetch("stars")
    assert_equal "2026-03-28T16:20:00Z", payload.fetch("last_pushed_at")
  end

  test "returns not found for an unknown repo" do
    get api_repo_path(owner: @user.username, name: "missing")

    assert_response :not_found
  end

  test "stars a repo idempotently for the authenticated user" do
    repo = Repo.create!(
      owner: @user,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack"],
      path: File.join(@repo_root, "hazel", "slack-notify.git")
    )
    stargazer = User.create!(username: "agent")

    post api_star_repo_path(owner: @user.username, name: repo.name), headers: { "Authorization" => "Bearer #{stargazer.plain_pat}" }

    assert_response :success
    assert_equal 1, response.parsed_body.dig("repo", "stars")
    assert_equal true, response.parsed_body.fetch("starred")

    post api_star_repo_path(owner: @user.username, name: repo.name), headers: { "Authorization" => "Bearer #{stargazer.plain_pat}" }

    assert_response :success
    assert_equal 1, response.parsed_body.dig("repo", "stars")
    assert_equal 1, repo.stars.where(user: stargazer).count
  end

  test "unstars a repo idempotently for the authenticated user" do
    repo = Repo.create!(
      owner: @user,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack"],
      path: File.join(@repo_root, "hazel", "slack-notify.git")
    )
    stargazer = User.create!(username: "agent")
    Star.create!(user: stargazer, repo: repo)

    delete api_star_repo_path(owner: @user.username, name: repo.name), headers: { "Authorization" => "Bearer #{stargazer.plain_pat}" }

    assert_response :success
    assert_equal 0, response.parsed_body.dig("repo", "stars")
    assert_equal false, response.parsed_body.fetch("starred")

    delete api_star_repo_path(owner: @user.username, name: repo.name), headers: { "Authorization" => "Bearer #{stargazer.plain_pat}" }

    assert_response :success
    assert_equal 0, response.parsed_body.dig("repo", "stars")
  end

  test "requires authentication to star a repo" do
    repo = Repo.create!(
      owner: @user,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack"],
      path: File.join(@repo_root, "hazel", "slack-notify.git")
    )

    post api_star_repo_path(owner: @user.username, name: repo.name)

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
