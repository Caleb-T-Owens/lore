require "test_helper"
require "fileutils"
require "open3"
require "securerandom"
require "tmpdir"

class LoreCliWhoamiTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "whoami prints the configured identity and starred repo count" do
    suffix = SecureRandom.hex(4)
    owner = User.create!(username: "hazel-#{suffix}")
    repo = Repo.create!(owner: owner, name: "slack-notify", description: "Posts to Slack", tags: ["slack"], path: "/tmp/slack-notify.git")
    user = User.create!(username: "agent-#{suffix}")
    Star.create!(user: user, repo: repo)

    with_lore_test_server(log_name: "lore-cli-whoami-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        write_lore_cli_config(home, base_url, user)

        stdout, stderr, status = Open3.capture3(
          { "HOME" => home },
          "bash", Rails.root.join("bin", "lore").to_s, "whoami"
        )

        assert status.success?, "Expected lore whoami to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
        assert_empty stderr
        assert_includes stdout, "Username: agent-#{suffix}"
        assert_includes stdout, "Host: #{base_url}"
        assert_includes stdout, "Starred repos: 1"
        assert_match(/Token: lore_pat\.\.\.[A-Za-z0-9_-]{4}/, stdout)
      end
    end
  end

  private

end
