require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class CheckPublicIngressScriptTest < ActiveSupport::TestCase
  SCRIPT_PATH = Rails.root.join("script", "check_public_ingress")
  GREEN_BODY = "<!DOCTYPE html><html><body style=\"background-color: green\"></body></html>"

  test "prints dns target hints when public dns is absent" do
    with_fake_commands(
      "getent" => <<~SH,
        #!/usr/bin/env bash
        exit 2
      SH
      "ip" => <<~SH,
        #!/usr/bin/env bash
        printf '2: eth0    inet 203.0.113.10/24 brd 203.0.113.255 scope global eth0\n'
      SH
      "curl" => <<~SH
        #!/usr/bin/env bash
        case "$*" in
          *"http://127.0.0.1/up"*) printf '%s' '#{GREEN_BODY}' ;;
          *) exit 1 ;;
        esac
      SH
    ) do |bin_dir|
      stdout, stderr, status = run_script(bin_dir)

      assert_not status.success?
      assert_includes stderr, "[blocker] dns: lore.cto.je does not resolve yet"
      assert_includes stdout, "[hint] dns-target: point lore.cto.je at 203.0.113.10"
      assert_includes stdout, "[hint] expected-ip: rerun with EXPECTED_IP=203.0.113.10"
      assert_includes stdout, "[ok] local-proxy: local ingress responds for lore.cto.je"
      assert_includes stdout, "[check] https: skipped until DNS resolves"
      assert_includes stderr, "Blocker summary: public ingress is not fully ready for lore.cto.je"
    end
  end

  test "fails when dns resolves to the wrong expected ip" do
    with_fake_commands(
      "getent" => <<~SH,
        #!/usr/bin/env bash
        printf '198.51.100.8 STREAM lore.cto.je\n198.51.100.8 DGRAM lore.cto.je\n'
      SH
      "curl" => <<~SH
        #!/usr/bin/env bash
        case "$*" in
          *"http://127.0.0.1/up"*|*"https://lore.cto.je/up"*) printf '%s' '#{GREEN_BODY}' ;;
          *) exit 1 ;;
        esac
      SH
    ) do |bin_dir|
      stdout, stderr, status = run_script(bin_dir, "EXPECTED_IP" => "203.0.113.10")

      assert_not status.success?
      assert_includes stdout, "[ok] dns: lore.cto.je resolves to 198.51.100.8"
      assert_includes stderr, "[blocker] dns-target: expected IP 203.0.113.10 is missing from 198.51.100.8"
      assert_includes stdout, "[ok] https: public HTTPS health check passed"
      assert_includes stderr, "Blocker summary: public ingress is not fully ready for lore.cto.je"
    end
  end

  private

  def run_script(bin_dir, env = {})
    Open3.capture3(
      {
        "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
        "PUBLIC_HOST" => "lore.cto.je",
        "LOCAL_CHECK_URL" => "http://127.0.0.1/up",
        "CONNECT_TIMEOUT" => "1",
        "MAX_TIME" => "1"
      }.merge(env),
      SCRIPT_PATH.to_s
    )
  end

  def with_fake_commands(commands)
    Dir.mktmpdir("check-public-ingress-bin") do |bin_dir|
      commands.each do |name, body|
        path = File.join(bin_dir, name)
        File.write(path, body)
        FileUtils.chmod("u+rwx", path)
      end

      yield bin_dir
    end
  end
end
