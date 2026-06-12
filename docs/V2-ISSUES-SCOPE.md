# TurboBoard — v2 Issues Scope

Drafted 2026-06-11. Follows v1 (PR dashboard) once PR plumbing + AI BYOK are proven.
Companion to `docs/V1-SCOPE.md`. Source planning lives in the `Mobile TurboBoard` project folder.

## Problem

v1 watches **PRs** across repos. The other half of day-to-day work lives in **issues/tickets** —
and for TurboVets those issues are tracked on a **GitHub Projects v2 board** ("Mobile Space",
`github.com/orgs/TurboVets/projects/8`), not as raw per-repo issues. The board carries the fields
that actually drive triage and sprint work (Status, Priority, Sprint, Complexity) — fields the
plain GitHub Issues REST/Search API does **not** expose. v2 brings that board into TurboBoard so a
contributor sees their issues, sprint, and the PRs linked to them in one place, cross-linked with
the existing PR views.

## Source of truth — GitHub Projects v2 (not repo issues)

All issues come from a Projects v2 board, addressed by `org login + project number`. Implications:

- **GraphQL only.** REST `list_issues` cannot read project fields. Use turbo_core `GraphQLClient`
  against `organization.projectV2(number:)` → `items` with `fieldValues`.
- **Custom fields are first-class.** Status / Priority / Sprint / Complexity / Jira Key are
  `ProjectV2` single-select / iteration / number / text fields, read from each item's `fieldValues`,
  not from the issue object.
- **Items span repos.** One board mixes `mobile`, `recruit-mobile`, `mobile-shared-components`.
  Repo is a field on the item, not the query root.
- **Org-private board** → the signed-in GitHub token needs `read:project` + org access. Validate
  on entry (cheap `projectV2(number:){ id }` probe); surface a clear "no project access" state.
- **Pagination:** board has 100+ items; page `items(first:100, after:)` and merge.

## Board shape (observed, Mobile Space)

| Field | Type | Values |
|---|---|---|
| **Status** | single-select | Not Started · In Progress · In Review · Triage · Done · Cancelled |
| **Priority** | single-select | P0 · P1 · P2 · P3 (often unset) |
| **Sprint** | iteration | named sprints with date ranges |
| **Complexity** | number | story points |
| **Labels** | labels | enhancement · bug · epic · test:e2e · question · … |
| **Parent issue / Sub-issues** | relation + progress | epics → children, % done |
| **Linked pull requests** | relation | issue ↔ PR (ties into v1 PR Detail) |
| **Jira Key** | text | synced from Jira; read-only deeplink |
| Assignees · Repository · Milestone · Created · Updated | — | standard |

## Lead Cockpit — the headline screen (Approach A) ✅ built (mock)

Decided 2026-06-11: the Issues half of the app leads with a **Lead Cockpit**, not a raw ticket
board. Opening Issues answers "what needs me right now?" — the thing GitHub Projects web does not.
The plain board/inbox is secondary. This is what makes the app worth more to a team lead than the
Projects web UI they already have.

Lead value (all confirmed in scope): **who's blocked/overloaded**, **what's stuck/aging**, **sprint
health/risk**, **PR↔issue flow**, plus **aging/cycle-time**, **per-person rollup**, and an
**AI sprint-risk brief**.

**Screen layout** (`lib/features/lead_cockpit/`, mirrors `pr_inbox`/`needs_attention`):

1. **Sprint health strip** — sprint name + days left + total/repos; an **AI Sprint Brief** toggle
   (BYOK Claude narrative); a proportional status bar; six count tiles (Done / In Progress /
   In Review / Not Started / **At Risk** / **Unestimated**).
2. **Team load** — one card per assignee: WIP / In-Review / Stuck counts, a 0–100 load gauge
   (green < 60 ≤ amber < 90 ≤ red), and current ticket titles. Members ≥ 90% load get a red border +
   `OVERLOADED` badge.
3. **Aging / stuck list** — items sitting too long in a status: status dot, title, repo, assignee,
   Priority, status, **time-in-status** (red past hard threshold, orange aging), linked-PR state.

**Status → signal (cockpit):** Done green · In Progress blue · In Review amber · Triage orange ·
Not Started gray · Cancelled gray. **Priority accent:** P0 red · P1 orange · P2 amber · P3 gray.

**Data sourcing — hybrid (decided):**
- *Available now* from a single Projects v2 query: status counts, per-assignee grouping,
  Priority/Sprint/Assignee, `updatedAt`, linked PRs.
- *Approximated* until snapshots accrue: time-in-status / cycle-time (derived from `updatedAt`),
  "since yesterday". **At Risk** and **Unestimated** are heuristics — At Risk = open P0/P1 that is
  stale or has a failing linked PR; Unestimated = open item with no Complexity.
