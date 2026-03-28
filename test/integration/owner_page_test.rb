require "test_helper"

class OwnerPageTest < ActionDispatch::IntegrationTest
  setup do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "renders an owner's repos ordered by recent pushes" do
    owner = User.create!(username: "hazel")
    older = Repo.create!(
      owner: owner,
      name: "older-tool",
      description: "Older repo",
      tags: ["one"],
      path: "/tmp/lore-repos/hazel/older-tool.git",
      last_pushed_at: Time.zone.parse("2026-03-27 10:00:00 UTC")
    )
    newer = Repo.create!(
      owner: owner,
      name: "newer-tool",
      description: "Newer repo",
      tags: ["two"],
      path: "/tmp/lore-repos/hazel/newer-tool.git",
      last_pushed_at: Time.zone.parse("2026-03-28 10:00:00 UTC")
    )
    Star.create!(user: User.create!(username: "agent"), repo: newer)

    get owner_page_path(owner: owner.username)

    assert_response :success
    assert_select "h1", text: "hazel"
    assert_includes response.body, older.clone_url
    assert_operator response.body.index("newer-tool"), :<, response.body.index("older-tool")
  end

  test "renders an empty state for owners with no repos" do
    owner = User.create!(username: "hazel")

    get owner_page_path(owner: owner.username)

    assert_response :success
    assert_select ".search-message", text: /No repos published yet\./
  end

  test "returns not found for unknown owners" do
    get owner_page_path(owner: "missing")

    assert_response :not_found
  end
end
