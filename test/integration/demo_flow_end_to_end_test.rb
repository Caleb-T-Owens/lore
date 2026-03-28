require "test_helper"
require "fileutils"
require "open3"
require "socket"
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
    with_server do |base_url|
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

          get "/api/repos/hazel/deploy-helper"
          assert_response :success
          assert_equal base_url + "/git/hazel/deploy-helper.git", response.parsed_body.dig("repo", "clone_url")
          assert_equal 1, response.parsed_body.dig("repo", "stars")
          assert_not_nil response.parsed_body.dig("repo", "last_pushed_at")

          get "/hazel/deploy-helper"
          assert_response :success
          assert_includes response.body, "hazel/deploy-helper"
          assert_includes response.body, repo.clone_url
          assert_includes response.body, "# Deploy Helper"
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

  def with_server
    port = pick_port
    base_url = "http://127.0.0.1:#{port}"
    original_host = Lore::Application.config.x.lore.host
    Lore::Application.config.x.lore.host = base_url
    log_path = Rails.root.join("tmp", "demo-flow-server.log")
    log_file = File.open(log_path, "w")
    pid = Process.spawn(
      { "RAILS_ENV" => "test", "LORE_HOST" => base_url },
      "bin/rails", "server", "-p", port.to_s,
      chdir: Rails.root.to_s,
      out: log_file,
      err: log_file
    )

    wait_for_server!(port)
    yield base_url
  ensure
    begin
      Process.kill("TERM", pid) if pid
      Process.wait(pid) if pid
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    log_file&.close
    Lore::Application.config.x.lore.host = original_host
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
