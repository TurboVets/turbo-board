# Mobile TurboBoard — AI Features

Notes from planning session, 2026-06-11.

## Model: Bring Your Own Key (BYOK)

Users provide their own Anthropic API key — the app never ships or shares a key.

- Keys are created at [console.anthropic.com](https://console.anthropic.com) (Settings → API keys).
- A claude.ai Pro/Max subscription does **not** include API access; the API is a separate product with pay-per-use billing. Users must add a payment method to the Console.
- The app calls the Messages API (`https://api.anthropic.com/v1/messages`) directly from Dart — no AI backend needed since each user pays for their own usage.
- Key storage: `flutter_secure_storage` (Keychain / Keystore). Never hardcode or log keys.
- Validate the key on entry with a cheap 1-token test call.

## Feature backlog (ranked for first iteration)

| # | Feature | Where | What | Effort |
|---|---|---|---|---|
| 1 | **PR Summary** | PR Detail | Send title + description + diff → 3-bullet TL;DR of what changed and why. ~1 Haiku call per PR. | Low |
| 2 | **Inbox Triage** | PR Inbox | Send all open PRs (title, age, CI state, review state) → ranked triage: review first, stale, blocking. The killer feature for the multi-repo scaling problem. | Medium |
| 3 | **Review Assistant** | PR Detail | Diff → flagged issues + draft review comments, editable before posting via GitHub API. | High (iteration 2) |
| 4 | **Reply Drafter** | PR Detail | Canned intents ("nudge reviewer", "request changes message") → editable draft. | Low |

## v1 scope (decided)

- Settings screen for API key (secure storage + validation)
- Shared Anthropic API client
- Feature #1 PR Summary
- Feature #4 Reply Drafter

Both v1 features are single-prompt calls sharing the same client. #2 Inbox Triage follows once the plumbing is proven, and is where a future chatbot UI ("ask anything about your PRs") can hang off without new infrastructure.

See `docs/plans/ai-v1-implementation-plan.md` for the implementation plan.
