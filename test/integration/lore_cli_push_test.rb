require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class LoreCliPushTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "push rebases onto origin main and pushes with configured lore auth" do
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
    seed_repo(repo.path, "README.md" => "# Slack Notify\n")

    with_lore_test_server(log_name: "lore-cli-push-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        Dir.mktmpdir("lore-cli-push") do |dir|
          primary_clone = File.join(dir, "primary")
          remote_clone = File.join(dir, "remote")
          public_remote = "#{base_url}/git/hazel/slack-notify.git"
          push_remote = "#{base_url.sub('http://', "http://#{contributor.username}:#{contributor.plain_pat}@")}/git/hazel/slack-notify.git"

          write_lore_cli_config(home, base_url, contributor)

          run_command!("git", "clone", public_remote, primary_clone)
          configure_git_identity!(primary_clone)
          File.write(File.join(primary_clone, "local.txt"), "local change\n")
          run_command!("git", "-C", primary_clone, "add", "local.txt")
          run_command!("git", "-C", primary_clone, "commit", "-m", "Local change")

          run_command!("git", "clone", public_remote, remote_clone)
          configure_git_identity!(remote_clone)
          File.write(File.join(remote_clone, "remote.txt"), "remote change\n")
          run_command!("git", "-C", remote_clone, "add", "remote.txt")
          run_command!("git", "-C", remote_clone, "commit", "-m", "Remote change")
          run_command!("git", "-C", remote_clone, "push", push_remote, "HEAD:main")

          stdout, stderr, status = Open3.capture3(
            { "HOME" => home },
            "bash", Rails.root.join("bin", "lore").to_s, "push", primary_clone
          )

          assert status.success?, "Expected lore push to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
          refute_includes stderr, "fatal:"
          assert_includes stdout, "Rebasing #{primary_clone} onto origin/main"
          assert_includes stdout, "Pushing #{primary_clone} to main"
          assert_predicate repo.reload.last_pushed_at, :present?

          remote_contents = clone_files(repo.path)
          assert_equal "local change\n", remote_contents.fetch("local.txt")
          assert_equal "remote change\n", remote_contents.fetch("remote.txt")
        end
      end
    end
  end

  private

  def seed_repo(repo_path, files)
    Dir.mktmpdir("lore-cli-seed") do |worktree|
      system("git", "init", "--initial-branch=main", worktree, exception: true)
      system("git", "-C", worktree, "config", "user.name", "Lore Test", exception: true)
      system("git", "-C", worktree, "config", "user.email", "lore-test@example.com", exception: true)
      files.each do |name, body|
        File.write(File.join(worktree, name), body)
      end
      system("git", "-C", worktree, "add", ".", exception: true)
      system("git", "-C", worktree, "commit", "-m", "Seed README", exception: true)
      system("git", "-C", worktree, "remote", "add", "origin", repo_path, exception: true)
      system("git", "-C", worktree, "push", "origin", "main", exception: true)
    end
  end

  def clone_files(repo_path)
    Dir.mktmpdir("lore-cli-push-clone") do |clone_parent|
      clone_path = File.join(clone_parent, "repo")
      system("git", "clone", repo_path, clone_path, exception: true)
      return {
        "README.md" => File.read(File.join(clone_path, "README.md")),
        "local.txt" => File.read(File.join(clone_path, "local.txt")),
        "remote.txt" => File.read(File.join(clone_path, "remote.txt"))
      }
    end
  end

  def configure_git_identity!(path)
    run_command!("git", "-C", path, "config", "user.name", "Lore Test")
    run_command!("git", "-C", path, "config", "user.email", "lore-test@example.com")
  end

  def run_command!(*command)
    stdout, stderr, status = Open3.capture3({ "GIT_TERMINAL_PROMPT" => "0" }, *command)
    assert status.success?, <<~MESSAGE
      Command failed: #{command.join(" ")}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE

    [stdout, stderr, status]
  end

end
