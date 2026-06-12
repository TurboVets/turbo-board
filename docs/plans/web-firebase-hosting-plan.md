# Plan — Web build & Firebase Hosting deploy

Status: proposed. Effort: **Low** (one code change + config).

TurboBoard is a standard Flutter web app with no backend (BYOK). Building for
web and deploying to Firebase Hosting is mostly configuration; the only real
gotcha is CORS for the Anthropic AI calls.

## Steps

```bash
flutter build web --release            # → build/web
firebase init hosting                  # public dir: build/web ; single-page app: Yes
firebase deploy --only hosting
```

- **SPA rewrite is required.** go_router uses real URLs (e.g. `/pr/owner/repo/42`).
  Without a `** → /index.html` rewrite, refreshing a deep link 404s. Answering
  "single-page app: Yes" in `firebase init` writes this; or commit a
  `firebase.json`:

  ```json
  {
    "hosting": {
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    }
  }
  ```

## What works on web as-is

- **GitHub data (board / detail)** — GitHub REST + GraphQL allow browser CORS
  with an `Authorization` token, so the board loads without changes.
- **Secure storage** — `flutter_secure_storage` uses WebCrypto on web; keys do
  NOT survive a browser-data clear (user re-enters them).
- Routing, fonts, layout, font-scaling shortcuts — unchanged.

## The catch — Anthropic AI calls (CORS)

`api.anthropic.com/v1/messages` blocks browser calls by default. From web the AI
summary / reply / triage features fail a CORS preflight unless the Anthropic Dio
client sends:

```dart
// lib/features/ai/data/services/anthropic_api_client.dart → _build()
headers: { ..., 'anthropic-dangerous-direct-browser-access': 'true' }
```

- Anthropic added this header specifically for BYOK browser apps.
- Gate it to web (`if (kIsWeb) ...`) so native builds are unchanged.
- **Trade-off:** the key lives in the browser and rides on requests visible in
  devtools. Acceptable for a personal/BYOK tool; not for a shared deployment
  where one key would be exposed to all users.

## Security posture

Static host, no backend, no secrets baked into the build. GitHub PAT + Anthropic
key are entered at runtime and stored client-side only. Nothing server-side to
leak; never commit a key.

## Open question

- For a **shared** (non-personal) web deployment, move AI calls behind a thin
  proxy (Cloud Function / Cloud Run) that holds a server-side key and adds CORS,
  instead of the direct-browser-access header. Out of scope for the BYOK model;
  revisit only if multi-user hosting is wanted.

## Checklist (when implementing)

- [ ] Add `anthropic-dangerous-direct-browser-access` header gated to `kIsWeb`
- [ ] Add `firebase.json` with the SPA rewrite
- [ ] `flutter build web --release` and verify board + deep-link refresh + AI calls
- [ ] `firebase deploy --only hosting`
- [ ] Add a short "Deploy to web" section to README
