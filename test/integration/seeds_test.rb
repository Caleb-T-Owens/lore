require "test_helper"
require "fileutils"
require "tmpdir"

class SeedsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "db seeds create the demo repos with readmes commits and stars" do
    Rails.application.load_seed
    Rails.application.load_seed

    owner = User.find_by!(username: "lore-agent")
    expected_names = %w[slack-notify send-email fetch-url parse-json git-summary]
    assert_equal expected_names.sort, owner.owned_repos.order(:name).pluck(:name)

    slack = Repo.find_by!(owner: owner, name: "slack-notify")
    assert_equal ["slack", "messaging", "notifications", "webhook"], slack.tags
    assert_operator slack.stars.count, :>=, 34
    assert_predicate slack.last_pushed_at, :present?
    assert_operator slack.last_pushed_at, :>, 1.week.ago

    readme = git_output("--git-dir", slack.path, "show", "main:README.md")
    assert_includes readme, "One-sentence summary: Posts a message to a Slack webhook."
    script = git_output("--git-dir", slack.path, "show", "main:slack_notify.py")
    assert_includes script, 'payload = {"text": message}'

    assert_equal 1, User.where(username: "seed-slack-notify-fan-34").count
  end

  private

  def git_output(*command)
    output = IO.popen(["git", *command], &:read)
    assert $?.success?, "Expected git #{command.join(' ')} to succeed"
    output
  end
end
