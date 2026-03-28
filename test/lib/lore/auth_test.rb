require "test_helper"

module Lore
  class AuthTest < ActiveSupport::TestCase
    test "resolves a user from a bearer token header" do
      user = User.create!(username: "hazel")

      resolved_user = Auth.user_from_bearer_header("Bearer #{user.plain_pat}")

      assert_equal user, resolved_user
    end

    test "rejects malformed or wrong bearer headers" do
      user = User.create!(username: "hazel")

      assert_nil Auth.user_from_bearer_header(nil)
      assert_nil Auth.user_from_bearer_header("Token #{user.plain_pat}")
      assert_nil Auth.user_from_bearer_header("Bearer wrong-token")
    end

    test "resolves a user from basic auth credentials" do
      user = User.create!(username: "hazel")
      header = "Basic #{Base64.strict_encode64("#{user.username}:#{user.plain_pat}")}"

      resolved_user = Auth.user_from_basic_header(header)

      assert_equal user, resolved_user
    end

    test "rejects malformed or mismatched basic auth credentials" do
      user = User.create!(username: "hazel")

      wrong_header = "Basic #{Base64.strict_encode64("#{user.username}:wrong-token")}"
      other_user = User.create!(username: "quinn")
      mismatched_header = "Basic #{Base64.strict_encode64("#{other_user.username}:#{user.plain_pat}")}"

      assert_nil Auth.user_from_basic_header(nil)
      assert_nil Auth.user_from_basic_header("Basic not-base64")
      assert_nil Auth.user_from_basic_header(wrong_header)
      assert_nil Auth.user_from_basic_header(mismatched_header)
    end
  end
end