- *Snapshot history* (real cycle-time, scope-creep, "since yesterday"): app snapshots the board
  per refresh into local storage and diffs over time. **Follow-up** — not in the first cut.

**Implementation status:** screen + widgets + Freezed models + provider + mock repository (seeded
with the design's sample sprint) + routing + nav entry are built and tested. Remaining: the live
`GithubLeadCockpitRepository` (below) and the snapshot store.

## In scope — Core

- **Issue Inbox** — all open (non-Done, non-Cancelled) board items across watched repos, board view.
  Mirrors PR Inbox layout. Per-row: title, repo, assignees, Priority pill, Complexity badge,
  sprint chip, and a **Status** signal dot. Epic rows show sub-issue progress.
- **My Issues / Needs Attention (issues)** — triage view mirroring PR Needs Attention. Categories:
  - **Assigned to me** (open, current user in assignees)
  - **Triage queue** (Status = Triage, or open + no Priority)
  - **In my sprint** (current iteration ∧ assigned to me)
  - **Stale** (no update in N days; threshold 3/5/7/14d, shared control with PR side)

  An item can appear in multiple categories; nav badge shows the **deduplicated** count.
- **Issue Detail (read-only)** — body, assignees, labels, Status, Priority, Sprint, Complexity,
  parent epic + sub-issue progress, **Linked PRs** (deep-link into existing PR Detail), Jira Key
  (read-only external link), repo, milestone.
- **Filters (issues)** — extend the existing `filters` feature: repo multi-select, Status multi,
  Priority multi, Sprint, Label, Assignee. Sort by "Updated recently".

## In scope — AI (BYOK, reuse v1 client)

- **Issue Summary** (Issue Detail) — title + body → 3-bullet TL;DR. Direct reuse of the v1 PR
  Summary path against the shared Anthropic client (`claude-haiku-4-5`). No new plumbing.

## In scope — Design

- Reuse the v1 three-region shell (rail / board / detail) and Tether tokens, dark-first. Add an
  **Issues** nav section beside PRs in the left rail with its own dedup attention badge.
- **Status → signal mapping** (issue semantics, distinct from CI):
  - Done / merged-equivalent → green
  - In Progress → blue
  - In Review → yellow/amber
  - Triage → orange
  - Not Started → gray
  - Cancelled → gray (muted/strikethrough)
- **Priority → accent:** P0 red · P1 orange · P2 yellow · P3 gray.

## Killer feature — PR ↔ Issue cross-link

The board's "Linked pull requests" field is the connective tissue between v1 and v2. Issue Detail
links out to PR Detail and vice-versa, so a reviewer jumps from "what changed" to "why" without
leaving the app. Prioritize wiring this both directions.

## Architecture notes

- New feature: `lib/features/issues/` (data: models, queries, repositories; presentation:
  providers, view, view_models). Mirror `pr_inbox` structure.
- New feature or shared: `issues_needs_attention` — or fold issue categories into the existing
  `needs_attention` feature behind a PR/Issue segment. **Decide before building** (see Open
  questions).
- Models (Freezed): `ProjectIssue`, `ProjectField` value union, `Sprint`, `SubIssueProgress`.
- Queries (`data/queries/`): `fetch_project_items.graphql` (paged), with `fieldValues` fragment
  resolving single-select / iteration / number / text by field name.
- Repository: `IssuesRepository` interface + GraphQL impl + mock impl (for tests / mock mode),
  returning `Result<T>`.
- Routing: `/issues`, `/issues/:repo/:number`; keep web URLs meaningful (deep-link on refresh).

## Out of scope (v2)

- **Writing to the board** — no status changes, no assignment, no comments, no creating issues.
  Read-only, same as v1 PR Detail.
- **Jira write-back / two-way sync** — Jira Key is a read-only deeplink only.
- Sprint planning / drag-to-reorder / board editing.
- AI triage that auto-sets Priority or Sprint.
- Live updates (webhooks/SSE) — still deferred, same as v1.
- Phone layouts.

## Open questions (resolve before build)

1. **Board selection:** hardcode Mobile Space (#8), or let the user pick org + project number in
   Repo Setup? (Recommend: configurable, default to a watched org's project.)
2. **Needs Attention:** separate Issues attention view, or one unified attention screen with a
   PR / Issue toggle? (Recommend: unified, segmented — keeps the dedup-badge UX consistent.)
3. **"Watched repos" vs "watched board":** v1 watches repos; the board is repo-spanning. Do we
   filter board items to watched repos, or show the whole board and filter in the UI?
4. **Token scope:** require `read:project` at sign-in, or request incrementally when the user first
   opens Issues? (Recommend: incremental, with a clear prompt — avoids gating v1 auth.)
