require "test_helper"
require "fileutils"
require "tmpdir"

class RepoPageTest < ActionDispatch::IntegrationTest
  setup do
    Star.delete_all
    Repo.delete_all
    User.delete_all
    @tmp_dirs = []
  end

  teardown do
    @tmp_dirs.each { |dir| FileUtils.rm_rf(dir) }
  end

  test "renders repo metadata and the README from main" do
    owner = User.create!(username: "hazel")
    repo_path = create_bare_repo_with_readme("# Slack Notify\n\nPosts a message to Slack.\n")
    repo = Repo.create!(
      owner: owner,
      name: "slack-notify",
      description: "Posts a message to a Slack webhook",
      tags: ["slack", "notifications"],
      path: repo_path,
      last_pushed_at: Time.zone.parse("2026-03-28 16:20:00 UTC")
    )
    Star.create!(user: User.create!(username: "agent"), repo: repo)

    get repo_page_path(owner: owner.username, repo: repo.name)

    assert_response :success
    assert_select "h1", text: "hazel/slack-notify"
    assert_includes response.body, repo.clone_url
    assert_includes response.body, "lore clone hazel/slack-notify"
    assert_includes response.body, "# Slack Notify"
    assert_select "button", text: "Copy"
  end

  test "renders an intentional empty state when the repo has no readme" do
    owner = User.create!(username: "hazel")
    repo_path = create_empty_bare_repo
    repo = Repo.create!(owner: owner, name: "bare-tool", description: "Bare repo", tags: [], path: repo_path)

    get repo_page_path(owner: owner.username, repo: repo.name)

    assert_response :success
    assert_select ".search-message", text: /No README on main yet\./
  end

  test "returns not found for an unknown repo" do
    owner = User.create!(username: "hazel")

    get repo_page_path(owner: owner.username, repo: "missing")

    assert_response :not_found
  end

  private

  def create_empty_bare_repo
    root = Dir.mktmpdir("lore-repo-page")
    @tmp_dirs << root
    repo_path = File.join(root, "repo.git")
    system("git", "init", "--bare", "--initial-branch=main", repo_path, exception: true)
    repo_path
  end

  def create_bare_repo_with_readme(readme_content)
    root = Dir.mktmpdir("lore-repo-page")
    @tmp_dirs << root
    repo_path = File.join(root, "repo.git")
    worktree = File.join(root, "worktree")

    system("git", "init", "--bare", "--initial-branch=main", repo_path, exception: true)
    system("git", "init", "--initial-branch=main", worktree, exception: true)
    system("git", "-C", worktree, "config", "user.name", "Lore Test", exception: true)
    system("git", "-C", worktree, "config", "user.email", "lore-test@example.com", exception: true)
    File.write(File.join(worktree, "README.md"), readme_content)
    system("git", "-C", worktree, "add", "README.md", exception: true)
    system("git", "-C", worktree, "commit", "-m", "Add README", exception: true)
    system("git", "-C", worktree, "remote", "add", "origin", repo_path, exception: true)
    system("git", "-C", worktree, "push", "origin", "main", exception: true)

    repo_path
  end
end
