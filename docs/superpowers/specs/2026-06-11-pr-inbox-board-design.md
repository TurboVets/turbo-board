# GitHub-backed PR Inbox + 3-Region Shell — Design

**Date:** 2026-06-11
**Feature:** `pr_inbox` (real data) + shared app shell (sub-project B of TurboBoard v1)
**Status:** Approved for planning

## Context

Sub-project A (Auth + Repo Setup) is complete: a user pastes a GitHub PAT, it is
validated and stored in `flutter_secure_storage`, and watched repos are picked
and persisted. The app currently routes an authenticated user to `/` which shows
the **scaffold** `PrInboxScreen` — a Material `NavigationRail` + three hardcoded
mock PRs.

Sub-project B replaces that with the real product surface: the responsive
three-region Tether shell and a PR Inbox board fed by live GitHub data for the
watched repos.

### Decisions locked during brainstorming

- **Board layout: columns by review state** (kanban), matching `design/mockup.html`.
- **Data source: GraphQL** — one `search` query to `https://api.github.com/graphql`,
  POSTed through the existing token-authed `GithubApiClient.dio` (built in A). We
  do NOT use turbo_core's `GraphQLClient` because it is a singleton bound to
  `DioClient.I` (the TurboVets backend) — same rationale that led A to use a
  dedicated GitHub Dio. We POST the query ourselves and parse the JSON.
- **Columns use the four `PrReviewState` values** (Needs review / Changes
  requested / Approved / Waiting), derived from GitHub's `reviewDecision`. The
  "needs *my* review" (`review-requested:@me`) triage belongs to Needs Attention
  (sub-project C), not this board.
- **Sign-out** is wired into the rail footer in B (the `signOut()` notifier
  method already exists from A, currently unused).

### Out of scope (B)

- Needs Attention and Filters (sub-project C) — nav entries appear but are
  disabled placeholders.
- PR Detail (sub-project D) — PR cards are display-only (tap is a no-op).
- AI features (E). Live updates / webhooks. Pagination beyond the first page.

### Design reference

- `design/mockup.html` — the app shell (`.rail`/`.nav`/`.main`/`.topbar`, lines
  ~296–333) and the board. Left rail: brand mark, nav group, watched-repos list,
  user footer. Topbar: page title + actions.
- `design/README.md` — Tether v2.0 tokens and the signal palette (passing=green,
  pending=yellow, failing/changes=red, needs-review=blue, waiting=gray).
- Access tokens via `context.appColors`. Prefer `turbo_ui` components.

## Architecture

The shell is a shared widget under `lib/shared/ui/shell/` that wraps routed
content via a go_router `ShellRoute`. The board lives in the existing `pr_inbox`
feature, now backed by a real GraphQL-driven repository. The data layer follows
A's pattern: errors caught only in the repository, surfaced as `Result<T>`.

## Shell (`lib/shared/ui/shell/`)

**`app_shell.dart`** — `AppShell` (`HookConsumerWidget`): a `Scaffold` with a
`Row` of [left rail | routed child]. `LayoutBuilder` drives responsiveness:
- width ≥ 1100: full rail (icons + labels + watched repos + user footer).
- width < 1100 (tablet): icon-only collapsed rail (no labels; watched repos and
  user collapse to icons/avatar). No phone layout (min assumption ~840px).

**`nav_rail.dart`** — `AppNavRail`:
- Brand: Tether crosshair mark + "TURBO" wordmark.
- Nav group "Workspace": "PR Inbox" (active, navigates `/`), and disabled
  placeholders "Needs attention", "Filters", "Issues" (greyed, non-tappable —
  wired in C).
- "Watched repos" group: from `watchedReposProvider`, each row a colored signal
  dot + `owner/name`. Tappable rows are display-only in B.
- Footer: `GithubUser` avatar (initials fallback) + login from `authStateProvider`,
  plus a **sign-out** control calling `ref.read(authStateProvider.notifier).signOut()`
  (which clears the token and returns to `/setup` via the existing redirect guard).

The shell reads `authStateProvider` only for display; the route guard from A
still governs access.

## Routing change (`lib/shared/router/app_router.dart`)

Wrap the board route in a `ShellRoute` whose `builder` returns
`AppShell(child: child)`. `/setup` stays OUTSIDE the shell (bare wizard). The
auth redirect guard is unchanged.

```
ShellRoute(builder: (c, s, child) => AppShell(child: child),
  routes: [ GoRoute('/', PrInboxScreen) ])
GoRoute('/setup', SetupScreen)   // outside the shell
```

## Data layer (`lib/features/pr_inbox/data/`)

**Model change — `models/pr_data.dart`:** add `@Default(0) int commentsCount`.
Existing fields unchanged. The GraphQL → enum mapping:
- `reviewDecision`: `REVIEW_REQUIRED` → `needsReview`; `CHANGES_REQUESTED` →
  `changesRequested`; `APPROVED` → `approved`; `null` → `waitingOnAuthor`.
