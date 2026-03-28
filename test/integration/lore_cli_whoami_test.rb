require "test_helper"
require "fileutils"
require "open3"
require "socket"
require "tmpdir"

class LoreCliWhoamiTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "whoami prints the configured identity and starred repo count" do
    owner = User.create!(username: "hazel")
    repo = Repo.create!(owner: owner, name: "slack-notify", description: "Posts to Slack", tags: ["slack"], path: "/tmp/slack-notify.git")
    user = User.create!(username: "agent")
    Star.create!(user: user, repo: repo)

    with_server do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        write_config(home, base_url, user)

        stdout, stderr, status = Open3.capture3(
          { "HOME" => home },
          "bash", Rails.root.join("bin", "lore").to_s, "whoami"
        )

        assert status.success?, "Expected lore whoami to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
        assert_empty stderr
        assert_includes stdout, "Username: agent"
        assert_includes stdout, "Host: #{base_url}"
        assert_includes stdout, "Starred repos: 1"
        assert_match(/Token: lore_pat\.\.\.[A-Za-z0-9_-]{4}/, stdout)
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

  def with_server
    port = pick_port
    log_path = Rails.root.join("tmp", "lore-cli-whoami-server.log")
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
