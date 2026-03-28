require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates a pat digest and exposes the plaintext token once" do
    user = User.create!(username: "Hazel")

    assert_equal "hazel", user.username
    assert_match(/^lore_pat_/, user.plain_pat)
    assert_equal User.digest_pat(user.plain_pat), user.pat_digest
    assert_equal user, user.authenticate_pat(user.plain_pat)
    assert_equal false, user.authenticate_pat("wrong-token")
  end

  test "rejects invalid usernames" do
    user = User.new(username: "9Hazel")

    assert_not user.valid?
    assert_includes user.errors[:username], "is invalid"
  end
end
