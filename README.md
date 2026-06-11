# TurboBoard

A single dashboard to watch **all open PRs** (and later, issues) across selected GitHub repos — so you stop tab-hopping between repositories.

**Form factors:** desktop (macOS / Windows / Linux), tablet (iPad / Android tablet), and web. Phones are **not** a target.

## First-time setup

The repo intentionally ships without generated platform folders. From the repo root:

```bash
bash scripts/setup.sh
```

or manually:

```bash
flutter create . --project-name turbo_board --platforms=macos,windows,linux,web,android,ios
flutter pub get
dart run build_runner build -d
flutter test
```

> Linux desktop note: `flutter_secure_storage` requires `libsecret-1-dev` (build) and a keyring service at runtime.

## Run

```bash
flutter run -d macos      # desktop
flutter run -d chrome     # web
```

## Stack

- Flutter, Riverpod (codegen) + flutter_hooks, Freezed, go_router — same conventions as `mobile_recruit`
- **Tether Design System** via [`turbo_ui`](https://github.com/TurboVets/mobile-shared-components) and networking via `turbo_core`
- We depend on `turbo_core` + `turbo_ui` directly (not the `turbo_sdk` umbrella) because `turbo_services`/`turbo_task` pull in mobile-only plugins that would break desktop/web builds

## Docs

- `CLAUDE.md` — architecture, conventions, and rules for AI agents and humans
- Product scope & design: see the `Mobile TurboBoard` planning folder (PR Inbox, PR Detail, filters, AI features)
