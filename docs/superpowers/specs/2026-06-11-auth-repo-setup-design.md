# Auth + Repo Setup — Design

**Date:** 2026-06-11
**Feature:** `repo_setup` (sub-project A of TurboBoard v1)
**Status:** Approved for planning

## Context

TurboBoard v1 is decomposed into sequential sub-projects, each with its own
spec → plan → implement cycle:

| # | Sub-project | Order rationale |
|---|---|---|
| **A** | **Auth + Repo Setup** (this doc) | Foundation — all real data needs a token + repo list. |
| B | GitHub-backed PR Inbox + 3-region Tether shell | Inbox UI mostly exists; swap mock for real data. |
| C | Filters + Needs Attention triage | Builds on real inbox list. |
| D | PR Detail (checks, reviews, conversation) | Drill-down from inbox. |
| E | AI BYOK (settings, Anthropic client, PR Summary, Reply Drafter) | Hangs off PR Detail. |

This spec covers **A only**.

### Decisions locked during brainstorming

- **Auth method: Personal Access Token (PAT).** User pastes a token; stored in
  `flutter_secure_storage`. No backend, no client secret, works on all six
  targets incl. web. Mirrors the BYOK Anthropic-key approach. (Mockup shows
  OAuth/GitHub-App buttons — we diverge: step 1 is a token-paste field.)
- **Repo picker: auto-list + toggle.** After the token validates, call the
  GitHub API to fetch all accessible repos (user + orgs), show them in a
  scrollable list with toggles, with a search/filter box and owner grouping —
  matching the mockup's step 2.

### Design reference

- `design/mockup.html` — auth screen is a centered wizard card (`.auth-card`,
  452px, top blue gradient rail, crosshair "T" mark), a 2-segment step-indicator
  bar (`.steps`/`.step`), step 1 = connect, step 2 = repo list with toggles
  (`.repo-pick`/`.repo-item`/`.toggle`).
- `design/README.md` — Tether v2.0 tokens (dark zinc `#18181b`, blue `#0073ff`,
  radii 4/8px, signal palette). Access in Flutter via `context.appColors` /
  `getTetherThemeData`. Prefer `turbo_ui` components.

## Goal

First-run gate: paste GitHub PAT → validate → pick watched repos → land on the
PR board. Re-editable later from Settings.

## Architecture

Standard feature layout under `lib/features/repo_setup/`, data/presentation
split per CLAUDE.md. Networking via turbo_core `DioClient`. Errors caught in the
repo layer only, surfaced upward as turbo_core `Result<T>`.

### Data layer (`lib/features/repo_setup/data/`)

**`models/github_user.dart`** (Freezed + JSON) — proves the token is valid.
- `login` (String), `avatarUrl` (String), `name` (String?).
- Maps `GET /user` response.

**`models/github_repo.dart`** (Freezed + JSON)
- `owner` (String), `name` (String), `nameWithOwner` (String), `description`
  (String?), `isPrivate` (bool), `pushedAt` (DateTime?).
- `fromJson` maps the REST repo shape (`full_name`, `owner.login`, `private`,
  `pushed_at`).

**`repositories/auth_repository.dart`** — interface + impl.
- Impl uses turbo_core `DioClient`, base `https://api.github.com`, header
  `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`.
- `Future<Result<GithubUser>> validateToken(String token)` → `GET /user`.
  - On success also inspects the `X-OAuth-Scopes` response header to detect
    missing scopes (`repo`, `read:org`); a missing-scope result is surfaced as a
    distinct failure message.
- `Future<Result<List<GithubRepo>>> listAccessibleRepos()` →
  `GET /user/repos?affiliation=owner,collaborator,organization_member&per_page=100&sort=pushed`,
  **paginated** by following the `Link` header `rel="next"` until exhausted.
- A `MockAuthRepository` implements the same interface for tests / offline dev,
  matching the existing `MockPrInboxRepository` pattern.

**`services/secure_token_store.dart`**
- Thin wrapper over `flutter_secure_storage`: `read()`, `write(token)`,
  `delete()` for the GitHub token. Never logged.
