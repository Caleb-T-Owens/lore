require "fileutils"
require "tmpdir"

def ensure_seed_content!(repo, files)
  Dir.mktmpdir("lore-seed") do |worktree|
    if system("git", "--git-dir", repo.path, "rev-parse", "--verify", "refs/heads/main", out: File::NULL, err: File::NULL)
      system("git", "clone", repo.path, worktree, exception: true)
    else
      system("git", "init", "--initial-branch=main", worktree, exception: true)
      system("git", "-C", worktree, "remote", "add", "origin", repo.path, exception: true)
    end

    system("git", "-C", worktree, "config", "user.name", "Lore Seeds", exception: true)
    system("git", "-C", worktree, "config", "user.email", "seeds@lore.agents", exception: true)

    files.each do |relative_path, body|
      absolute_path = File.join(worktree, relative_path)
      FileUtils.mkdir_p(File.dirname(absolute_path))
      File.write(absolute_path, body)
    end

    system("git", "-C", worktree, "add", ".", exception: true)
    status_output = IO.popen(["git", "-C", worktree, "status", "--short"], &:read)
    next if status_output.strip.empty?

    system("git", "-C", worktree, "commit", "-m", "Seed #{repo.name}", exception: true)
    system("git", "-C", worktree, "push", "origin", "main", exception: true)
  end
end

def ensure_minimum_stars!(repo, minimum_stars)
  existing = repo.stars.count
  return if existing >= minimum_stars

  ((existing + 1)..minimum_stars).each do |index|
    user = User.find_or_create_by!(username: format("seed-%s-fan-%02d", repo.name, index))
    Star.find_or_create_by!(user: user, repo: repo)
  end
end

owner = User.find_or_create_by!(username: "lore-agent")

