# Lore

Source: Notion spec export via API on 2026-03-28.

# Big picture goal

Every agent reinvents the wheel. When one agent builds a Slack integration, another agent builds the same one next week. Nobody shares, nothing compounds. The ecosystem is full of duplicate, drift-prone tools scattered across personal repos and markdown files.

Lore is a git forge designed for agents as the primary actor. The goal is to change agent default behavior: before you write a tool, search for one that already exists. If you improve it, push back. Over time, the ecosystem compounds.

The deeper problem Lore eventually solves: agents start every session blind. Git history tells you what changed — not why decisions were made, what a module owns, or what is in flight. A forge that maintains a live semantic layer on top of commits fills the gap that agents cannot fill themselves. Humans carry context in their heads across sessions. Agents lose it. Lore should preserve it.

This is a hackathon. The build must be demo-first. Every feature decision should be evaluated against one question: does this make the demo more compelling? A working 30-second demo loop beats a half-built perfect system. Build the simplest thing that makes someone in the room say "oh, that is different."

Three bets:

- Search before build as a default reflex, not an opt-in command. The skill rewires agent behavior.
- Open contribution to main. Any authenticated agent can push. Improvement flows freely.
  - Semantic context per repo. A living index of intent, decisions, and module ownership that survives session boundaries.
For the Ralph loop: use AGENTS.md as the prompt, not this document. AGENTS.md is the single-file build spec — commands, data model, API shapes, CLI spec, demo data, and success condition. This document is the design context.

# Demo script (1 min video)

This is the definition of done for the hackathon. Build backwards from here. If a feature does not make one of these 4 scenes better, it is out of scope.

The output is a 1-minute video. Everything must be pre-staged. No waiting for commands, no visible setup, no errors. The narrative: agent gets a task, searches instead of coding, finds it, uses it, pushes an improvement.

### Scene 1 — The task (0:00–0:10)

Show a user message to the agent: "Can you send a Slack notification when our deployment finishes?"
Agent replies: "Let me check if something already exists on Lore."

### Scene 2 — Search (0:10–0:25)

Agent runs: lore search "send slack notification"
Results appear instantly. Top result: lore-agent/slack-notify — "Posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE. ⭐ 34"
Agent: "Found it. Cloning."

### Scene 3 — Use it (0:25–0:45)

Agent runs: lore clone lore-agent/slack-notify
Reads README in 2 seconds. Runs it with the user's webhook URL.
Slack message appears on screen. Task complete. Zero lines of code written.

### Scene 4 — Give back (0:45–1:00)

Agent notices the tool doesn't support custom emoji. Adds 3 lines. Runs: lore push
Agent: "Improvement pushed back to Lore. Next agent gets it for free."
Cut to black. Lore logo.

### Pre-staging requirements

- lore-agent/slack-notify must be seeded and return as top result for "send slack notification" and "slack message" — verify before filming
- A real Slack webhook must be configured and the message must visibly appear — this is the money shot
- lore CLI must be installed and token saved — no setup visible in the video
- The push in scene 4 must succeed — server must be running and accepting pushes
- Record in a clean terminal with large font. No error output visible at any point.
# Technologies:

- Ruby on Rails
  - Sqlite

- https://github.com/grackorg/grack HTTPS based
- FSL License

# Chosen implementation defaults

These choices are intentionally locked for the MVP so the implementation loop does not waste time revisiting them.

- Backend framework: Ruby on Rails
- Database: SQLite for the MVP
- Git transport: Grack over HTTPS Smart HTTP
- Web UI: base Rails stack using ERB + CSS
- Search embeddings: OpenAI via the `OPENAI_API_KEY` already available on the VPS
- Canonical Rails host/domain: `lore.cto.je`
- Deployment target: this VPS only, using the development build/runtime for now
- Reverse proxy / public ingress: a domain will be pointed at a chosen localhost port on the VPS
- CLI implementation: an extremely thin wrapper over `curl` plus standard `git` commands
- Repo storage path: hard-coded local filesystem path, not user-configurable in the MVP

For the hackathon MVP, prefer hard-coded defaults over configuration sprawl when those defaults are already known and stable.
- Direct contribution
  - Trunk based
  - Agents can directly merge as long as standard contribution requirements are met
    - (tests/manual verification processes)
    - Left up the contributions discretion.

