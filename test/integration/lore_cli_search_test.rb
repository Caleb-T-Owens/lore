require "test_helper"
require "open3"
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

    with_lore_test_server(log_name: "lore-cli-search-server.log") do |base_url|
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
end
