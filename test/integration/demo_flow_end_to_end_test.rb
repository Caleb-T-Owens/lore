require "test_helper"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "tmpdir"

class DemoFlowEndToEndTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "register publish clone push and metadata refresh work together" do
    with_lore_test_server(log_name: "demo-flow-server.log", host_override: true) do |base_url|
      Dir.mktmpdir("lore-e2e-home") do |home|
        git_config = File.join(home, ".gitconfig")

        register_stdout, = run_lore(home, base_url, git_config, "register", "hazel")
        assert_includes register_stdout, "Registered hazel on #{base_url}"

        Dir.mktmpdir("lore-e2e-project") do |workspace|
          source_path = File.join(workspace, "deploy-helper")
          clone_path = File.join(workspace, "deploy-helper-clone")
          setup_local_repo(source_path)

          publish_stdout, = run_lore(
            home, base_url, git_config,
            "publish", source_path,
            "--description", "Posts deploy updates to Slack",
            "--tags", "slack,deploy"
          )
          assert_includes publish_stdout, "Created repo hazel/deploy-helper"

          clone_stdout, = run_lore(home, base_url, git_config, "clone", "hazel/deploy-helper", clone_path)
          assert_includes clone_stdout, "Cloned hazel/deploy-helper to #{clone_path}"
          assert_includes clone_stdout, "Starred hazel/deploy-helper"

          File.write(File.join(clone_path, "emoji.txt"), ":rocket:\n")
          run_command!("git", "-C", clone_path, "add", "emoji.txt")
          run_command!("git", "-C", clone_path, "commit", "-m", "Add emoji support", env: { "HOME" => home, "GIT_CONFIG_GLOBAL" => git_config })

          push_stdout, = run_lore(home, base_url, git_config, "push", clone_path)
          assert_includes push_stdout, "Rebasing #{clone_path} onto origin/main"
          assert_includes push_stdout, "Pushing #{clone_path} to main"

          repo = Repo.find_by!(name: "deploy-helper", owner: User.find_by!(username: "hazel"))
          assert_predicate repo.last_pushed_at, :present?
          assert_equal 1, repo.stars.count

          repo_payload = get_json!("#{base_url}/api/repos/hazel/deploy-helper").fetch("repo")
          assert_equal base_url + "/git/hazel/deploy-helper.git", repo_payload.fetch("clone_url")
          assert_equal 1, repo_payload.fetch("stars")
          assert_not_nil repo_payload.fetch("last_pushed_at")

          repo_page = get_text!("#{base_url}/hazel/deploy-helper")
          assert_includes repo_page, "hazel/deploy-helper"
          assert_includes repo_page, repo.clone_url
          assert_includes repo_page, "# Deploy Helper"
        end
      end
    end
  end

  private

  def setup_local_repo(path)
    FileUtils.mkdir_p(path)
    system("git", "init", "--initial-branch=main", path, exception: true)
    system("git", "-C", path, "config", "user.name", "Lore Test", exception: true)
    system("git", "-C", path, "config", "user.email", "lore-test@example.com", exception: true)
    File.write(File.join(path, "README.md"), "# Deploy Helper\n")
    system("git", "-C", path, "add", "README.md", exception: true)
    system("git", "-C", path, "commit", "-m", "Initial commit", exception: true)
  end

  def run_lore(home, base_url, git_config, *args)
    run_command!("bash", Rails.root.join("bin", "lore").to_s, *args, env: {
      "HOME" => home,
      "LORE_HOST" => base_url,
      "GIT_CONFIG_GLOBAL" => git_config
    })
  end

  def run_command!(*command, env: {})
    stdout, stderr, status = Open3.capture3(env, *command)
    assert status.success?, <<~MESSAGE
      Command failed: #{command.join(" ")}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE

    [stdout, stderr, status]
  end

  def get_json!(url)
    response = Net::HTTP.get_response(URI(url))
    assert response.is_a?(Net::HTTPSuccess), "Expected success from #{url}, got #{response.code}: #{response.body}"

    JSON.parse(response.body)
  end

  def get_text!(url)
    response = Net::HTTP.get_response(URI(url))
    assert response.is_a?(Net::HTTPSuccess), "Expected success from #{url}, got #{response.code}: #{response.body}"

    response.body
  end

end
