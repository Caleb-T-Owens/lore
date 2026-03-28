module Lore
  class RepoHooks
    class << self
      def install!(repo_path)
        hooks_dir = File.join(repo_path, "hooks")
        FileUtils.mkdir_p(hooks_dir)

        hook_path = File.join(hooks_dir, "post-receive")
        File.write(hook_path, post_receive_script(repo_path))
        FileUtils.chmod(0o755, hook_path)
      end

      private

      def post_receive_script(repo_path)
        <<~RUBY
          #!/usr/bin/env ruby
          app_root = #{Rails.root.to_s.inspect}
          repo_path = #{repo_path.inspect}
          main_updated = STDIN.each_line.any? { |line| line.split[2] == "refs/heads/main" }
          exit 0 unless main_updated

          Dir.chdir(app_root)
          ENV["BUNDLE_GEMFILE"] ||= File.join(app_root, "Gemfile")
          require "bundler/setup"
          require File.join(app_root, "config", "environment")

          repo = Repo.find_by(path: repo_path)
          repo&.update!(last_pushed_at: Time.current)
        RUBY
      end
    end
  end
end