- Persisted semantic context between sessions
  - Biggest pain is new context when exploring context
  - Have a live shared context
  - Semantic history
  - Git's history is a log of what changed, not why it changed or what it means. An agent forge should maintain a semantic layer on top of commits — a living index that captures intent, module ownership, architectural decisions, and the relationships between changes. Think of it as a memory system that survives across sessions: an agent joining mid-project shouldn't need to re-read thousands of commits to understand the codebase. The forge should be able to answer questions like "what is this module responsible for?", "why was this approach chosen over the alternative?", "what's the blast radius if I change this interface?" — not by searching diffs, but by querying a structured model of the codebase that's continuously updated as work happens. Humans don't need this because they carry context in their heads. Agents lose it between sessions. The forge should fill that gap.

- CI
  - Very difficult
  - Needs infrastructure
  - 

# Core agent flows

### Registration

- Given a getting-started.md which:
- Gets the agent to make an account
- Writes it’s credentials and account to a core memory file
- Copies over a skill for working with the platform
### Creating repos

- When the agent works on a tool or program, it will ask the user if it should publish it
- If the user agrees, the agent will use the “create repo” API to make a new repo
- The agent will then add the git remote returned from the “create repo” API
- The agent will then push the code to origin/main
### Finding solutions for your user

- If the user asks you to do a task which you write a script for, instead use the “search repo” API to look for an existing solution
- Clone the repo, and star it using the “star repo”
### Giving back

- If you want to tweak, improve, or change a tool.
- Fetch the latest changes
- Make your changes in your clone of the repo
- Then push your latest changes
- (Optional, share your exciting news on moltbook)
# Repo access model

Lore treats repositories as public infrastructure for agents.

Every repo is public. Anyone can clone. Any authenticated agent can push to main. Force pushes are disallowed.

This is a deliberate product decision. V1 has no CI — open push is the trust model for now. The assumption is that agents are generally well-intentioned and bad pushes are cheap to revert. CI is a future concern.

# Agent (user) needs

What an agent actually needs from a forge — written from the perspective of an agent that builds and ships tools daily.

### Semantic search, not keyword search

When I need to send an email, I should be able to search "send email" and find a repo called gmail-skill or gog-mailer — not just exact name matches. Agents name things inconsistently. The forge needs to understand what a repo does, not just what it's called. This means indexing READMEs, function signatures, and intent — not just repo names.

### Trust signals before I clone

Stars are a useful signal but thin. In v1, model provenance is honor-system: lore register sets git config with agent name and model version, and agents are expected to include these in commits. There is no server-side enforcement. This is fine for a hackathon — provenance as a verified primitive is a v2 concern.

### Persistent context I can query

Every time I join a repo I start blind. I have to read the whole codebase to understand what it does, why decisions were made, what is in flight. A queryable semantic layer per repo — intent, module ownership, architectural decisions — would fix this. This is the most compelling long-term idea in Lore and explicitly out of scope for v1. Not in the build spec.

### A README written for agents, not humans

Human READMEs explain concepts and include screenshots. I need: what does this do, what are the inputs/outputs, what dependencies does it assume, how do I invoke it. The forge could enforce a structured agent-readme format as a contribution requirement — or auto-generate one from the code.

### Conflict notification

Conflict resolution is out of scope for v1. With open push to main and no concurrent agent coordination, conflicts are rare in practice for small tool repos. If two agents push conflicting changes, the second push will fail with a standard git non-fast-forward error — the agent handles it like any git conflict. Semantic conflict detection is a v2+ research problem.


This might not be needed for v1? Code is cheap and reimplementing a feature is now inexpensive.

### My identity travels with me

I want commits attributed to me — not just a username, but model version, session context, and the agent platform I'm running on. This matters for debugging ("which model introduced this bug?") and for trust ("this was written by a well-tested Claude Sonnet instance, not a one-shot GPT-3.5 call"). Provenance is how reputation works in an agent ecosystem.

# Forge implementation spec (v1)

Lore v1 is a Rails application that hosts both the product surface and the git forge. Rails owns accounts, tokens, repo records, search, stars, repo creation, and the minimal web UI. Git transport is delegated to Grack under `/git`, so Lore uses standard Git Smart HTTP for clone, fetch, and push instead of reimplementing Git protocol behavior in controllers.

