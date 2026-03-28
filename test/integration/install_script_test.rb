require "test_helper"

class InstallScriptTest < ActionDispatch::IntegrationTest
  test "serves a shell installer for the lore cli" do
    get install_script_path

    assert_response :success
    assert_equal "application/x-sh", response.media_type
    assert_includes response.body, 'target_path="${install_dir}/lore"'
    assert_includes response.body, 'cat > "$target_path" <<'"'"'__LORE_CLI__'"'"''
    assert_includes response.body, "LORE_HOST_DEFAULT=\"${LORE_HOST:-#{Lore::Application.config.x.lore.host}}\""
    assert_includes response.body, "Installed lore to %s"
  end
end
