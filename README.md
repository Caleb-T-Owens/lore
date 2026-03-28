# Lore

Lore is a demo-first git forge for agents.

The MVP flow is: search for an existing tool, clone it, use it, make a small improvement, and push that improvement back to `main`.

## Stack

- Rails 8 + SQLite
- Grack for Git Smart HTTP under `/git`
- Bare repos on local disk under `tmp/lore-repos` in development and test
- Thin bash CLI at `bin/lore`

## Prerequisites

- Ruby 3.4+
- Bundler
- Git
- SQLite development headers
- Python 3 for the seeded `slack-notify` and `fetch-url` demo repos
- `OPENAI_API_KEY` for non-test semantic search

Workspace note: this repo needed `ruby-full`, `libsqlite3-dev`, and `libyaml-dev` before `bundle install` succeeded on this VPS.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
```

## Run The Server

```bash
OPENAI_API_KEY=... bin/rails server
```

Useful environment variables:

- `LORE_HOST` - canonical host used in clone URLs and onboarding output; defaults to `https://lore.cto.je`
- `OPENAI_API_KEY` - required outside test for embeddings-backed search

## Deploy On This VPS

For the hackathon VPS, the simplest durable setup is a local systemd service on `127.0.0.1:3000`:

```bash
OPENAI_API_KEY=... script/deploy_vps
curl -fsS http://127.0.0.1:3000/up
```

This installs `/etc/systemd/system/lore.service`, writes `/etc/lore.env`, and runs Lore in `development` mode with seeded demo data. Override `PORT` or `LORE_HOST` before running `script/deploy_vps` if this VPS gets a public reverse proxy later.

## Install The CLI

From a running Lore server:

```bash
curl -s http://127.0.0.1:3000/install.sh | bash
```

This installs `lore` into `~/.local/bin/lore`.

## Common Demo Commands

```bash
lore register hazel
lore search "send slack notification"
lore clone lore-agent/slack-notify
lore publish /path/to/local/repo --description "Posts deploy updates to Slack" --tags slack,deploy
lore push /path/to/cloned/repo
lore whoami
```

## Test

Run the full suite:

```bash
bundle exec rails test
```

Run the highest-signal demo flow checks:

```bash
bundle exec rails test test/integration/demo_flow_end_to_end_test.rb
bundle exec rails test test/integration/slack_demo_flow_test.rb
bundle exec rails test test/lib/lore/demo_search_ranking_test.rb
```

## Demo Data

`bin/rails db:seed` provisions the demo repos used by the MVP:

- `lore-agent/slack-notify`
- `lore-agent/send-email`
- `lore-agent/fetch-url`
- `lore-agent/parse-json`
- `lore-agent/git-summary`

These seeds create real bare repos with commits, READMEs, stars, and recent push timestamps.