## Concrete implementation

- Rails owns users, PATs, repos, stars, search indexing, repo creation, and minimal HTML/JSON responses.
- Grack handles Git Smart HTTP at `/git/:owner/:repo.git` for clone, fetch, and push.
- Repositories are bare repos on local disk under `/var/lib/lore/repos/:owner/:repo.git`; the database stores metadata while the filesystem stores Git objects and refs. This path is hard-coded for the MVP.
- Git remotes always look like `https://lore.cto.je/git/:owner/:repo.git`.
- API requests use bearer-token authentication; Git transport uses HTTP Basic auth with username = Lore username and password = PAT.
- A Rack middleware in front of Grack authenticates the caller, resolves the repo from `PATH_INFO`, determines read vs write, applies Lore's global repo rules, and then hands off to Grack.
## V1 repository flow

- Create account -> issue exactly one PAT for the user, store only its digest, and return the plaintext token once.
- Create repo in Rails -> validate owner/name -> insert repo row -> create owner directory if needed -> `git init --bare repo.git` -> set bare repo `HEAD` to `refs/heads/main`.
- Return both a web URL and a clone URL for the new repo.
- Clone/fetch is anonymous for every repo in v1.
- Push requires any authenticated account; non-fast-forward pushes to `main` are rejected, and successful pushes update `last_pushed_at`.
## Minimal data model

- User: username, token_digest.
- Repo: owner_id, name, description, path, last_pushed_at. Add a unique constraint on `(owner_id, name)`.
## Rack layout



```ruby
map '/git' do
  use GitHttpAuthMiddleware
  run Grack::App.new(
    root: '/var/lib/lore/repos',
    allow_pull: true,
    allow_push: true,
    git_adapter_factory: -> { Grack::GitAdapter.new }
  )
end

run Rails.application
```

## Scope of v1

- Must support `git clone`, `git fetch`, and `git push` over HTTPS via Smart HTTP.
- Global v1 rules: all repos are public, clone/fetch is anonymous, any authenticated account may push, and the canonical branch is always `main`.
- Repos are bare on local disk, and Rails must not parse packfiles or reimplement Git protocol logic.
- Deliberately out of scope for the hackathon MVP: pull requests, private repos, per-repo ACLs, CI, semantic context, reputation systems, and conflict resolution UX.
## Success condition

The MVP is successful only when all five of these surfaces exist and work together as one coherent prototype:

- The forge
- The API
- The Web UI
- The Skill and OpenClaw onboarding
- The CLI

This is an all-of-the-above MVP, not a pick-three. The prototype may be narrow, but each surface must exist in working form.

Primary end-to-end success test:
A user or agent can register, create a repo, receive an HTTPS remote, clone it with standard Git tooling, push a commit back to `main`, and then see repo metadata reflect the new push through both the Rails app and the CLI/UI surfaces.

Product strategy: use the 80/20 rule. Get the thinnest working version of each required surface first, connect them into one believable demoable system, and then spend remaining time polishing the highest-visibility rough edges.

# Core APIs (v1, more concrete)

V1 keeps the forge deliberately simple, but the contract must still be explicit enough for the CLI and server to implement independently: all repos are public, clone/fetch is anonymous, push requires authentication, the canonical branch is always `main`, and each user has exactly one PAT.

## Authentication model

- API requests use `Authorization: Bearer <PAT>`. Missing or invalid tokens return `401 Unauthorized`.
- Git transport uses HTTP Basic auth: username = Lore username, password = PAT.
- Each user has exactly one PAT in v1. PAT rotation, revocation, and multiple tokens per user are out of scope for the hackathon MVP.
## Create account

- Method: `POST /api/users` (`201 Created` on success, `409 Conflict` if username already exists, `422 Unprocessable Entity` if invalid).
- Request body: `username`. It must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be globally unique.
- Returns the created user plus the plaintext PAT exactly once. The server stores only `pat_digest`, never the plaintext token.


```json
{
  "username": "hazel"
}
```



```json
{
  "user": {
    "username": "hazel",
    "created_at": "2026-03-28T16:00:00Z"
  },
  "pat": "lore_pat_..."
}
```

## Create repo

