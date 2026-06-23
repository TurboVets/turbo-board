# Realtime Updates — Activation Checklist

The webhook → Firestore signal relay and client realtime code are **merged and
working in the app**, but the feature is **dormant until the backend is deployed
and a GitHub webhook is configured**. Until then the app silently runs in
polling-only mode (no behavior change, no errors).

This doc lists everything left to turn it on. Code: PR #5
(`feat/webhook-realtime`). Spec: `docs/superpowers/specs/2026-06-22-webhook-realtime-design.md`.

---

## ⛔ Blocker: Firebase billing (Blaze plan)

**Cloud Functions (Gen 2) require the Firebase Blaze pay-as-you-go plan.** The
project `turboboard-59499` is currently on the free Spark plan, and
`firebase deploy --only functions` will fail until someone with billing
permission upgrades it.

- Who: a Firebase project Owner with org billing permission (not the current
  account — that permission is missing).
- What: Firebase console → project `turboboard-59499` → upgrade to **Blaze**.
- Cost reality: this relay is tiny. Webhook invocations + a few Firestore
  writes/reads per PR event. Expected well within the Blaze free tier
  (2M function calls/mo, 50K Firestore reads/day). Set a budget alert to be safe.

Everything below is blocked on this step.

---

## What already works (no action needed)

- App boots, signs in anonymously (best-effort), and listens for events.
- If no backend/webhook exists, it degrades to the normal polling interval —
  current production behavior is unchanged.
- All code, rules, indexes, and the Cloud Function source are committed.

---

## Activation steps (after Blaze is enabled)

### 1. Set the webhook secret
```bash
firebase functions:secrets:set WEBHOOK_SECRET
# paste a strong random value; reuse the SAME value in the GitHub webhook (step 3)
```

### 2. Deploy backend
```bash
firebase deploy --only functions,firestore:rules,firestore:indexes
```
Note the printed `githubWebhook` URL
(`https://<region>-turboboard-59499.cloudfunctions.net/githubWebhook`).

### 3. Configure the GitHub webhook
One endpoint + one secret serves everything. Choose the scope:

- **Org-level (1 config, preferred):** GitHub org → Settings → Webhooks → Add
  webhook. Covers every repo in the org. Needs org-admin.
- **Per-repo:** each repo → Settings → Webhooks → Add webhook. Needs repo-admin.

Settings (either scope):
- Payload URL: the deployed function URL from step 2
- Content type: `application/json`
- Secret: the value from step 1
- Events (select individually): **Pull requests, Pull request reviews, Pull
  request review comments, Check suites, Issue comments**

### 4. Enable the Firestore TTL policy ⚠️ console-only
The function writes an `expireAt` field, but the auto-delete policy must be
turned on manually (it is not code):

- Firebase console → Firestore → **TTL** → Create policy
- Collection: `repo_events`, Timestamp field: `expireAt`

Without this, events accumulate forever (they still work, just never purge).

### 5. Live-verify
- Trigger activity on a watched repo (open/label a PR). Confirm a `repo_events`
  doc appears in Firestore (doc id = the delivery id shown in GitHub → Recent
  Deliveries) and GitHub shows a `204`.
- Run the app, watch that repo, trigger a PR event → board updates within a few
  seconds, no manual refresh.
- Tamper test: redeliver with a wrong secret (or `curl` a bad signature) → `401`.

---

## Alternative if Blaze is never approved

The relay design assumes Firebase Functions. If billing stays blocked
long-term, options (each its own spec/PR):

1. **Keep polling only** — do nothing; current behavior. The realtime code stays
   dormant and harmless.
2. **Host the webhook receiver elsewhere** (Cloudflare Workers free tier, a tiny
   VPS, etc.) that writes to Firestore via a service account. Reuses the client
   code and Firestore rules unchanged; only the receiver moves off Functions.
   The HMAC + event-mapping logic in `functions/src/{verify,map_event}.ts` ports
   directly.

---

## File map (for whoever activates this)

- `functions/src/index.ts` — `githubWebhook` handler
- `functions/src/verify.ts` — HMAC verification
- `functions/src/map_event.ts` — payload → event mapping (incl. `check_suite`
  PR resolution)
- `firestore.rules`, `firestore.indexes.json` — read rules + composite index
- `firebase.json` — `functions` + `firestore` config blocks
- `lib/features/realtime/` — client model, repository, listener provider
- `lib/main.dart` — anonymous sign-in on boot
- `lib/shared/ui/providers/auto_refresh_provider.dart` — polling stretch when
  realtime connected
- `lib/features/repo_setup/presentation/view/setup_screen.dart` — in-app webhook
  setup instructions card
