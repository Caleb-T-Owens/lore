require "test_helper"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "tmpdir"

class GitTransportEndToEndTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    return unless @owner_username

    FileUtils.rm_rf(File.join(Rails.application.config.x.lore.repo_root, @owner_username))
    User.where(username: [@owner_username, @contributor_username]).destroy_all
  end

  test "supports anonymous clone and fetch plus authenticated fast-forward-only pushes" do
    suffix = SecureRandom.hex(4)

    with_lore_test_server(log_name: "git-transport-server.log") do |base_url|
      owner = register_user(base_url, "owner#{suffix}")
      contributor = register_user(base_url, "agent#{suffix}")
      @owner_username = owner.dig("user", "username")
      @contributor_username = contributor.dig("user", "username")

      create_repo(base_url, owner.fetch("pat"), name: "push-demo", description: "Demo repo")

      Dir.mktmpdir("lore-git-transport") do |dir|
        clone_one = File.join(dir, "clone1")
        clone_two = File.join(dir, "clone2")
        public_remote = "#{base_url}/git/#{owner.dig("user", "username")}/push-demo.git"
        push_remote = "#{base_url.sub("http://", "http://#{contributor.dig("user", "username")}:#{contributor.fetch("pat")}@")}/git/#{owner.dig("user", "username")}/push-demo.git"

        run_command!("git", "clone", public_remote, clone_one)
        configure_git_identity!(clone_one)
        File.write(File.join(clone_one, "README.md"), "hello\n")
        run_command!("git", "-C", clone_one, "add", "README.md")
        run_command!("git", "-C", clone_one, "commit", "-m", "first commit")
        run_command!("git", "-C", clone_one, "push", push_remote, "HEAD:main")
        assert Repo.find_by!(name: "push-demo", owner: User.find_by!(username: @owner_username)).last_pushed_at.present?

        run_command!("git", "clone", public_remote, clone_two)
        configure_git_identity!(clone_two)

        File.write(File.join(clone_one, "one.txt"), "one\n")
        run_command!("git", "-C", clone_one, "add", "one.txt")
        run_command!("git", "-C", clone_one, "commit", "-m", "second commit")
        run_command!("git", "-C", clone_one, "push", push_remote, "HEAD:main")

        run_command!("git", "-C", clone_two, "fetch", "origin")

        File.write(File.join(clone_two, "two.txt"), "two\n")
        run_command!("git", "-C", clone_two, "add", "two.txt")
        run_command!("git", "-C", clone_two, "commit", "-m", "stale commit")
        _, stderr, status = run_command("git", "-C", clone_two, "push", push_remote, "HEAD:main")

        assert_not status.success?
        assert_includes stderr, "[rejected]"
        assert_includes stderr, "non-fast-forward"
      end
    end
  end

  private

  def register_user(base_url, username)
    post_json("#{base_url}/api/users", { username: username })
  end

  def create_repo(base_url, pat, name:, description:)
    post_json(
      "#{base_url}/api/repos",
      { name: name, description: description, tags: [ "demo" ] },
      headers: { "Authorization" => "Bearer #{pat}" }
    )
  end

  def post_json(url, payload, headers: {})
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    headers.each { |key, value| request[key] = value }
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }

    assert response.is_a?(Net::HTTPSuccess), "Expected success from #{url}, got #{response.code}: #{response.body}"

    JSON.parse(response.body)
  end

  def configure_git_identity!(path)
    run_command!("git", "-C", path, "config", "user.name", "Lore Test")
    run_command!("git", "-C", path, "config", "user.email", "lore-test@example.com")
  end

  def run_command!(*command)
    stdout, stderr, status = run_command(*command)

    assert status.success?, <<~MESSAGE
      Command failed: #{command.join(" ")}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE

    [ stdout, stderr, status ]
  end

  def run_command(*command)
    Open3.capture3({ "GIT_TERMINAL_PROMPT" => "0" }, *command)
  end
end
