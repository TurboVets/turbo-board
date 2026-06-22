# Webhook Backend + Realtime Updates — Design

**Date:** 2026-06-22
**Status:** Approved (brainstorm), pending implementation plan
**Branch:** `feat/webhook-realtime`

## Summary

Add a GitHub webhook receiver and realtime update path so the board reflects PR
activity within seconds instead of waiting for the ~5-minute poll. The backend is
a **signal relay**: it receives webhooks, verifies them, and writes a tiny event
record to Firestore. Clients listening to that stream fire a **targeted refetch
using their own PAT**. The backend stores **no PR data and no tokens** — the
existing BYOK (bring-your-own-key) trust model is preserved.

## Goals

- Near-realtime board/detail updates on PR activity (open/close/merge, review,
  CI, comments).
- Preserve BYOK: backend never holds a GitHub token or PR contents.
- Resilient: degrades cleanly to polling when realtime is unavailable.
- Cross-platform: works on macOS, Windows, Linux, web, and tablets (all current
  targets).

## Non-Goals

- Backend as source of truth for PR data (rejected — would require a stored app
  token + storing PR contents).
- Self-hosted WebSocket/SSE server (rejected — reuse existing Firebase project).
- GitHub OAuth login / per-user authorization (rejected — events carry only
  low-sensitivity metadata; see Security).
- Per-repo board provider granularity (rejected as YAGNI — `prInbox` stays a
  single global query; see Client Invalidation).

## Decisions (from brainstorm)

| Decision | Choice | Rationale |
|---|---|---|
| Backend role | **Signal relay** | Keeps BYOK intact; smallest footprint |
| Webhook setup | **Manual, one shared secret** (org-level preferred) | No new PAT scopes; one config if single-org |
| Client read auth | **Anonymous Firebase Auth** | Blocks casual scraping; events are non-sensitive |
| Polling fate | **Keep as fallback, stretched** | Covers unconfigured webhooks + dropped streams |
| Board granularity | **Global `prInbox` + event→provider mapping** | One cheap call; comments never touch the board |
| Backlog suppression | **docChanges-after-first-snapshot, dedup by docId** | Clock-skew-proof; no replay on reconnect |

## Architecture

```
GitHub  --webhook POST-->  Cloud Function (githubWebhook)
                              | 1. verify X-Hub-Signature-256 (HMAC) -> 401 on fail
                              | 2. parse event -> {repo, event, action, prNumber}
                              | 3. write Firestore repo_events (doc id = delivery id)
                              v
                          Firestore  repo_events  (read: auth!=null, write: false)
                              ^
                              | snapshots() (anonymous-auth client)
                          Flutter clients
                              | on new event -> map event type -> invalidate providers
                              v
                          targeted refetch via client's OWN PAT -> GitHub API
```

Backend stores: **NO PR data, NO tokens.** Only `{repo, event, action, prNumber?,
ts, expireAt}` metadata.

## Components

### Backend — `functions/` (Firebase Cloud Functions Gen 2, TypeScript)

New `functions/` directory (none exists today — repo currently uses Firebase
hosting only).

**`githubWebhook` (HTTPS function):**

1. Read raw request body (needed for an exact HMAC over the bytes GitHub signed).
2. Verify `X-Hub-Signature-256` = `sha256=` HMAC-SHA256(body, `WEBHOOK_SECRET`)
   using a constant-time compare. Missing/mismatched signature → `401`, no write.
   **This is the security boundary.**
3. Read `X-GitHub-Event` and parse payload:
   - `repo` = `payload.repository.full_name`
   - `event` = the `X-GitHub-Event` header value
   - `action` = `payload.action` (when present)
   - `prNumber` = `payload.pull_request.number` ?? `payload.issue.number`
     (for `issue_comment` on a PR) ?? null
4. Write to Firestore `repo_events` with **doc id = `X-GitHub-Delivery`**
   (idempotent — GitHub retries reuse the same delivery id):
   `{repo, event, action, prNumber?, ts: serverTimestamp(), expireAt: ts + 24h}`
5. Return `204` immediately (do not block GitHub on Firestore latency beyond the
   single write).

**Subscribed events:** `pull_request`, `pull_request_review`,
`pull_request_review_comment`, `check_suite`, `issue_comment`.

