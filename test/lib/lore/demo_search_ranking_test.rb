require "test_helper"
require "fileutils"

module Lore
  class DemoSearchRankingTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    teardown do
      FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
      Star.delete_all
      Repo.delete_all
      User.delete_all
    end

    test "seeded repos win the demo-critical search queries" do
      Rails.application.load_seed

      expectations = {
        "send slack message" => "slack-notify",
        "post to webhook" => "slack-notify",
        "send email" => "send-email",
        "read a url" => "fetch-url",
        "summarize git history" => "git-summary"
      }

      expectations.each do |query, expected_repo|
        result = RepoSearch.search(query).first

        assert_not_nil result, "Expected a search result for #{query.inspect}"
        assert_equal expected_repo, result.repo.name, "Expected #{expected_repo} to rank first for #{query.inspect}"
      end
    end
  end
end