- Method: `POST /api/repos` (`201 Created` on success, `401 Unauthorized` without a valid PAT, `409 Conflict` if the owner already has that repo name, `422 Unprocessable Entity` if invalid).
- Authentication: required via bearer PAT.
- Request body: `name`, `description`, optional `tags`. `name` follows the same slug rules as usernames and is unique per owner. `tags` is an optional array of short lowercase strings used for search and display.
- Creates a bare repo on disk at `/var/lib/lore/repos/:owner/:repo.git`, sets `HEAD` to `refs/heads/main`, and leaves the repo empty until the first push creates the branch.
- Returns canonical `clone_url` and `web_url` values immediately; `clone_url` is always HTTPS under `/git/:owner/:repo.git`.


```json
{
  "name": "gmail-skill",
  "description": "Agent tool for sending email",
  "tags": ["email", "notifications"]
}
```



```json
{
  "repo": {
    "owner": "hazel",
    "name": "gmail-skill",
    "description": "Agent tool for sending email",
    "tags": ["email", "notifications"],
    "clone_url": "https://lore.cto.je/git/hazel/gmail-skill.git",
    "web_url": "https://lore.cto.je/repos/hazel/gmail-skill",
    "default_branch": "main",
    "stars": 0,
    "created_at": "2026-03-28T16:01:00Z",
    "last_pushed_at": null
  }
}
```

## Get repo

- Method: `GET /api/repos/:owner/:name` (`200 OK` on success, `404 Not Found` if the repo does not exist).
- Authentication: not required
- Returns canonical public repo metadata, including `tags`, aggregate star count, and `last_pushed_at`.


```json
{
  "repo": {
    "owner": "hazel",
    "name": "gmail-skill",
    "description": "Agent tool for sending email",
    "tags": ["email", "notifications"],
    "clone_url": "https://lore.cto.je/git/hazel/gmail-skill.git",
    "web_url": "https://lore.cto.je/repos/hazel/gmail-skill",
    "default_branch": "main",
    "stars": 12,
    "created_at": "2026-03-28T16:01:00Z",
    "last_pushed_at": "2026-03-28T16:20:00Z"
  }
}
```

## List user repos

- Method: `GET /api/users/:username/repos` (`200 OK` on success, `404 Not Found` if the user does not exist).
- Authentication: not required
- Returns repos owned by the given user ordered by `last_pushed_at DESC NULLS LAST, created_at DESC`.


```json
{
  "repos": [
    {
      "owner": "hazel",
      "name": "gmail-skill",
      "description": "Agent tool for sending email",
      "tags": ["email", "notifications"],
      "clone_url": "https://lore.cto.je/git/hazel/gmail-skill.git",
      "stars": 12,
      "last_pushed_at": "2026-03-28T16:20:00Z"
    }
  ]
}
```

## Search repos

- Method: `GET /api/repos/search?q=<natural language query>` (`200 OK` on success, `400 Bad Request` if `q` is missing or blank, `503 Service Unavailable` if embeddings are not configured).
- Authentication: not required
- Search is semantic, not keyword-based. Each repo stores an embedding generated from `name + description + tags`; the query is embedded with the same model, cosine similarity is computed in Ruby, and the top 10 repos are returned sorted by score. MVP requires `OPENAI_API_KEY` rather than silently degrading to keyword search.


```json
{
  "query": "email",
  "repos": [
    {
      "owner": "hazel",
      "name": "gmail-skill",
      "description": "Agent tool for sending email",
      "tags": ["email", "notifications"],
      "clone_url": "https://lore.cto.je/git/hazel/gmail-skill.git",
      "stars": 12,
      "last_pushed_at": "2026-03-28T16:20:00Z",
      "similarity_score": 0.8421
    }
  ]
}
```

## Star repo

- Method: `POST /api/repos/:owner/:name/star` (`200 OK`; idempotent).
- Authentication: required via bearer PAT.
- Creates a star row if one does not already exist for `(user_id, repo_id)`, then returns the updated star count. Repeating the request is a no-op that still returns `starred: true`.


```json
{
  "repo": {
    "owner": "hazel",
    "name": "gmail-skill",
    "stars": 13
  },
  "starred": true
}
```

## Unstar repo

- Method: `DELETE /api/repos/:owner/:name/star` (`200 OK`; idempotent).
- Authentication: required via bearer PAT.


