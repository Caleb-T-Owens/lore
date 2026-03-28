require "test_helper"
require "fileutils"
require "open3"
require "socket"
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

    with_server do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        Dir.mktmpdir("lore-cli-clone") do |dir|
          clone_path = File.join(dir, "slack-notify")
          write_config(home, base_url, contributor)

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

  private

  def write_config(home, base_url, user)
    config_dir = File.join(home, ".lore")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "config"), <<~CONFIG)
      LORE_TOKEN=#{user.plain_pat}
      LORE_HOST=#{base_url}
      LORE_USERNAME=#{user.username}
    CONFIG
  end

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

  def with_server
    port = pick_port
    log_path = Rails.root.join("tmp", "lore-cli-clone-server.log")
    log_file = File.open(log_path, "w")
    pid = Process.spawn(
      { "RAILS_ENV" => "test" },
      "bin/rails", "server", "-p", port.to_s,
      chdir: Rails.root.to_s,
      out: log_file,
      err: log_file
    )

    wait_for_server!(port)
    yield "http://127.0.0.1:#{port}"
  ensure
    begin
      Process.kill("TERM", pid) if pid
      Process.wait(pid) if pid
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    log_file&.close
  end

  def pick_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def wait_for_server!(port)
    60.times do
      socket = TCPSocket.new("127.0.0.1", port)
      socket.close
      return
    rescue Errno::ECONNREFUSED
      sleep 0.25
    end

    flunk "Timed out waiting for Rails server on port #{port}"
  end
end
