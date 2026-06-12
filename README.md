# TurboBoard

A single command surface to watch **all open pull requests across selected GitHub repos** — so you stop tab-hopping between repositories. Built with Flutter on the Tether v2.0 design system.

**Form factors:** desktop (macOS / Windows / Linux), tablet (iPad / Android tablet), and web. Phones are **not** a target.

## What's inside

- **PR Board** — every open PR across your watched repos, in columns by review state (needs review / changes requested / approved / waiting), with CI + review badges. Inline **search** and a collapsible **filter bar** (repo / status / review / CI, sort by updated). Each card opens the PR on GitHub or drills into detail.
- **Needs Attention** — triage view grouping PRs into actionable buckets (needs my review, changes requested, failing checks, draft, stale — threshold 3/5/7/14d). A deduplicated count shows on the nav rail.
- **PR Detail** — checks, reviewers, last commit, conversation timeline.
- **AI (bring your own key)** — paste your Anthropic API key once and get a 3-bullet **PR summary** and canned **reply drafts** on the detail screen. Keys are stored in the OS Keychain/Keystore; the app calls the Anthropic Messages API directly (no backend, pay-per-use on your account).
- **Settings** — GitHub connection + PAT change, watched-repo toggles + add, Anthropic key validate/save/remove, and a font-size slider.
- **Font scaling** — `Cmd`/`Ctrl` + `=` / `-` / `0` rescales the whole app (also via the Settings slider); persisted across launches.

## Requirements

- Flutter SDK with Dart `>=3.10.0` (this repo was developed on Flutter 3.41.x).
- A GitHub **personal access token** (fine-grained recommended; scopes: `repo`, `read:org`) to load PRs.
- *(Optional, for AI features)* an Anthropic API key from [console.anthropic.com](https://console.anthropic.com) — note a claude.ai Pro/Max plan does **not** include API access; the API is billed separately, pay-per-use.

## Local setup

Generated code (Freezed / Riverpod / JSON) is **not** committed — generate it after cloning:

```bash
flutter pub get
dart run build_runner build -d
```

If the platform folders are missing (fresh checkout without them), run `bash scripts/setup.sh`, which scaffolds them and runs the steps above.

> **Linux desktop:** `flutter_secure_storage` needs `libsecret-1-dev` at build time and a keyring service at runtime.
>
> **Web:** keys are protected by WebCrypto and do **not** survive a browser-data clear — you re-enter them after such a clear.

## Run

```bash
flutter run -d macos      # desktop (macOS)
flutter run -d windows    # desktop (Windows)
flutter run -d linux      # desktop (Linux)
flutter run -d chrome     # web
```

**First run:** you land on the connect screen — paste a GitHub PAT, then pick which repos to watch. The board loads their open PRs. To enable AI features, open **Settings → Anthropic API key** and paste your key. Everything (token, key, watched repos, font size) persists locally.

## Development

```bash
dart format --line-length 120 .   # format (CI rejects unformatted code)
dart analyze                       # static analysis
flutter test                       # tests
dart run build_runner build -d     # regenerate after model/provider changes
```

## Project structure

```
lib/
├── features/        # pr_inbox, pr_detail, needs_attention, filters, ai, settings, repo_setup
│   └── <feature>/
│       ├── data/            # models (Freezed), repositories, services, queries
│       └── presentation/    # providers (Riverpod), view, helpers
└── shared/          # router (go_router), ui (Tether theme, shell, shared widgets)
```

Clean Architecture with feature-based modules; data/presentation separation. See **`CLAUDE.md`** for the full architecture, conventions, and rules.

## Stack

- Flutter · Riverpod (codegen) + flutter_hooks · Freezed · go_router
- **Tether Design System** via [`turbo_ui`](https://github.com/TurboVets/mobile-shared-components); networking via `turbo_core`
- We depend on `turbo_core` + `turbo_ui` directly (not the `turbo_sdk` umbrella) — `turbo_services`/`turbo_task` pull in mobile-only plugins that break desktop/web builds

## Docs

- `CLAUDE.md` — architecture, conventions, rules for AI agents and humans
- `docs/V1-SCOPE.md` — product scope · `docs/AI-FEATURES.md` — AI feature notes
- `design/` — the TurboBoard design (HTML mockup + tokens) the UI is built from
