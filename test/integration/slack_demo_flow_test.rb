require "test_helper"
require "fileutils"
require "json"
require "open3"
require "socket"
require "tmpdir"

class SlackDemoFlowTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  teardown do
    FileUtils.rm_rf(Rails.application.config.x.lore.repo_root)
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "the slack demo flow can search clone use and push an emoji improvement" do
    Rails.application.load_seed

    with_server do |base_url|
      Dir.mktmpdir("lore-slack-demo-home") do |home|
        git_config = File.join(home, ".gitconfig")
        clone_path = nil

        run_lore(home, base_url, git_config, "register", "demo-agent")

        search_stdout, = run_lore(home, base_url, git_config, "search", "send", "slack", "notification")
        assert_match(/^1\. lore-agent\/slack-notify \(34 stars\) - Posts a message to a Slack webhook\.$/, search_stdout.lines.first.to_s.strip)

        Dir.mktmpdir("lore-slack-demo") do |workspace|
          clone_path = File.join(workspace, "slack-notify")
          clone_stdout, = run_lore(home, base_url, git_config, "clone", "lore-agent/slack-notify", clone_path)
          assert_includes clone_stdout, "Cloned lore-agent/slack-notify to #{clone_path}"

          with_webhook do |webhook_url, deliveries|
            script_stdout, = run_command!("python3", "slack_notify.py", env: {
              "HOME" => home,
              "GIT_CONFIG_GLOBAL" => git_config,
              "SLACK_WEBHOOK_URL" => webhook_url,
              "MESSAGE" => "deploy finished"
            }, chdir: clone_path)

            assert_equal "sent\n", script_stdout
            assert_equal({ "text" => "deploy finished" }, deliveries.first)
          end

          add_emoji_support(clone_path)
          run_command!("git", "-C", clone_path, "add", "slack_notify.py")
          run_command!("git", "-C", clone_path, "commit", "-m", "Add emoji support", env: { "HOME" => home, "GIT_CONFIG_GLOBAL" => git_config })

          push_stdout, = run_lore(home, base_url, git_config, "push", clone_path)
          assert_includes push_stdout, "Pushing #{clone_path} to main"

          script = IO.popen(["git", "--git-dir", Repo.find_by!(name: "slack-notify").path, "show", "main:slack_notify.py"], &:read)
          assert_includes script, 'payload["icon_emoji"] = emoji'
        end
      end
    end
  end

  private

  def add_emoji_support(path)
    script_path = File.join(path, "slack_notify.py")
    updated = File.read(script_path).sub(
      "message = os.environ[\"MESSAGE\"]\n",
      "message = os.environ[\"MESSAGE\"]\nemoji = os.environ.get(\"EMOJI\")\n"
    ).sub(
      "payload = {\"text\": message}\n",
      "payload = {\"text\": message}\nif emoji:\n  payload[\"icon_emoji\"] = emoji\n"
    )
    File.write(script_path, updated)
  end

  def run_lore(home, base_url, git_config, *args)
    run_command!("bash", Rails.root.join("bin", "lore").to_s, *args, env: {
      "HOME" => home,
      "LORE_HOST" => base_url,
      "GIT_CONFIG_GLOBAL" => git_config
    })
  end

  def run_command!(*command, env: {}, chdir: nil)
    stdout, stderr, status = if chdir
      Open3.capture3(env, *command, chdir: chdir)
    else
      Open3.capture3(env, *command)
    end
    assert status.success?, <<~MESSAGE
      Command failed: #{command.join(" ")}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE

    [stdout, stderr, status]
  end

  def with_webhook
    server = TCPServer.new("127.0.0.1", 0)
    deliveries = []
    thread = Thread.new do
      client = server.accept
      request = +""
      request << client.gets until request.end_with?("\r\n\r\n")
      headers = request.split("\r\n")
      content_length = headers.filter_map { |line| line[/\AContent-Length: (\d+)\z/i, 1] }.first.to_i
      body = client.read(content_length)
      deliveries << JSON.parse(body)
      client.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
      client.close
    ensure
      server.close
    end

    yield "http://127.0.0.1:#{server.addr[1]}", deliveries
    thread.join
  ensure
    server&.close unless server&.closed?
  end

  def with_server
    port = pick_port
    base_url = "http://127.0.0.1:#{port}"
    original_host = Lore::Application.config.x.lore.host
    Lore::Application.config.x.lore.host = base_url
    log_path = Rails.root.join("tmp", "slack-demo-server.log")
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
    Lore::Application.config.x.lore.host = original_host if defined?(original_host)
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
