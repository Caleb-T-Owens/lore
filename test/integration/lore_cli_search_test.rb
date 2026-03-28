require "test_helper"
require "open3"
require "socket"
require "tmpdir"

class LoreCliSearchTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "search prints ranked repos in predictable terminal output" do
    owner = User.create!(username: "hazel")
    match_embedding = Lore::Embeddings.embed("send slack notification")
    Repo.create!(
      owner: owner,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: ["slack", "notifications"],
      path: "/tmp/lore-repos/hazel/slack-notify.git",
      embedding: match_embedding
    )
    Repo.create!(
      owner: owner,
      name: "send-email",
      description: "Sends email",
      tags: ["email"],
      path: "/tmp/lore-repos/hazel/send-email.git",
      embedding: Array.new(match_embedding.length, 0.0)
    )
    Star.create!(user: User.create!(username: "agent"), repo: Repo.find_by!(name: "slack-notify"))

    with_server do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        stdout, stderr, status = Open3.capture3(
          { "HOME" => home, "LORE_HOST" => base_url },
          "bash", Rails.root.join("bin", "lore").to_s, "search", "send", "slack", "notification"
        )

        assert status.success?, "Expected lore search to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
        assert_empty stderr
        assert_includes stdout, "1. hazel/slack-notify (1 stars) - Posts to Slack"
        assert_includes stdout, "2. hazel/send-email (0 stars) - Sends email"
        assert_operator stdout.index("hazel/slack-notify"), :<, stdout.index("hazel/send-email")
      end
    end
  end

  private

  def with_server
    port = pick_port
    log_path = Rails.root.join("tmp", "lore-cli-search-server.log")
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
