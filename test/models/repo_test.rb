require "test_helper"

class RepoTest < ActiveSupport::TestCase
  test "normalizes names and tags" do
    owner = User.create!(username: "hazel")
    repo = Repo.create!(
      owner: owner,
      name: "Slack-Notify",
      description: "Posts to Slack",
      tags: [" Slack ", "notifications", "slack"],
      path: "/tmp/lore-repos/hazel/slack-notify.git"
    )

    assert_equal "slack-notify", repo.name
    assert_equal ["slack", "notifications"], repo.tags
  end

  test "requires an absolute path" do
    owner = User.create!(username: "hazel")
    repo = Repo.new(
      owner: owner,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: [],
      path: "relative/path.git"
    )

    assert_not repo.valid?
    assert_includes repo.errors[:path], "must be absolute"
  end

  test "builds embedding input from searchable metadata" do
    owner = User.create!(username: "hazel")
    repo = Repo.new(
      owner: owner,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: ["slack", "notifications"],
      path: "/tmp/lore-repos/hazel/slack-notify.git"
    )

    assert_equal "slack-notify\nPosts to Slack\nslack notifications", repo.embedding_input
  end
end
