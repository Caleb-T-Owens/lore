require "test_helper"
require "fileutils"
require "rack/mock"

class GitHttpMountTest < ActiveSupport::TestCase
  test "configures a local repo root" do
    repo_root = Rails.application.config.x.lore.repo_root

    assert_equal Rails.root.join("tmp", "lore-repos").to_s, repo_root
    FileUtils.mkdir_p(repo_root)
    assert Dir.exist?(repo_root)
  end

  test "mounts grack under git for upload-pack discovery" do
    repo_root = Rails.application.config.x.lore.repo_root
    owner = User.create!(username: "demo")
    repo = Lore::RepoProvisioner.create(
      owner: owner,
      params: {
        name: "tool",
        description: "Demo tool",
        tags: [ "demo" ]
      }
    )

    assert_predicate repo, :persisted?

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