**Config / secrets:** `WEBHOOK_SECRET` lives in Firebase Secret Manager (never
committed, never logged).

**TTL:** A Firestore TTL policy on `expireAt` auto-purges old events (~24h). No
manual cleanup job.

### Firestore

- Collection: `repo_events`.
- Security rules:
  ```
  match /repo_events/{id} {
    allow read: if request.auth != null;
    allow write: if false;   // Admin SDK (Function) bypasses rules
  }
  ```
- Document shape:
  ```
  {
    repo: string,          // "owner/name"
    event: string,         // X-GitHub-Event
    action: string|null,   // payload.action
    prNumber: number|null,
    ts: Timestamp,         // serverTimestamp()
    expireAt: Timestamp    // ts + 24h, drives TTL
  }
  ```

### Client — new feature `lib/features/realtime/`

**New dependencies** (all support macOS/Windows/Linux/web/Android/iOS):
`firebase_core`, `cloud_firestore`, `firebase_auth`. Generate
`lib/firebase_options.dart` via `flutterfire configure`.

**Boot (`main`):** `Firebase.initializeApp(...)` then a silent, best-effort
`signInAnonymously()`. Any failure is logged and the app continues in
**polling-only** mode — fully functional, just not realtime.

**`data/models/repo_event.dart`** — Freezed model + `fromJson` mapping the
Firestore document. (Per CLAUDE.md model conventions.)

**`data/repositories/realtime_repository.dart`** — interface + two impls:
- `FirestoreRealtimeRepository` — `Stream<List<RepoEvent>> watch(List<String> repos)`.
  Firestore `whereIn` caps at 30 values, so repo lists are chunked into batches of
  ≤30 and the per-batch streams are merged. Watched repo lists are expected to be
  small; chunking is a safety measure.
- `MockRealtimeRepository` — no-op / scriptable stream for tests and offline.

**`presentation/providers/realtime_provider.dart`:**
- Watches `watchedReposProvider`; (re)subscribes when the watched set changes.
- **Backlog suppression:** the first Firestore snapshot (existing docs) is ignored;
  the provider only reacts to `added` `docChanges` delivered *after* the initial
  load, deduped by docId within the session. This avoids acting on stale events
  and avoids replaying on reconnect, without relying on client/server clock
  agreement.
- **Debounce ~3s:** events are buffered and coalesced by `repo` so a CI burst
  (many `check_suite`/`check_run` deliveries) produces one invalidation pass per
  affected repo, not dozens.
- **Event → provider mapping** (applied per coalesced event):

  | Event | Invalidate |
  |---|---|
  | `pull_request` (opened/closed/merged/ready_for_review) | `prInbox` + cockpit/sprint + `prDetail(prNumber)` |
  | `pull_request_review` | `prInbox` + `prDetail(prNumber)` |
  | `check_suite` | `prInbox` + `prDetail(prNumber)` |
  | `issue_comment` / `pull_request_review_comment` | **`prDetail(prNumber)` only** |

  `prDetail` is a family provider keyed by PR number — invalidation targets the
  exact PR. `prInbox` is a single global provider (one GraphQL search across all
  watched repos), so a board-relevant event refetches the whole board in one call
  regardless of which repo changed — this is existing architecture and is
  intentionally left global.
- Exposes **`realtimeConnectedProvider`** with state connected / disconnected /
  error.

### Polling integration — `lib/shared/ui/providers/auto_refresh_provider.dart`

`AutoRefresh` watches `realtimeConnectedProvider`:
- **connected** → stretch the effective interval to ~20 min (safety net for repos
  without a configured webhook).
- **disconnected / error** → snap back to the user's configured interval
  (`refreshIntervalProvider`, default 5 min).

The existing lifecycle gating (pause when not `resumed`, catch-up on resume) is
unchanged.

## Data Flow (example: a review is submitted)

1. Reviewer approves PR #42 in `acme/web`.
2. GitHub POSTs `pull_request_review` to `githubWebhook`.
3. Function verifies HMAC, writes `repo_events/<delivery-id>` =
   `{repo:"acme/web", event:"pull_request_review", action:"submitted", prNumber:42, ts, expireAt}`.