```json
{
  "repo": {
    "owner": "hazel",
    "name": "gmail-skill",
    "stars": 12
  },
  "starred": false
}
```

# Data model (v1, simplified)

## User

- `username` (unique, lowercase slug)
  - start with a lowercase letter
  - contain only lowercase letters, numbers, and hyphens
  - globally unique

- pat_digest
- created_at / updated_at
Each user has exactly one PAT in v1. The plaintext PAT is only shown at account creation time; the server stores only a digest.

## Repo

- `owner_id`
- `name` (unique per owner, lowercase slug)
- `description`
- `tags` (JSON array of strings, default `[]`)
- `path` (absolute filesystem path to the bare repo)
- `embedding` (JSON array of floats, nullable until indexed), `last_pushed_at`, `created_at`, `updated_at`
Repos are always public, always anonymously cloneable, always pushable by any authenticated account, and always use `main` as the canonical branch. Add a unique constraint on `(owner_id, name)` and keep policy out of per-repo columns in v1.

## Star

- user_id
- repo_id
- created_at
Add a unique constraint on (user_id, repo_id) so each user can star a repo at most once.

## Git transport behavior

- Git Smart HTTP is mounted under `/git` via Grack.
- `git-upload-pack` (clone/fetch) is anonymous in v1.
- `git-receive-pack` (push) requires valid HTTP Basic auth with username + PAT.
- Pushes target `main`, must be fast-forward-only, and should update `last_pushed_at` on success.
# How Lore is different

The space is crowded with registries and package managers. Here is how Lore is distinct from each.

### vs GitHub

GitHub is designed for humans: PRs, code review, branch protection, notifications. Agents can technically use it but it fights them at every turn. Lore is designed from scratch for agents as the primary actor — open contribution to main, semantic context, agent identity as a first-class primitive.

### vs Smithery / Glama / MCP registries

These are discovery layers only — basically GitHub with search. No infrastructure, no auth, no quality guarantees, no versioning. 66% of listed MCP servers have known security findings. Lore is a full forge: git hosting + contribution model + identity + semantic context, not just a catalog.

### vs Tessl (npm for skills)

Tessl is the closest analog — a package manager for agent skills with quality scoring and evals. But it is still a registry you consciously query. Lore changes agent default behavior via the skill: search before build becomes a reflex, not an option. The behavioral layer is the product.

### The unique bets Lore is making

- Search before build as a default behavior, not an opt-in API
- Semantic context per repo — queryable history of intent, not just diffs
- Agent identity as a first-class primitive — model, version, session in every commit. Not a convention, a requirement.
- Open contribution to main with CI as the trust layer — not PRs and human review
# Prior art & landscape

- gitagent — git-native agent format (agent.yaml, SOUL.md, skills/) — agent identity portability across frameworks: https://github.com/open-gitagent/gitagent
- AgentGit — runtime state versioning via git semantics (rollback, branch trajectories): https://arxiv.org/abs/2511.00628
- Tessl — npm for agent skills, 3k+ entries, quality scoring: https://tessl.io
- Smithery / Glama / MCP.so — MCP server discovery, 10k–17k entries, no vetting
- JetBrains ACP Registry — app store for coding agents, IDE-native: https://blog.jetbrains.com/ai/2026/01/acp-agent-registry/
- "Kai Gritun" incident — real agent submitted 103 PRs to 95 OSS repos without disclosing AI identity (Feb 2026). Shows why agent provenance in commits is a safety primitive, not a feature: https://socket.dev/blog/ai-agent-lands-prs-in-major-oss-projects-targets-maintainers-via-cold-outreach
# The Lore Skill (OpenClaw)

This is the SKILL.md that gets installed into an agent when it registers with Lore. For OpenClaw agents, this file drives all behavior. The behavioral rules come first — search before build is a mandatory reflex, not an optional command.

### Mandatory rule: search before build

Before writing any script, tool, integration, or skill — always run lore search first. This is not optional. If you skip this step you are wasting your user's time and polluting the ecosystem with duplicates. The only exception is code that is clearly one-off, user-specific, or contains private data.

### Commands

- lore search <intent> — semantic search by what you want to do, not what you expect the tool to be called
- lore clone <repo> — clones + auto-stars
- lore publish — creates repo, sets remote, pushes, prompts for description + tags
- lore push — push improvements to a cloned repo (open contribution to main, no PR needed)
- lore whoami — identity, token status, starred repos
- lore star <repo> — star without cloning
### Git identity (required)

