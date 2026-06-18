# TurboBoard — v2 Roadmap

Forward-looking features deferred past v1. Companion to `docs/V1-SCOPE.md` and
`docs/V2-ISSUES-SCOPE.md`. Nothing here is committed — these are parked ideas with
enough detail to pick up later.

## Real-time updates via GitHub webhooks

**Status:** deferred to v2. Parked 2026-06-17.

Replace the current 5-minute polling with push-based realtime updates driven by
GitHub webhook events.

### Why a backend is required

TurboBoard is a client-only app (BYOK, no server). GitHub webhooks POST events to
a **public URL**, so a desktop/web/tablet client cannot be the webhook target. A
thin relay backend must receive the events and fan them out to clients.

```
GitHub repo/org webhook → relay endpoint → datastore (event docs / per-user inbox)
                                          → app subscribes to a realtime stream
```

This is the "SSE/WebSocket fan-out backend" listed as out-of-scope in v1.

### Candidate hosting

- **Firebase (fits existing stack — already uses firebase_core + hosting):**
  Cloud Function endpoint → Firestore event docs → app listens via Firestore
  realtime stream; FCM for push. Requires the **Blaze** plan (Spark can no longer
  deploy functions), but a 3-person team sits inside the free allowances
  (~2M function calls/mo, 20K Firestore writes/day, 50K reads/day, unlimited FCM).
  Realistic bill at this scale: **$0/mo**. Must set a billing budget alert + cap
  `maxInstances` to avoid runaway charges.
- **No-card alternative:** Cloudflare Workers (100K req/day free) as the relay +
  Supabase (Postgres + Realtime) for the inbox/stream.

### Features this unlocks

Highest value:
- **Review-requested push notifications** — `review_requested` → instant desktop/push ping.
- **Live CI status** — `check_run` / `check_suite` / `status` flip the PR badge live.

Also:
- Live PR board (opened / synchronize / labeled / ready_for_review) with no refresh.
- Live review state (`pull_request_review`: approved / changes requested).
- @mention / assignment / merge-conflict / merged pings.
- Cross-repo activity feed (commented / merged / closed).
- Live cockpit + stuck-issue recompute from `issues` / `projects_v2_item` events.
- Kills polling → far less GitHub API rate-limit burn; battery/network win on tablet.

### Caveats

- Configuring repo/org webhooks needs **admin** access (PAT alone insufficient).
- HMAC-verify webhook payloads in the relay (security + reject junk early).
- Web push vs native desktop notifications differ per platform — verify
  cross-platform support per the Platform Rules before adding a notify plugin.
- Verify current Firebase pricing/tiers before committing.

### Suggested first spike

Cloud Function (or Worker) + datastore + one event type (`check_run`) → live CI
badge on the PR board, no polling. Proves the relay + stream path end-to-end before
building the notifications surface.
