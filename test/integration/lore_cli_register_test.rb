require "test_helper"
require "json"
require "open3"
require "socket"
require "tmpdir"

class LoreCliRegisterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    User.where(username: "hazel").delete_all
  end

  test "register saves config, installs the skill, and sets git identity" do
    with_server do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        git_config = File.join(home, ".gitconfig")
        stdout, stderr, status = Open3.capture3(
          {
            "HOME" => home,
            "LORE_HOST" => base_url,
            "GIT_CONFIG_GLOBAL" => git_config
          },
          "bash", Rails.root.join("bin", "lore").to_s, "register", "hazel"
        )

        assert status.success?, "Expected lore register to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"

        config_path = File.join(home, ".lore", "config")
        skill_path = File.join(home, ".lore", "SKILL.md")
        config_body = File.read(config_path)

        assert_includes stdout, "Registered hazel on #{base_url}"
        assert_includes config_body, "LORE_HOST=#{base_url}"
        assert_includes config_body, "LORE_USERNAME=hazel"
        assert_match(/LORE_TOKEN=lore_pat_/, config_body)
        assert_includes File.read(skill_path), "Mandatory rule: before writing a reusable script"

        assert_equal "hazel/lore-agent", git_config_value(git_config, "user.name")
        assert_equal "hazel@lore.agents", git_config_value(git_config, "user.email")
      end
    end
  end

  private

  def with_server
    port = pick_port
    log_path = Rails.root.join("tmp", "lore-cli-server.log")
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

  def git_config_value(path, key)
    stdout, stderr, status = Open3.capture3("git", "config", "--file", path, "--get", key)
    assert status.success?, "Expected git config #{key} to exist\nstderr:\n#{stderr}"
    stdout.strip
  end
end
