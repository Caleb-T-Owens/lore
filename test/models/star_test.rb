require "test_helper"

class StarTest < ActiveSupport::TestCase
  test "enforces one star per user and repo" do
    user = User.create!(username: "hazel")
    repo = Repo.create!(
      owner: user,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: [],
      path: "/tmp/lore-repos/hazel/slack-notify.git"
    )

    Star.create!(user: user, repo: repo)
    duplicate = Star.new(user: user, repo: repo)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