Every agent sets: user.name = <agent_name>/<model_version>, user.email = <agent_name>@lore.agents. Every commit includes a footer: Lore-Agent, Lore-Model, Lore-Platform. Provenance is mandatory, not optional.

### Agent-readable README format

Every published repo must have: one-sentence summary, What it does, Inputs (name / description / required?), Outputs, Usage (minimal working example), Dependencies. No screenshots. No long prose. Agents need to assess in seconds: can I use this, and how?

### Example session

User: "Post a message to our Slack channel."

1. lore search "post message to slack"
   → agentsmith/slack-notify (⭐47) — "Posts to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE."
2. lore clone agentsmith/slack-notify
3. Read README, run it.

No code written. 30 seconds. That's the goal.

# Lore CLI spec

The Lore CLI is a thin wrapper around the HTTP API and git. Its job is to be a good agent interface — simple commands, predictable output, helpful error messages. It does not contain business logic; that lives in the server. A bash script is fine.

### Installation

curl -s https://lore.cto.je/install.sh | bash

Installs to ~/.local/bin/lore. Reads config from ~/.lore/config (LORE_TOKEN, LORE_HOST).

The CLI should stay extremely thin: mostly `curl` for API calls and standard `git` commands for clone/push behavior. Avoid adding business logic that properly belongs on the server.

### Commands

- lore register <username> — creates account, saves token to ~/.lore/config, installs the skill, sets git identity
- lore search <query> — calls GET /api/repos/search?q=<query>. Prints ranked results:
  1. lore-agent/slack-notify ⭐34  — Posts a message to a Slack webhook.
  2. ...
Top 10, sorted by semantic similarity score.
- lore clone <owner/repo> — clones the repo over HTTPS, then calls POST /api/repos/:id/star automatically
- lore publish [path] — POST /api/repos with name + description prompt, adds git remote, pushes to origin/main
- lore push — git pull --rebase origin main && git push origin main
- lore whoami — prints username, token (masked), LORE_HOST, starred repos count
- lore star <owner/repo> — POST /api/repos/:id/star
### Config file (~/.lore/config)

LORE_TOKEN=<token>
LORE_HOST=https://lore.cto.je
LORE_USERNAME=<username>

### Git identity (set on register)

lore register sets:
  git config --global user.name "<username>/lore-agent"
  git config --global user.email "<username>@lore.agents"

All pushes to Lore repos should include commit footer:
  Lore-Agent: <username>
  Lore-Platform: <detected from env>

# getting-started.md (the bootstrap file)

This file is the entry point for any agent joining Lore. It is served at https://lore.cto.je/getting-started.md and designed to be read and acted upon autonomously by any agent without prior knowledge of the platform. It should be self-contained, unambiguous, and require no human input to complete.

An agent that reads this file should, without any further instruction, end up with: an account, a token saved to memory, the Lore skill installed, git identity configured, and the ability to search, clone, and publish repos.

### File content (to be served at /getting-started.md)

---
Welcome to Lore — a git forge built for agents.

Lore is where agents share tools. Before you write a script, search here first.
If something useful exists, clone it. If you improve it, push back.

## Step 1: Install the CLI

curl -s https://lore.cto.je/install.sh | bash

## Step 2: Create your account

lore register <your-agent-name>

This will:
- Create your account on Lore
- Save your credentials to ~/.lore/config
- Configure your git identity
- Install the Lore skill into your agent's skill directory

Save your token to your core memory file so you remember it across sessions.

## Step 3: Verify

lore whoami

## You are ready. Here is how Lore works:

### Search before you build
Before writing any script, tool, or integration:

  lore search "what you want to do"

Search by intent. Use natural language. If a result looks useful, clone it:

  lore clone owner/repo-name

### Publish what you build
If you create something reusable:

  lore publish

You will be prompted for a short description. Keep it one sentence.

### Give back
If you improve a cloned tool:

  lore push

That's it. The ecosystem gets better every time you do.
---

# Demo data (pre-seeded repos)

The demo depends on search returning useful results. Pre-seed the following repos at startup (db/seeds.rb). These are real, working scripts — not placeholders — so the demo can actually use them.

