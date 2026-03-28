require "test_helper"

class ApiUsersTest < ActionDispatch::IntegrationTest
  test "creates a user and returns the plaintext pat once" do
    post api_users_path, params: { username: "Hazel" }, as: :json

    assert_response :created

    payload = response.parsed_body
    created_user = User.find_by!(username: "hazel")

    assert_equal "hazel", payload.dig("user", "username")
    assert_equal created_user.created_at.iso8601, payload.dig("user", "created_at")
    assert_match(/^lore_pat_/, payload.fetch("pat"))
    assert_equal User.digest_pat(payload.fetch("pat")), created_user.pat_digest
  end

  test "returns conflict for a duplicate username" do
    User.create!(username: "hazel")

    post api_users_path, params: { username: "hazel" }, as: :json

    assert_response :conflict
    assert_includes response.parsed_body.fetch("errors").fetch("username"), "Username has already been taken"
  end

  test "returns unprocessable entity for an invalid username" do
    post api_users_path, params: { username: "9hazel" }, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("errors").fetch("username"), "Username is invalid"
  end

  test "lists a user's repos ordered by recent pushes" do
    user = User.create!(username: "hazel")
    Repo.create!(
      owner: user,
      name: "older-push",
      description: "Older repo",
      tags: ["one"],
      path: "/tmp/older-push.git",
      last_pushed_at: Time.zone.parse("2026-03-27 10:00:00 UTC")
    )
    Repo.create!(
      owner: user,
      name: "newer-push",
      description: "Newer repo",
      tags: ["two"],
      path: "/tmp/newer-push.git",
      last_pushed_at: Time.zone.parse("2026-03-28 10:00:00 UTC")
    )
    Repo.create!(
      owner: user,
      name: "never-pushed",
      description: "No pushes yet",
      tags: ["three"],
      path: "/tmp/never-pushed.git"
    )

    get api_user_repos_path(username: user.username)

    assert_response :success
    assert_equal ["newer-push", "older-push", "never-pushed"], response.parsed_body.fetch("repos").map { |repo| repo.fetch("name") }
    assert_equal ["hazel", "hazel", "hazel"], response.parsed_body.fetch("repos").map { |repo| repo.fetch("owner") }
  end

  test "returns not found when listing repos for an unknown user" do
    get api_user_repos_path(username: "missing")

    assert_response :not_found
  end
end
