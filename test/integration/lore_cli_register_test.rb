require "test_helper"
require "json"
require "open3"
require "tmpdir"

class LoreCliRegisterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    User.where(username: "hazel").delete_all
  end

  test "register saves config, installs the skill, and sets git identity" do
    with_lore_test_server(log_name: "lore-cli-server.log") do |base_url|
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

  test "register prints a readable validation error for duplicate usernames" do
    User.create!(username: "hazel")

    with_lore_test_server(log_name: "lore-cli-server.log") do |base_url|
      Dir.mktmpdir("lore-cli-home") do |home|
        stdout, stderr, status = Open3.capture3(
          { "HOME" => home, "LORE_HOST" => base_url },
          "bash", Rails.root.join("bin", "lore").to_s, "register", "hazel"
        )

        assert_not status.success?
        assert_empty stdout
        assert_includes stderr, "Lore API request failed (409): Username has already been taken"
        refute File.exist?(File.join(home, ".lore", "config"))
      end
    end
  end

  private

  def git_config_value(path, key)
    stdout, stderr, status = Open3.capture3("git", "config", "--file", path, "--get", key)
    assert status.success?, "Expected git config #{key} to exist\nstderr:\n#{stderr}"
    stdout.strip
  end
end