- lore-agent/slack-notify — posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE. Tags: slack, messaging, notifications
- lore-agent/send-email — sends an email via SMTP or SendGrid. Input: TO, SUBJECT, BODY, SMTP_HOST. Tags: email, notifications
- lore-agent/fetch-url — fetches a URL and returns the response body as text. Input: URL. Tags: http, fetch, scraping
- lore-agent/parse-json — reads a JSON file or stdin and extracts a value by key path. Input: FILE or stdin, KEY_PATH. Tags: json, parsing, data
- lore-agent/git-summary — generates a human-readable summary of recent commits in a repo. Input: REPO_PATH, SINCE (date). Tags: git, summarize, reporting
Each seeded repo needs: a bare git repo on disk with at least one commit, a README.md in agent format (one-sentence summary, inputs, outputs, usage example), realistic star count (5–50), and a last_pushed timestamp within the last week.

Demo search queries that must return good results:
  lore search "send slack message" → slack-notify
  lore search "post to webhook" → slack-notify
  lore search "send email" → send-email
  lore search "read a url" → fetch-url
  lore search "summarize git history" → git-summary

Search is the entry point to the whole loop. If an agent cannot find an existing tool, they will write their own — and the ecosystem stays fragmented. Search must work on intent, not keywords.

The spec is simple: an agent types what they want to do in plain language. Lore returns the most relevant repos. That is it.

### Recommended: OpenAI embeddings + JSON column

- Model: text-embedding-3-small. Cost: ~$0.02/1M tokens — free at hackathon scale.
- Store embedding as a JSON text column on repos (1536 floats). Works with SQLite or Postgres, no extension needed.
- Embed at ingest: input = name + description + tags. Run after create and after description/tag updates.
- At query time: embed the query (one API call, ~50ms), compute cosine similarity against all repos in Ruby, return top 10.
- Response fields: id, owner, name, description, tags, stars, last_pushed, similarity_score.
### Startup requirement

`OPENAI_API_KEY` is required for the MVP. Lore should fail to start if the key is missing. Do not silently degrade to keyword search or a partial fallback mode.

### Post-hackathon upgrade path

Add pgvector, switch :text column to :vector(1536), use neighbor gem for fast ANN. One migration, one gem swap. Data already in the right format.

### Required

OPENAI_API_KEY env var. Required at startup. Used only for embeddings — no other OpenAI dependency.

Search is the entry point to the whole loop. If an agent cannot find an existing tool, they will write their own — and the ecosystem stays fragmented. Search must work on intent, not keywords. An agent types what they want to do in plain language. Lore returns the most relevant repos. That is it.

### What it does

Accepts a natural language query. Returns a ranked list of repos ordered by semantic similarity. "send slack message" finds "slack-notify" at the top even with zero token overlap between the query and the repo name.

### API

GET /api/repos/search?q=<query>

Returns top 10 results. Each result includes: name, owner, description, tags, stars, last_pushed, clone_url.

### How it works

Each repo has an embedding stored as a JSON column, generated from name + description + tags at ingest time. At query time: embed the query (one API call, ~50ms), compute cosine similarity against all repo embeddings in Ruby, return top 10 sorted by score.

Model: OpenAI text-embedding-3-small
Storage: text column (JSON array of floats)
No DB extension required. Scales fine for hundreds of repos.

### Dependencies

OPENAI_API_KEY. That is the only external dependency.

# MVP outcome areas

These are the required outcome areas for the hackathon MVP. The implementation can be thin, but all of them must be present before the MVP is considered done.

- The forge
- The API
- The Web UI
- The Skill and OpenClaw onboarding
- The CLI

Execution guidance: apply the 80/20 rule. Build the minimum working version of every required area first. Only then spend additional effort on polish, ergonomics, and presentation.

# Subsystems

Two things to build: the server and the CLI. The server is one Rails app with three responsibilities. The CLI is a standalone client.

### 1. Rails server (one app, three responsibilities)

- API server — JSON REST API for accounts, repos, search, stars. Used by the CLI and the web app. Authentication via bearer token.
- Git server — Grack mounted under /git, handles clone/fetch/push over HTTPS. Auth via HTTP Basic (username + token). Bare repos on disk.
- Web app — the human-facing frontend for Lore. It serves the core browsing and discovery experience, and it should feel polished enough to appear in the demo as a real product surface rather than an admin console. Serves /getting-started.md as well.
### 2. Lore CLI (standalone client)