- `commits.nodes[0].statusCheckRollup.state`: `SUCCESS` → `passing`; `PENDING`/
  `EXPECTED` → `pending`; `FAILURE`/`ERROR` → `failing`; absent/null → `pending`.

**Query — `queries/search_open_prs.dart`:** a `const String` GraphQL document:
```graphql
query SearchOpenPrs($q: String!, $first: Int!) {
  search(query: $q, type: ISSUE, first: $first) {
    nodes {
      ... on PullRequest {
        number title isDraft updatedAt url
        author { login }
        repository { nameWithOwner }
        reviewDecision
        comments { totalCount }
        commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
      }
    }
  }
}
```
The `$q` variable is built as `is:pr is:open ` + the watched repos joined as
`repo:owner/name` terms (sorted, deduped). `$first` = 50.

**Service — `GithubApiClient`:** add
`Future<Map<String, dynamic>> graphql(String query, Map<String, dynamic> variables)`
that POSTs `{query, variables}` to `/graphql`; throws on non-200 or a non-empty
top-level `errors` array (message surfaced).

**Repository — `repositories/pr_inbox_repository.dart`:** add
`GithubPrInboxRepository implements PrInboxRepository`:
- ctor takes the `GithubApiClient` and the watched-repo slugs.
- `fetchOpenPrs()`: if no watched repos → `Result.success(const [])`. Else build
  `$q`, call `graphql(...)`, map `search.nodes` → `List<PrData>` (skip non-PR
  nodes), `Result.success`. All exceptions/GraphQL errors caught → `Result.failure`.
- `MockPrInboxRepository` stays (tests, offline).

## Presentation (`lib/features/pr_inbox/presentation/`)

**Provider — `providers/pr_inbox_provider.dart`:** `prInboxRepositoryProvider`
returns `GithubPrInboxRepository(ref.watch(githubApiClientProvider),
ref.watch(watchedReposProvider))` (so it refetches when watched repos change).
`prInboxProvider` unchanged in shape (returns `List<PrData>` or throws).

**Board — `view/pr_inbox_screen.dart` (rebuilt):**
- Topbar: title "PR Inbox" + a refresh `TetherIconButton` → `ref.invalidate(prInboxProvider)`.
- Body: `prInboxProvider.when(...)`:
  - `loading` → centered spinner.
  - `error` → centered message + "Retry" button (invalidate).
  - `data` empty + no watched repos → empty state ("Pick repos to watch in setup").
  - `data` → a `Row` of four `PrColumn`s, one per `PrReviewState`, in the order
    Needs review / Changes requested / Approved / Waiting. Each column: header
    (label + count badge) and a scrollable list of `PrCard`s. < 1100px wide →
    the four columns sit in a horizontally scrollable row.
- Keep pull-to-refresh (`RefreshIndicator`) wrapping the data view.

**`view/widgets/pr_card.dart`** — `PrCard` (Tether card): draft/PR icon, title
(ellipsis), `repo#number · author · updated <timeago>`, a CI badge, a review
badge, and a comment count. Tap is a no-op in B. Badge colors follow the signal
palette via `context.appColors`.

**`view/widgets/pr_column.dart`** — `PrColumn`: fixed-width (≈320) column with a
header (title + count) and the card list; empty column shows a subtle "None".

The board groups the flat `List<PrData>` by `reviewState` in the widget layer
(pure function, testable).

## Error handling

- All network/GraphQL failures caught in `GithubPrInboxRepository` → `Result.failure`
  with a user-facing message; details `log`-ged (never the token).
- A bad/expired token surfaces as a GraphQL/HTTP error → board error state with
  Retry. (Token re-entry is via sign-out → `/setup`.)
- Empty watched-repo set is a first-class empty state, not an error.

## Testing (`test/`)

- `data/services/github_api_client_test.dart` (mocked Dio): `graphql()` returns
  data on 200; throws on `errors[]`; throws on non-200.
- `data/repositories/pr_inbox_repository_test.dart`: query string built from
  watched repos (contains each `repo:owner/name`); response → `PrData` mapping
  for every review/CI state + draft + commentsCount; empty watched → empty list;
  failure path → `Result.failure`.
- `presentation/view/pr_inbox_screen_test.dart`: groups PRs into the four columns
  with correct counts; loading/error/empty states; refresh invalidates.
- `shared/ui/shell/app_shell_test.dart`: rail shows nav entries + watched repos +
  user login; tablet (<1100) collapses to icon rail; sign-out calls the notifier.
- Existing A and pr_inbox tests must stay green.

## Pre-completion checklist (per CLAUDE.md)

- `dart run build_runner build -d` after the model/provider changes.
- `dart format --line-length 120 --set-exit-if-changed .`
- `dart analyze` → clean.
- `flutter test` → all pass.
- Manual smoke on macOS + web with a real PAT and ≥1 watched repo.
