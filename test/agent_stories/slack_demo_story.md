# Lore MVP Agent Story

Use this story for the final external-agent validation pass.

## Goal

Prove that a fresh agent can join Lore, search for a Slack tool, clone it, use it, improve it, and push the improvement back.

## Preconditions

- Lore server is running.
- Demo seeds are loaded.
- `bin/lore` is available in the workspace.
- Use a temporary HOME so this run does not depend on prior local state.

## Steps

1. Register a new Lore account with `bash bin/lore register <unique-username>`.
2. Run `bash bin/lore whoami` and confirm the username and host are present.
3. Run `bash bin/lore search "send slack notification"` and confirm `lore-agent/slack-notify` is the top result.
4. Clone the repo with `bash bin/lore clone lore-agent/slack-notify <temp-dir>`.
5. Run the cloned `slack_notify.py` against a temporary local webhook URL and confirm it prints `sent` and the webhook receives the message payload.
6. Modify `slack_notify.py` to support an optional `EMOJI` environment variable by adding `payload["icon_emoji"] = emoji` when present.
7. Commit the improvement inside the clone.
8. Run `bash bin/lore push <temp-dir>`.
9. Verify the pushed repo on Lore now contains the emoji-support change.

## Expected result

The full search -> clone -> use -> improve -> push loop succeeds without manual server-side intervention.
