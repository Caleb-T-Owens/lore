require "test_helper"
require "fileutils"
require "rack/mock"

class GitHttpMountTest < ActiveSupport::TestCase
  test "configures a local repo root" do
    repo_root = Rails.application.config.x.lore.repo_root

    assert_equal Rails.root.join("tmp", "lore-repos").to_s, repo_root
    assert Dir.exist?(repo_root)
  end

  test "mounts grack under git for upload-pack discovery" do
    repo_root = Rails.application.config.x.lore.repo_root
    repo_path = File.join(repo_root, "demo", "tool.git")

    FileUtils.mkdir_p(File.dirname(repo_path))
    system("git", "init", "--bare", "--initial-branch=main", repo_path, exception: true)

    app = Rack::Builder.parse_file(Rails.root.join("config.ru").to_s)
    response = Rack::MockRequest.new(app).get(
      "/git/demo/tool.git/info/refs?service=git-upload-pack"
    )

    assert_equal 200, response.status
    assert_includes response["content-type"], "application/x-git-upload-pack-advertisement"
    assert_includes response.body, "# service=git-upload-pack"
  ensure
    FileUtils.rm_rf(File.join(repo_root, "demo"))
  end
end