4. Each connected client watching `acme/web` receives an `added` docChange.
5. After ≤3s debounce, clients invalidate `prInbox` and `prDetail(42)`.
6. Riverpod refetches via each client's own PAT; UI updates. Providers with no
   listeners are no-ops.

## Error Handling & Resilience

- **Anonymous sign-in fails** → log, no realtime, polling stays at normal
  interval. App fully usable.
- **Firestore stream error** → mark `realtimeConnectedProvider` = error → poller
  snaps to normal cadence → resubscribe with backoff.
- **Webhook signature invalid/missing** → `401`, no Firestore write.
- **GitHub webhook retries** → same `X-GitHub-Delivery` → same doc id → idempotent
  overwrite, not a duplicate event.
- **Repo with no webhook configured** → never produces events → covered by the
  fallback poll.

## Security

- **Real boundary = webhook ingress HMAC.** Constant-time `X-Hub-Signature-256`
  verification against a secret in Secret Manager. Unsigned/forged payloads are
  rejected before any write.
- **Read side is metadata only.** Events contain `{repo, event, action, prNumber,
  ts}` — no PR titles, diffs, or tokens. Anonymous Firebase Auth blocks casual
  scraping and gives a per-client uid for future rate-limiting; it is explicitly
  *not* relied on for confidentiality (a Firebase config is public in the web
  build, so a motivated reader could self-issue an anonymous token). This is
  acceptable because the only leak is "repo `owner/name` had activity at time T",
  and repo slugs are not secret to anyone already in the org.
- **No tokens on the backend.** Clients refetch with their own PAT, exactly as
  today.

## Webhook Setup (manual, documented in-app)

One Cloud Function endpoint + one shared secret serve every webhook. The number of
GitHub-side configs depends on scope:

- **Org-level (preferred, 1 config):** Org → Settings → Webhooks → Add webhook.
  Covers every repo in the org. Requires org-admin.
- **Per-repo (1 per repo):** Repo → Settings → Webhooks → Add webhook. Requires
  repo-admin on each.

Settings for either:
- Payload URL: `https://<region>-<project>.cloudfunctions.net/githubWebhook`
- Content type: `application/json`
- Secret: the project `WEBHOOK_SECRET`
- Events: Pull requests, Pull request reviews, Pull request review comments,
  Check suites, Issue comments.

The app surfaces these instructions on a setup screen. Backend code is identical
for org-level vs per-repo — only the GitHub-side config count differs.

## Testing

**Backend (Node unit tests):**
- Signature verification: valid signature passes; invalid → 401; missing → 401.
- Payload → event mapping for each subscribed event type (correct `repo`, `event`,
  `action`, `prNumber`, including `issue_comment` PR-number extraction).
- Idempotency: same delivery id → single doc.

**Client (Flutter, with `MockRealtimeRepository`):**
- Each event type invalidates exactly the providers in the mapping table (and no
  others — e.g. `issue_comment` does not touch `prInbox`).
- Debounce coalesces a burst into one invalidation pass per repo.
- Initial-snapshot backlog is ignored; only post-load `added` changes act; dedup by
  docId prevents double-handling.
- `auto_refresh` interval switches: normal → stretched on connect, stretched →
  normal on disconnect/error.

## Files

**New:**
- `functions/` — package.json, tsconfig, `src/index.ts` (`githubWebhook`),
  `src/verify.ts`, `src/map_event.ts`, tests.
- `lib/firebase_options.dart` (generated).
- `lib/features/realtime/data/models/repo_event.dart`
- `lib/features/realtime/data/repositories/realtime_repository.dart`
- `lib/features/realtime/presentation/providers/realtime_provider.dart`
- `firestore.rules`, Firestore TTL policy config.
- Tests under `test/features/realtime/` and `functions/` test dir.

**Modified:**
- `pubspec.yaml` — firebase deps.
- `lib/main.dart` — Firebase init + anonymous sign-in.
- `lib/shared/ui/providers/auto_refresh_provider.dart` — stretch interval on
  realtime connection.
- `firebase.json` — add functions + firestore config.
- Repo-setup screen — webhook setup instructions.

## Open Questions

None blocking. Org-level vs per-repo webhook is a deployment choice, not a code
choice.
