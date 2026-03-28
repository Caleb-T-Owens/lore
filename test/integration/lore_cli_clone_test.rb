require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class LoreCliCloneTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "clone fetches the repo over git http and auto-stars it" do
    owner = User.create!(username: "hazel")
    contributor = User.create!(username: "agent")
    repo = Lore::RepoProvisioner.create(
      owner: owner,
      params: {
        name: "slack-notify",
        description: "Posts to Slack",
        tags: ["slack"]
      }
    )
    seed_repo(repo.path, "# Slack Notify\n")

    with_lore_test_server(log_name: "lore-cli-clone-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        Dir.mktmpdir("lore-cli-clone") do |dir|
          clone_path = File.join(dir, "slack-notify")
          write_lore_cli_config(home, base_url, contributor)

          stdout, stderr, status = Open3.capture3(
            { "HOME" => home },
            "bash", Rails.root.join("bin", "lore").to_s, "clone", "hazel/slack-notify", clone_path
          )

          assert status.success?, "Expected lore clone to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
          refute_includes stderr, "fatal:"
          assert_includes stdout, "Cloned hazel/slack-notify to #{clone_path}"
          assert_includes stdout, "Starred hazel/slack-notify"
          assert_equal "# Slack Notify\n", File.read(File.join(clone_path, "README.md"))
          assert_predicate Star.find_by(user: contributor, repo: repo), :present?
        end
      end
    end
  end

  test "clone still succeeds when auto-starring fails" do
    owner = User.create!(username: "hazel")
    repo = Lore::RepoProvisioner.create(
      owner: owner,
      params: {
        name: "slack-notify",
        description: "Posts to Slack",
        tags: ["slack"]
      }
    )
    seed_repo(repo.path, "# Slack Notify\n")

    with_lore_test_server(log_name: "lore-cli-clone-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        Dir.mktmpdir("lore-cli-clone") do |dir|
          clone_path = File.join(dir, "slack-notify")
          config_user = Struct.new(:plain_pat, :username).new("invalid-token", "agent")
          write_lore_cli_config(home, base_url, config_user)

          stdout, stderr, status = Open3.capture3(
            { "HOME" => home },
            "bash", Rails.root.join("bin", "lore").to_s, "clone", "hazel/slack-notify", clone_path
          )

          assert status.success?, "Expected lore clone to succeed even when auto-star fails\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
          assert_includes stdout, "Cloned hazel/slack-notify to #{clone_path}"
          refute_includes stdout, "Starred hazel/slack-notify"
          assert_includes stderr, "Warning: cloned hazel/slack-notify but could not star it automatically."
          assert_equal "# Slack Notify\n", File.read(File.join(clone_path, "README.md"))
          assert_equal 0, repo.stars.count
        end
      end
    end
  end

  private

  def seed_repo(repo_path, readme_content)
    Dir.mktmpdir("lore-cli-seed") do |worktree|
      system("git", "init", "--initial-branch=main", worktree, exception: true)
      system("git", "-C", worktree, "config", "user.name", "Lore Test", exception: true)
      system("git", "-C", worktree, "config", "user.email", "lore-test@example.com", exception: true)
      File.write(File.join(worktree, "README.md"), readme_content)
      system("git", "-C", worktree, "add", "README.md", exception: true)
      system("git", "-C", worktree, "commit", "-m", "Seed README", exception: true)
      system("git", "-C", worktree, "remote", "add", "origin", repo_path, exception: true)
      system("git", "-C", worktree, "push", "origin", "main", exception: true)
    end
  end

end
