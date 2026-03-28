require "test_helper"
require "fileutils"
require "open3"
require "socket"
require "tmpdir"
require "uri"

class LoreCliPublishTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "publish creates a lore repo, adds origin, and pushes main" do
    publisher = User.create!(username: "hazel")

    with_server do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        Dir.mktmpdir("lore-cli-project") do |parent|
          project_path = File.join(parent, "slack-notify")
          setup_local_repo(project_path)
          write_config(home, base_url, publisher)

          stdout, stderr, status = Open3.capture3(
            { "HOME" => home },
            "bash", Rails.root.join("bin", "lore").to_s,
            "publish", project_path,
            "--description", "Posts a message to a Slack webhook",
            "--tags", "slack,notifications"
          )

          assert status.success?, "Expected lore publish to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
          refute_includes stderr, "fatal:"
          assert_includes stdout, "Created repo hazel/slack-notify"
          assert_includes stdout, "Added origin #{base_url}/git/hazel/slack-notify.git"
          assert_includes stdout, "Pushed main to hazel/slack-notify"

          repo = Repo.find_by!(owner: publisher, name: "slack-notify")
          assert_equal ["slack", "notifications"], repo.tags
          assert_predicate repo.last_pushed_at, :present?

          remote = git_stdout(project_path, "remote", "get-url", "origin")
          assert_equal "http://hazel:#{publisher.plain_pat}@127.0.0.1:#{URI(base_url).port}/git/hazel/slack-notify.git", remote

          cloned_readme = clone_readme(repo.path)
          assert_includes cloned_readme, "# Slack Notify"
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

  def setup_local_repo(project_path)
    FileUtils.mkdir_p(project_path)
    system("git", "init", "--initial-branch=main", project_path, exception: true)
    system("git", "-C", project_path, "config", "user.name", "Lore Test", exception: true)
    system("git", "-C", project_path, "config", "user.email", "lore-test@example.com", exception: true)
    File.write(File.join(project_path, "README.md"), "# Slack Notify\n")
    system("git", "-C", project_path, "add", "README.md", exception: true)
    system("git", "-C", project_path, "commit", "-m", "Initial commit", exception: true)
  end

  def clone_readme(repo_path)
    Dir.mktmpdir("lore-cli-publish-clone") do |clone_parent|
      clone_path = File.join(clone_parent, "repo")
      system("git", "clone", repo_path, clone_path, exception: true)
      return File.read(File.join(clone_path, "README.md"))
    end
  end

  def git_stdout(path, *args)
    stdout, stderr, status = Open3.capture3("git", "-C", path, *args)
    assert status.success?, "Expected git #{args.join(' ')} to succeed\nstderr:\n#{stderr}"
    stdout.strip
  end

  def with_server
    port = pick_port
    base_url = "http://127.0.0.1:#{port}"
    log_path = Rails.root.join("tmp", "lore-cli-publish-server.log")
    log_file = File.open(log_path, "w")
    pid = Process.spawn(
      { "RAILS_ENV" => "test", "LORE_HOST" => base_url },
      "bin/rails", "server", "-p", port.to_s,
      chdir: Rails.root.to_s,
      out: log_file,
      err: log_file
    )

    wait_for_server!(port)
    yield base_url
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
