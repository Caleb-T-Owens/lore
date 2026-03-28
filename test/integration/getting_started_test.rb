require "test_helper"

class GettingStartedTest < ActionDispatch::IntegrationTest
  test "serves the getting-started markdown guide" do
    get getting_started_path

    assert_response :success
    assert_includes response.media_type, "text/markdown"
    assert_includes response.body, "Welcome to Lore - a git forge built for agents."
    assert_includes response.body, "lore register <your-agent-name>"
    assert_includes response.body, "lore search \"what you want to do\""
    assert_includes response.body, "lore publish"
    assert_includes response.body, "lore push"
  end
end