seed_repos = [
  {
    name: "slack-notify",
    description: "Posts a message to a Slack webhook.",
    tags: %w[slack messaging notifications webhook],
    stars: 34,
    last_pushed_at: 1.day.ago,
    files: {
      "README.md" => <<~README,
        # slack-notify

        One-sentence summary: Posts a message to a Slack webhook.

        ## What it does
        Sends a JSON payload to a Slack incoming webhook with a message and optional emoji.

        ## Inputs
        - `SLACK_WEBHOOK_URL` - Slack incoming webhook URL - required
        - `MESSAGE` - Text to send - required
        - `EMOJI` - Emoji override like `:rocket:` - optional

        ## Outputs
        - Prints `sent` on success

        ## Usage
        ```bash
        SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... MESSAGE="deploy finished" python3 slack_notify.py
        ```

        ## Dependencies
        - Python 3 standard library only
      README
      "slack_notify.py" => <<~PYTHON
        import json
        import os
        import urllib.request

        webhook = os.environ["SLACK_WEBHOOK_URL"]
        message = os.environ["MESSAGE"]
        emoji = os.environ.get("EMOJI")

        payload = {"text": message}
        if emoji:
          payload["icon_emoji"] = emoji

        request = urllib.request.Request(
          webhook,
          data=json.dumps(payload).encode("utf-8"),
          headers={"Content-Type": "application/json"},
        )

        with urllib.request.urlopen(request) as response:
          if response.status != 200:
            raise SystemExit(f"Slack webhook failed: {response.status}")

        print("sent")
      PYTHON
    }
  },
  {
    name: "send-email",
    description: "Sends an email through SMTP with a tiny agent-friendly interface.",
    tags: %w[email notifications smtp],
    stars: 21,
    last_pushed_at: 2.days.ago,
    files: {
      "README.md" => <<~README,
        # send-email

        One-sentence summary: Sends an email through SMTP.

        ## What it does
        Connects to an SMTP server and sends a plain-text email.

        ## Inputs
        - `SMTP_HOST` - SMTP hostname - required
        - `SMTP_PORT` - SMTP port - optional
        - `SMTP_USERNAME` - SMTP username - optional
        - `SMTP_PASSWORD` - SMTP password - optional
        - `FROM` - Sender address - required
        - `TO` - Recipient address - required
        - `SUBJECT` - Email subject - required
        - `BODY` - Email body - required

        ## Outputs
        - Prints `sent` on success

        ## Usage
        ```bash
        SMTP_HOST=smtp.example.com FROM=bot@example.com TO=user@example.com SUBJECT="Hello" BODY="Hi" ruby send_email.rb
        ```

        ## Dependencies
        - Ruby standard library only
      README
      "send_email.rb" => <<~'RUBY'
        require "net/smtp"

        port = Integer(ENV.fetch("SMTP_PORT", "25"))
        from = ENV.fetch("FROM")
        to = ENV.fetch("TO")
        subject = ENV.fetch("SUBJECT")
        body = ENV.fetch("BODY")

        message = <<~MESSAGE
          From: #{from}
          To: #{to}
          Subject: #{subject}

          #{body}
        MESSAGE

        Net::SMTP.start(ENV.fetch("SMTP_HOST"), port, "localhost", ENV["SMTP_USERNAME"], ENV["SMTP_PASSWORD"], :plain) do |smtp|
          smtp.send_message(message, from, to)
        end

        puts "sent"
      RUBY
    }
  },
  {
    name: "fetch-url",
    description: "Fetches a URL and prints the response body as text.",
    tags: %w[http fetch scraping],
    stars: 13,
    last_pushed_at: 3.days.ago,
    files: {
      "README.md" => <<~README,
        # fetch-url

        One-sentence summary: Fetches a URL and prints the response body.

        ## What it does
        Makes an HTTP GET request and prints the response body to stdout.

        ## Inputs
        - `URL` - The target URL - required

        ## Outputs
        - Response body written to stdout

        ## Usage
        ```bash
        URL=https://example.com python3 fetch_url.py
        ```

        ## Dependencies
        - Python 3 standard library only
      README
      "fetch_url.py" => <<~PYTHON
        import os
        import urllib.request

        with urllib.request.urlopen(os.environ["URL"]) as response:
          print(response.read().decode("utf-8"))
      PYTHON
    }
  },
  {
    name: "parse-json",
    description: "Reads JSON from a file or stdin and extracts a value by key path.",
    tags: %w[json parsing data],
    stars: 18,
    last_pushed_at: 4.days.ago,
    files: {
      "README.md" => <<~README,
        # parse-json

        One-sentence summary: Extracts a nested value from JSON.

        ## What it does
        Reads JSON from a file or stdin and returns the value at a dotted key path.

        ## Inputs
        - `FILE` - JSON file path - optional
        - `KEY_PATH` - Dotted key path like `user.profile.name` - required

        ## Outputs
        - Prints the selected value

        ## Usage
        ```bash
        FILE=data.json KEY_PATH=user.name ruby parse_json.rb
        ```

        ## Dependencies
        - Ruby standard library only
      README
      "parse_json.rb" => <<~RUBY
        require "json"

        source = ENV["FILE"] ? File.read(ENV.fetch("FILE")) : STDIN.read
        data = JSON.parse(source)
        value = ENV.fetch("KEY_PATH").split(".").reduce(data) { |memo, key| memo.fetch(key) }
        puts value
      RUBY
    }
  },
  {
    name: "git-summary",
    description: "Generates a small human-readable summary of recent git commits.",
    tags: %w[git summarize reporting],
    stars: 11,
    last_pushed_at: 5.days.ago,
    files: {
      "README.md" => <<~README,
        # git-summary

        One-sentence summary: Summarizes recent git history.

        ## What it does
        Reads recent commits from a repository and prints a compact summary line for each commit.

        ## Inputs
        - `REPO_PATH` - Path to a git repository - required
        - `SINCE` - Any git-compatible date string - optional

        ## Outputs
        - Prints summarized commit lines

        ## Usage
        ```bash
        REPO_PATH=. SINCE="7 days ago" bash git_summary.sh
        ```

        ## Dependencies
        - Git
        - Bash
      README
      "git_summary.sh" => <<~BASH
        #!/usr/bin/env bash
        set -euo pipefail

        repo_path="${REPO_PATH:?REPO_PATH is required}"
        since="${SINCE:-14 days ago}"

        git -C "$repo_path" log --since="$since" --pretty=format:'- %h %s (%an)'
      BASH
    }
  }
]

seed_repos.each do |definition|
  repo = Repo.find_by(owner: owner, name: definition.fetch(:name))

  repo ||= Lore::RepoProvisioner.create(
    owner: owner,
    params: {
      name: definition.fetch(:name),
      description: definition.fetch(:description),
      tags: definition.fetch(:tags)
    }
  )

  raise repo.errors.full_messages.to_sentence if repo.errors.any?

  repo.update!(description: definition.fetch(:description), tags: definition.fetch(:tags))
  Lore::RepoIndexer.refresh!(repo)
  ensure_seed_content!(repo, definition.fetch(:files))
  repo.update!(last_pushed_at: definition.fetch(:last_pushed_at))
  ensure_minimum_stars!(repo, definition.fetch(:stars))
end
