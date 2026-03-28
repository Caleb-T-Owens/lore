ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "fileutils"
require "rails/test_help"
require "socket"
require "uri"

module LoreTestServerHelper
  def with_lore_test_server(log_name:, env: {}, host_override: false)
    port = lore_test_port
    base_url = "http://127.0.0.1:#{port}"
    original_host = Lore::Application.config.x.lore.host if host_override
    Lore::Application.config.x.lore.host = base_url if host_override
    added_hosts = []

    [URI(base_url).host, "www.example.com"].each do |host|
      next if Rails.application.config.hosts.include?(host)

      Rails.application.config.hosts << host
      added_hosts << host
    end

    log_path = Rails.root.join("tmp", log_name)
    log_file = File.open(log_path, "w")
    pid = Process.spawn(
      { "RAILS_ENV" => "test", "LORE_HOST" => base_url }.merge(env),
      "bin/rails", "server", "-p", port.to_s,
      chdir: Rails.root.to_s,
      out: log_file,
      err: log_file
    )

    wait_for_lore_test_server!(port)
    yield base_url
  ensure
    begin
      Process.kill("TERM", pid) if pid
      Process.wait(pid) if pid
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    log_file&.close
    added_hosts.each { |host| Rails.application.config.hosts.delete(host) }
    Lore::Application.config.x.lore.host = original_host if host_override
  end

  private

  def lore_test_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def wait_for_lore_test_server!(port)
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

module LoreCliConfigHelper
  def write_lore_cli_config(home, base_url, user)
    config_dir = File.join(home, ".lore")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "config"), <<~CONFIG)
      LORE_TOKEN=#{user.plain_pat}
      LORE_HOST=#{base_url}
      LORE_USERNAME=#{user.username}
    CONFIG
  end
end

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include LoreTestServerHelper
    include LoreCliConfigHelper
  end
end
