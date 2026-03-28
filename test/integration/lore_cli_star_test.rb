require "test_helper"
require "open3"
require "tmpdir"

class LoreCliStarTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "star marks a repo as starred and prints updated count" do
    owner = User.create!(username: "hazel")
    stargazer = User.create!(username: "agent")
    repo = Repo.create!(
      owner: owner,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: ["slack"],
      path: "/tmp/lore-repos/hazel/slack-notify.git"
    )

    with_lore_test_server(log_name: "lore-cli-star-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        write_lore_cli_config(home, base_url, stargazer)

        stdout, stderr, status = Open3.capture3(
          { "HOME" => home },
          "bash", Rails.root.join("bin", "lore").to_s, "star", "hazel/slack-notify"
        )

        assert status.success?, "Expected lore star to succeed\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
        assert_empty stderr
        assert_includes stdout, "Starred hazel/slack-notify (1 stars)"
        assert_predicate Star.find_by(user: stargazer, repo: repo), :present?
      end
    end
  end

  test "star fails clearly when no token is configured" do
    with_lore_test_server(log_name: "lore-cli-star-server.log") do
      Dir.mktmpdir("lore-cli-home") do |home|
        stdout, stderr, status = Open3.capture3(
          { "HOME" => home },
          "bash", Rails.root.join("bin", "lore").to_s, "star", "hazel/slack-notify"
        )

        assert_not status.success?
        assert_empty stdout
        assert_includes stderr, "Lore token not found"
      end
    end
  end
end
