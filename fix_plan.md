# fix_plan.md

## Current status

- Source-of-truth spec exported to `spec.md`.
- Rails 8.1 app skeleton is bootstrapped in-repo with SQLite and a passing baseline test run.
- Grack is bundled, mounted under `/git`, and backed by a local repo root at `tmp/lore-repos` with a passing Rack-level integration test.
- Core `User`, `Repo`, and `Star` models now exist with SQLite constraints, validations, and PAT digest issuance at user creation.
- Shared bearer-token and basic-auth helpers now resolve users from PATs for both the future API and Git middleware.
- `POST /api/users` now creates accounts, returns the one-time plaintext PAT, and covers the registration path with focused integration tests.
- `POST /api/repos` now requires bearer auth, creates bare repos on disk with `HEAD` on `main`, and returns canonical URLs from the create response.
- Real Git transport is now covered with end-to-end validation for anonymous clone/fetch, authenticated push, non-fast-forward rejection, and `last_pushed_at` updates.
- Public repo read APIs now cover per-repo metadata and owner repo listings with canonical URLs and recency ordering.
- Star and unstar API flows now exist and update live star counts in repo responses.
- Search API plumbing now exists and ranks repos by stored embeddings with similarity scores.
- Repo creation now generates and persists embeddings from `name + description + tags`, so new repos are searchable immediately.
- The web UI now has a styled homepage at `/` with Lore positioning, a search CTA, trust signals, recent repos, and an intentional empty state.
- The web UI now has a dedicated `/search` page with semantic ranking, linkable queries, and friendly empty/error states.
- The web UI now has an owner page at `/:owner`, with reserved-route-safe matching and recent repo ordering.
- The web UI now has a repo detail page at `/:owner/:repo`, including clone affordances and README rendering from the bare repo's `main` branch.
- The app now serves `/getting-started.md` as markdown with the canonical Lore onboarding flow and command sequence.
- A first CLI command now exists: `bin/lore register` creates an account, writes `~/.lore/config`, installs a local skill file, and sets git identity.
- `bin/lore search` now calls the real search API and prints ranked results in predictable terminal output.
- Target is a hackathon MVP optimized for the 1-minute demo flow.

## Highest-priority execution plan

### 0. Project bootstrap

- [x] Initialize the Rails app and dependency baseline for Lore v1.
- [x] Add Grack and configure a repo-root path that works in local development/test.
- [ ] Add minimal project documentation for setup/run/test if missing.

### 1. Authentication + core data model

- [x] Implement `User`, `Repo`, and `Star` models with the required constraints and validations.
- [x] Implement PAT issuance on user creation with digest-only storage.
- [x] Add auth helpers for bearer PAT API auth and Basic auth for git transport.
- [x] Implement `POST /api/users` so registration returns the one-time PAT.

### 2. Repo creation + storage

- [x] Implement repo creation API that validates owner/name, creates the DB row, initializes a bare repo on disk, and points `HEAD` at `main`.
- [x] Return canonical `web_url` and `clone_url` values from repo read APIs.
- [x] Update repo metadata on successful pushes, including `last_pushed_at`.

### 3. Git Smart HTTP

- [x] Mount Grack under `/git`.
- [x] Add middleware that resolves repo access from the request path and enforces Lore v1 rules.
- [x] Validate anonymous clone/fetch, authenticated push, and non-fast-forward rejection to `main`.

### 4. Search + stars

- [x] Implement repo search API returning ranked results with similarity scores.
- [x] Add embedding generation/storage for `name + description + tags`.
- [x] Implement star/unstar flows and star counts.
- [ ] Ensure the seeded `slack-notify` repo is top-ranked for demo-critical queries.

### 5. Minimal web UI

- [x] Build a homepage that introduces Lore and highlights repos in a demo-friendly way.
- [x] Build a dedicated search page for searching all repos.
- [x] Build a user page that lists a user's repos.
- [x] Build a repo detail page showing description, tags, stars, clone URL, and last push metadata.
- [x] Serve `getting-started.md` from the app.

### 6. Lore CLI

- [x] Implement `lore register`.
- [x] Implement `lore search` with predictable terminal output.
- [ ] Implement `lore clone` with auto-star behavior.
- [ ] Implement `lore publish`, `lore push`, and `lore whoami`.
- [x] Install/save config in `~/.lore/config` and set git identity during register.

### 7. Demo fixtures + end-to-end validation

- [ ] Seed working demo repos with realistic metadata, commits, and agent-readable READMEs.
- [ ] Add focused tests for API behavior, repo creation, auth, and search ranking.
- [ ] Add an end-to-end demo validation path covering register/create/clone/push/metadata refresh.
- [ ] Validate the exact filmed scenario for Slack search/clone/use/push.
- [ ] As the very last major item, add agent-driven integration tests based on step-by-step user stories: hand the story to another agent, let it interact with the APIs/web UI/CLI, and assert the required outcome happened.

## Known design constraints

- Optimize for a compelling demo over long-term architecture purity.
- Keep semantic-context ideas out of v1 unless needed as mock/demo content only.
- Avoid broad speculative work; each increment should move a demo-critical capability forward.

## Next recommended increment

- Implement `lore clone` with auto-star behavior.
