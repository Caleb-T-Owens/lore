# AGENT.md

Lore hackathon MVP. This file is the durable build contract for autonomous runs.

## Product intent

Lore is a git forge built for agents.

Default behavior should change from "write a new tool" to "search for one first, use it, and push improvements back".

This repo is for the Lore server + CLI demo surface, not the seeded example tools themselves.

## Demo-first rule

Optimize for the 1-minute demo loop:

1. User asks for a Slack notification tool.
2. Agent runs `lore search "send slack notification"`.
3. Search returns `lore-agent/slack-notify` as the top result.
4. Agent clones and uses it.
5. Agent makes a tiny improvement and pushes it back successfully.

If a feature does not make that demo more compelling or more reliable, it is likely out of scope.

## Source of truth

Read first:

- `spec.md` — full exported product/design/spec context from Notion
- `fix_plan.md` — prioritized execution plan

Use `spec.md` as the main source of truth for implementation details.

## Hard scope for v1

Build these core capabilities:

- Rails app as the main server
- JSON API for users, repos, search, and stars
- Git Smart HTTP via Grack mounted under `/git`
- Bare repos stored on local disk
- Public clone/fetch for all repos
- Authenticated push to `main` for any valid account
- Minimal web UI for browsing/searching repos
- Semantic-ish repo search using embeddings stored on repo records
- Thin Lore CLI that wraps the HTTP API + git
- Seeded demo repos that make search and demo flows work

## Explicitly out of scope

Do not spend time building these unless they are required to unblock a must-have flow:

- pull requests
- private repos
- per-repo ACLs
- CI infrastructure
- semantic context / long-term repo memory system
- reputation systems
- complex conflict resolution UX
- production hardening beyond hackathon usefulness

## Required product rules

- Canonical branch is always `main`
- Clone/fetch is anonymous
- Push requires authentication
- Any authenticated account may push to any repo in v1
- Non-fast-forward pushes to `main` must be rejected
- Rails must not reimplement Git protocol behavior
- Git transport should be delegated to Grack

## Suggested implementation shape

- Rails owns users, PATs, repo metadata, stars, indexing, repo creation, minimal HTML/JSON
- Grack handles clone/fetch/push at `/git/:owner/:repo.git`
- Bare repos live under a local root such as `/var/lib/lore/repos` or a repo-local configurable path for development/test
- Search uses embeddings for `name + description + tags`
- CLI is a thin script or small executable that calls the API and shells out to git

## Validation targets

Prefer focused validation after each increment, but keep these end goals in mind:

- Rails tests pass
- Repo creation works and creates a bare git repo with HEAD on `main`
- Anonymous clone/fetch works
- Authenticated push works
- Non-fast-forward push is rejected
- Repo metadata updates after push
- Search for `send slack notification` returns `lore-agent/slack-notify` at the top
- Seed/demo data exists and is usable

Important late-stage testing requirement:

- Treat agent-driven integration testing as one of the very last major items, after the MVP surfaces basically exist.
- The integration test style should be a step-by-step user story.
- That user story should be handed to another agent, which then executes the steps against the real APIs / web UI / CLI where practical.
- The test should assert the intended outcome of the story, rather than only checking internal implementation details.

## Durable environment notes

- In this workspace, Rails bootstrap required installing `ruby-full`, `libsqlite3-dev`, and `libyaml-dev` before `bundle install` would succeed.

## Ralph loop contract

On each iteration:

1. Read `spec.md`, `fix_plan.md`, and this file.
2. Pick exactly one highest-value remaining item.
3. Search the codebase before assuming it is missing.
4. Implement one bounded but meaningful increment.
5. Run focused validation for that increment.
6. Update `fix_plan.md` to reflect reality.
7. Update this file only if you discover durable run/build/test knowledge.
8. Commit if the increment is coherent and validated.
9. Immediately continue to the next item unless the repo is truly complete, blocked, unsafe, or user-stopped.

Do not stop just because you reached a nice milestone.

## Completion rule

The loop is only complete when the demo-critical Lore MVP works end-to-end and `fix_plan.md` has no meaningful remaining items.

If stopping, state one exact reason:

- `complete`
- `blocked`
- `unsafe`
- `user-stopped`
