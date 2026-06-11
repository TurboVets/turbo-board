# TurboBoard — v1 Scope

Decided 2026-06-11. Source planning docs live in the `Mobile TurboBoard` project folder
(`design/README.md`, `docs/AI-FEATURES.md`, `docs/plans/ai-v1-implementation-plan.md`).

## Problem

Managing multiple GitHub repos means constantly switching tabs to check PRs/issues, review PRs, and follow up.
This doesn't scale as the number of repos grows. TurboBoard is a single place to watch all open PRs across
selected repos (and later, issues).

## Form factors

Desktop (macOS / Windows / Linux), tablet (iPad / Android tablet), and web. **Phones are not a target.**

## In scope — Core (GitHub dashboard MVP)

- **Auth / Repo Setup** — GitHub sign-in, then pick which repos to watch
- **PR Inbox** — all open PRs across watched repos, with CI / review / draft badges
- **Needs Attention** — triage view grouping PRs into actionable categories: Needs my review,
  Changes requested (waiting on author), Failing checks, Draft, and Stale (threshold adjustable 3/5/7/14d).
  A PR can appear in multiple categories; nav badge shows the deduplicated count
- **PR Detail** — checks status, review state, requested reviewers, last commit, conversation
- **Filters** — repo multi-select, PR status (Open / Draft / Merged / Closed), review state
  (Needs my review / Changes requested / Approved / Waiting on author), CI state
  (Failing / Pending / Passing), sort by "Updated recently"

## In scope — AI features (BYOK)

Users provide their own Anthropic API key (Messages API, `claude-haiku-4-5`). No AI backend.

- **AI Settings screen** — paste / validate / save API key (flutter_secure_storage; never logged or committed)
- **Shared Anthropic API client** — single client both features reuse
- **PR Summary** (PR Detail) — title + description + diff → 3-bullet TL;DR
- **Reply Drafter** (PR Detail) — canned intents (nudge reviewer, request changes, approve, ask for update)
  → editable draft, copy to clipboard

## In scope — Design

- Tether Design System v2.0 via `turbo_ui` (`getTetherThemeData`, `context.appColors`), dark-first
- Desktop-first three-region shell: left rail (nav/repos), center board, right detail/filter column;
  tablet collapses to rail + single column
- Status signal mapping: passing/approved = green, pending = yellow, failing/changes = red,
  needs review/draft info = blue, waiting/draft = gray, stale = orange

## Out of scope (v1)

- Issues monitoring
- AI Inbox Triage (#2) — follows once the AI plumbing is proven; future "ask anything about your PRs"
  chatbot hangs off it
- AI Review Assistant (#3) and posting drafts/comments to GitHub
- Streaming AI responses
- Live updates via webhooks (SSE/WebSocket fan-out backend)
- Phone layouts
