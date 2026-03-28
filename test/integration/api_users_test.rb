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
end