- Web caveat (WebCrypto, keys don't survive browser-data clears) documented in a
  doc comment.

### Persistence

- **GitHub token** → `flutter_secure_storage` (key `github_token`).
- **Watched repo slugs** (`List<String>` of `owner/name`) → `shared_preferences`
  (key `watched_repos`).

### Presentation (`lib/features/repo_setup/presentation/`)

**`providers/auth_provider.dart`**
- `@Riverpod(keepAlive: true) authRepository` — provides the impl (mock swap
  point), mirroring `prInboxRepositoryProvider`.
- `@Riverpod(keepAlive: true) class AuthStateNotifier` — exposes a sealed
  `AuthState`:
  - `Unauthenticated`, `Validating`, `Authenticated(GithubUser)`,
    `AuthError(String message)`.
  - On `build()`: read stored token; if present, validate and resolve to
    `Authenticated` or back to `Unauthenticated` (+ surface error). If absent →
    `Unauthenticated`.
  - `Future<void> submitToken(String token)` — validate, on success store token
    + set `Authenticated`, on failure set `AuthError`.
  - `Future<void> signOut()` — delete token, clear state.
- `@Riverpod(keepAlive: true) class WatchedReposNotifier extends ...` —
  `List<String>` of slugs, hydrated from `shared_preferences`; `toggle(slug)`,
  `isWatched(slug)`, persists on every change.
- `@riverpod Future<List<GithubRepo>> accessibleRepos(Ref)` — calls
  `listAccessibleRepos()`; consumed by step 2.

**`view/setup_screen.dart`** (`HookConsumerWidget`, `routeName = 'setup'`)
- Centered Tether card on the dark canvas. Top step-indicator bar (2 segments).
- **Step 1 — Connect:**
  - Crosshair "T" mark, "TurboBoard" title, subtitle.
  - `TetherTextField` (obscured) for the PAT.
  - Scope hint: "Needs `repo` and `read:org` scopes."
  - Link/hint to `github.com/settings/tokens`.
  - "Validate & continue" `TetherActionButton` (loading while validating).
  - Inline error text on invalid/expired token or missing scopes.
  - Advances to step 2 on `Authenticated`.
- **Step 2 — Watched repos:**
  - Search/filter `TetherTextField` (client-side filter by `nameWithOwner`).
  - Scrollable list grouped by owner; each row a `TetherListItem` showing repo
    name + description + a watched toggle. Loading/error/empty states.
  - "Open PR Board →" `TetherActionButton`, enabled only when ≥1 repo selected;
    navigates to `/`.

**`view/widgets/`**
- `auth_step_indicator.dart` — the 2-segment progress bar.
- `repo_pick_list.dart` — the grouped, filterable, toggle list (step 2 body).

### Routing (`lib/shared/router/app_router.dart`)

- Add `GoRoute('/setup', name: SetupScreen.routeName)`. Keep `/` → board.
- `redirect` callback reads `AuthStateNotifier`:
  - `Unauthenticated`/`AuthError` and not on `/setup` → redirect to `/setup`.
  - `Authenticated` and on `/setup` → redirect to `/`.
  - `Validating` → no redirect (let the current screen show progress).
- Router watches the auth provider so redirects re-run on state change.

### Error handling

- All Dio/network errors caught inside `AuthRepositoryImpl` → `Result.failure`
  with a user-facing message; details `log()`-ged (never the token).
- Distinct messages: invalid/expired token (401), missing scopes (header probe),
  network/unknown.
- UI renders failures as inline text under the relevant field; never a raw
  exception string.

### Testing (`test/features/repo_setup/`)

- `data/repositories/auth_repository_test.dart` (mockito-mocked Dio):
  - valid token → `Authenticated` user.
  - 401 → failure with invalid-token message.
  - missing-scope header → scope failure message.
  - `listAccessibleRepos` follows `Link` pagination and concatenates pages.
- `presentation/providers/auth_provider_test.dart` (ProviderContainer, overrides):
  - boot with stored token → validates → `Authenticated`.
  - boot with no token → `Unauthenticated`.
  - `submitToken` success/failure transitions.
  - `WatchedReposNotifier.toggle` adds/removes + persists.
- `presentation/view/setup_screen_test.dart` (widget):
  - step 1 validate flow (success advances, failure shows error).
  - step 2 toggle selection enables the "Open PR Board" button.

## Out of scope (A)

- Real PR inbox wiring and the 3-region shell (sub-project B).
- A full Settings screen — for A, a minimal route to re-open setup / sign out is
  enough; polish later.
- OAuth / GitHub App, webhooks, rate-limit dashboards.

## Pre-completion checklist (per CLAUDE.md)

- `dart run build_runner build -d` after models/providers.
- `dart format --line-length 120 --set-exit-if-changed .`
- `dart analyze`
- `flutter test`