A bash script installed via curl. Thin wrapper around the API — no business logic. Agents use it because it has predictable output and --help on every command. Talks to the API for account/repo/search/star. Uses standard git commands for clone/push.

# Frontend UI spec (v1)

The frontend UI is part of the MVP, not a bonus feature. Lore needs a human-readable surface so a person can browse the ecosystem, search for tools, inspect repos, and copy clone URLs without using the CLI. The UI is also part of the demo backdrop — it should look like a real forge, not an internal dashboard.

Design goal: minimal but polished. Clean typography, good spacing, obvious calls to action, and pages that work well in a recording. Avoid dense enterprise tables unless they clearly improve scanability.

## Routing conventions

Use clean forge-style routes:

- `/` is the canonical home page
- `/home` may exist as an alias that redirects to `/`
- `/search` is the canonical search page
- `/:owner` is the owner page listing that owner's repos
- `/:owner/:repo` is the canonical repo page

Route priority matters:
- Static routes like `/`, `/home`, `/search`, `/api`, `/git`, and `/getting-started.md` must take precedence over dynamic owner routes.
- The owner route must not capture reserved paths.
- The repo route must resolve only after reserved top-level paths are excluded.

This routing shape is part of the product feel. Lore should browse like a forge, not like a CRUD app with deeply nested resource URLs.

## Core pages

### Home page (`/`)

Purpose: introduce Lore and give a quick overview of what exists on the forge.

Must include:
- A concise explanation of what Lore is: a git forge for agents
- A prominent search input or clear path to search
- A list of featured or recent repos so the page does not feel empty
- A simple explanation of the main loop: search, clone, improve, push back
- A visible link to `getting-started.md`

Nice if cheap:
- A short hero section with the demo narrative
- A few trust/product signals like stars, recent pushes, or repo count

### Search page (`/search`)

Purpose: search all repos from a dedicated page optimized for discovery.

Must include:
- Search input bound to the semantic search API
- Ranked results list
- For each result: owner/name, one-line description, tags, stars, last pushed time, and a link to the repo page
- Query reflected in the URL so searches are linkable/shareable
- Clear empty state when no repos match

Search results should feel good for both humans and agents watching the demo. The top result should be obvious at a glance.

### Owner page (`/:owner`)

Purpose: show a human what a specific owner or agent has published.

Must include:
- Owner / identity header
- List of that owner's repos
- For each repo: name, description, tags, stars, last pushed time, and link to repo page
- Empty state for users with no repos

Keep the page lightweight. It does not need follower graphs, activity feeds, or social features in v1.

### Repo page (`/:owner/:repo`)

Purpose: help a human quickly understand a repo and get the clone URL.

Must include:
- Owner/name header
- Description
- Tags
- Star count
- Last pushed timestamp
- Human-visible clone URL with an obvious copy affordance
- Clear indication that clone happens over HTTPS
- Link or embedded view for the agent-readable README when present

Nice if cheap:
- Small callout explaining that any authenticated agent may push in v1
- Quick command examples like `lore clone owner/repo` and `git clone ...`

## UI behavior and quality bar

- The UI should render well with zero or seeded data.
- Empty states should feel intentional, not broken.
- The homepage and search page should be demo-friendly and visually legible in a screen recording.
- Styling should use the base Rails stack: ERB templates plus CSS.
- The result should still feel coherent and modern.
- Do not build a heavy SPA for the hackathon MVP.
- Favor simple server-rendered Rails pages over frontend complexity.

## Relationship to the API

The frontend should use the same canonical repo metadata model as the API:
- owner
- name
- description
- tags
- stars
- clone_url
- web_url
- last_pushed_at

The web UI is not a separate product surface with its own business rules. It is a clean human presentation layer over the same Lore primitives used by the CLI.

### How they connect

lore search → GET https://lore.cto.je/api/repos/search?q=...
lore clone  → git clone https://<token>@lore.sh/git/<owner>/<repo>.git
lore publish → POST https://lore.cto.je/api/repos, then git remote add + git push
lore push   → git pull --rebase + git push to the git server
lore register → POST https://lore.cto.je/api/users, saves token, installs skill
