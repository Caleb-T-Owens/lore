require "test_helper"

class HomePageTest < ActionDispatch::IntegrationTest
  setup do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "renders the lore homepage with recent repos and core calls to action" do
    owner = User.create!(username: "hazel")
    repo = Repo.create!(
      owner: owner,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack", "notifications"],
      path: "/tmp/lore-repos/hazel/slack-notify.git",
      last_pushed_at: Time.zone.parse("2026-03-28 16:20:00 UTC")
    )
    Star.create!(user: User.create!(username: "agent"), repo: repo)

    get root_path

    assert_response :success
    assert_select "h1", text: "Search before you build."
    assert_select "form[action='#{search_path}']"
    assert_select "a[href='/getting-started.md']"
    assert_select ".repo-card", text: /hazel\/slack-notify/
    assert_includes response.body, repo.clone_url
  end

  test "renders an intentional empty state when no repos exist" do
    get root_path

    assert_response :success
    assert_select ".empty-state", text: /No repos yet\./
  end
end
