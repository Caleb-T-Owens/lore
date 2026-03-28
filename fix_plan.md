# fix_plan.md

## Current status

- Source-of-truth spec exported to `spec.md`.
- Rails 8.1 app skeleton is bootstrapped in-repo with SQLite and a passing baseline test run.
- Grack is bundled, mounted under `/git`, and backed by a local repo root at `tmp/lore-repos` with a passing Rack-level integration test.
- Core `User`, `Repo`, and `Star` models now exist with SQLite constraints, validations, and PAT digest issuance at user creation.
- Shared bearer-token and basic-auth helpers now resolve users from PATs for both the future API and Git middleware.
- `POST /api/users` now creates accounts, returns the one-time plaintext PAT, and covers the registration path with focused integration tests.
- `POST /api/repos` now requires bearer auth, creates bare repos on disk with `HEAD` on `main`, and returns canonical URLs from the create response.
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
- [ ] Return canonical `web_url` and `clone_url` values from repo read APIs.
- [ ] Update repo metadata on successful pushes, including `last_pushed_at`.

### 3. Git Smart HTTP

- [x] Mount Grack under `/git`.
- [ ] Add middleware that resolves repo access from the request path and enforces Lore v1 rules.
- [ ] Validate anonymous clone/fetch, authenticated push, and non-fast-forward rejection to `main`.

### 4. Search + stars

- [ ] Implement repo search API returning ranked results with similarity scores.
- [ ] Add embedding generation/storage for `name + description + tags`.
- [ ] Implement star/unstar flows and star counts.
- [ ] Ensure the seeded `slack-notify` repo is top-ranked for demo-critical queries.

### 5. Minimal web UI

- [ ] Build a homepage that introduces Lore and highlights repos in a demo-friendly way.
- [ ] Build a dedicated search page for searching all repos.
- [ ] Build a user page that lists a user's repos.
- [ ] Build a repo detail page showing description, tags, stars, clone URL, and last push metadata.
- [ ] Serve `getting-started.md` from the app.

### 6. Lore CLI

- [ ] Implement `lore register`.
- [ ] Implement `lore search` with predictable terminal output.
- [ ] Implement `lore clone` with auto-star behavior.
- [ ] Implement `lore publish`, `lore push`, and `lore whoami`.
- [ ] Install/save config in `~/.lore/config` and set git identity during register.

### 7. Demo fixtures + end-to-end validation

- [ ] Seed working demo repos with realistic metadata, commits, and agent-readable READMEs.
- [ ] Add focused tests for API behavior, repo creation, auth, and search ranking.
- [ ] Add an end-to-end demo validation path covering register/create/clone/push/metadata refresh.
- [ ] Validate the exact filmed scenario for Slack search/clone/use/push.

## Known design constraints

- Optimize for a compelling demo over long-term architecture purity.
- Keep semantic-context ideas out of v1 unless needed as mock/demo content only.
- Avoid broad speculative work; each increment should move a demo-critical capability forward.

## Next recommended increment

- Add Lore's git auth middleware so clone stays anonymous while push requires valid Basic auth.
