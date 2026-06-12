# PR Detail (read-only) — Design

**Date:** 2026-06-11
**Feature:** `pr_detail` (sub-project D of TurboBoard v1)
**Status:** Approved (user delegated autonomous build on master)

## Context

Sub-projects A (Auth + Repo Setup) and B (PR Board + shell) are complete. A user
signs in with a PAT, picks watched repos, and sees a board of open PRs in
four review-state columns inside the responsive Tether shell. PR cards are
currently display-only.

Sub-project D adds the **read-only PR Detail** surface: tapping a PR card opens a
deep-linkable detail screen showing the PR header, CI checks, reviewers, last
commit, and the conversation timeline (comments + review summaries).

### Decisions locked during brainstorming

- **Read-only.** No composer / posting comments or reviews to GitHub — v1
  explicitly lists "posting drafts/comments to GitHub" as out of scope. The
  Reply Drafter (sub-project E) later adds a copy-to-clipboard draft; AI Summary
  (E) also hangs off this screen. D leaves room for them but builds neither.
- **Markdown rendering via `gpt_markdown`.** `flutter_markdown` is discontinued;
  `gpt_markdown` (pure-Dart, renders markdown → widgets, no native plugins) is
  used to render PR/comment `body` markdown. Must be verified to resolve and
  web-build cleanly before use.
- **Conversation = issue comments + top-level review summaries**, merged into one
  time-ordered timeline. Inline file-diff review threads are out of scope for D.

### Out of scope (D)

- Posting/editing comments or reviews (any GitHub mutation).
- Inline code-review threads (file + line + diff hunks).
- AI Summary and Reply Drafter (sub-project E).
- Merging PRs, file/diff browsing, commit lists beyond the latest commit.

### Design reference

- `design/mockup.html` — the detail screen (`renderDetail`, `.detail`/`.d-head`/
  `.panel` checks list / `.thread` comments / `.sidecard` reviewers, lines
  ~426–490). Note the mockup's composer is omitted in D (posting is out of scope).
- Access Tether tokens via `context.appColors`; reuse the signal-color mapping
  from B (passing=green, pending=yellow, failing=red, etc.).

## Architecture

A new `pr_detail` feature under `lib/features/pr_detail/` with the standard
data/presentation split. PR data for one PR is fetched with a single GraphQL
query POSTed through the existing `GithubApiClient` (shared, token-authed). The
detail screen is a routed child inside the existing `AppShell` (the nav rail
stays visible), reached via a deep-linkable route. Errors are caught only in the
repository and surfaced as `Result<T>`.

## Routing

Add a route under the existing `ShellRoute` (so the rail persists):
`/pr/:owner/:repo/:number`, name `PrDetailScreen.routeName = 'prDetail'`. The
three path params are passed to the screen. This is deep-link-safe on web
refresh. `PrCard` becomes tappable and navigates here via
`context.goNamed('prDetail', pathParameters: {owner, repo, number})`.

## Data layer (`lib/features/pr_detail/data/`)

### Models (`models/`, Freezed + JSON where useful)

- **`pr_detail.dart` → `PrDetail`**: `repo` (owner/name), `number`, `title`,
  `state` (`PrState { open, closed, merged }`), `isDraft`, `author` (login),
  `baseRefName`, `headRefName`, `bodyMarkdown` (String, may be empty),
  `reviewDecision` (reuse `PrReviewState` from pr_inbox or a local mapping),
  `lastCommit` (`PrCommit?`), `checks` (`List<PrCheck>`), `reviewers`
  (`List<PrReviewer>`), `timeline` (`List<PrTimelineEvent>`).
- **`pr_check.dart` → `PrCheck`**: `name`, `state` (`PrCheckState { success,
  pending, failure, neutral }`), `summary` (String? — e.g. conclusion text).
- **`pr_reviewer.dart` → `PrReviewer`**: `login`, `state` (`PrReviewerState {
  approved, changesRequested, commented, pending }`).
- **`pr_commit.dart` → `PrCommit`**: `abbreviatedOid`, `messageHeadline`,
  `committedDate` (DateTime?).
- **`pr_timeline_event.dart` → `PrTimelineEvent`**: `author` (login),
  `bodyMarkdown`, `createdAt` (DateTime), `kind` (`PrEventKind { comment,
  review }`), `reviewState` (`PrReviewerState?` — set when kind == review).

Each model is small and single-purpose. Mapping from the GraphQL response lives
in pure top-level functions in the repository file (testable without a client),
mirroring `prFromSearchNode` in pr_inbox.

### Query (`queries/pr_detail_query.dart`)

A raw-string GraphQL document `prDetailQuery` with variables `$owner`, `$name`,
`$number`:

```graphql
query PrDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number title body isDraft state url
      baseRefName headRefName
      author { login }
      reviewDecision
      reviewRequests(first: 50) {
        nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } }
      }
      latestReviews(first: 50) {
        nodes { author { login } state body submittedAt }
      }
      comments(first: 100) {
        nodes { author { login } body createdAt }
      }
      commits(last: 1) {
        nodes {
          commit {
            abbreviatedOid messageHeadline committedDate
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  __typename
                  ... on CheckRun { name conclusion status }
                  ... on StatusContext { context state }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

- **Reviewers** combine `reviewRequests` (→ `pending`) with `latestReviews`
  (state → approved/changesRequested/commented), keyed by login; a submitted
  review supersedes a pending request for the same login.
- **Checks** map each `contexts` node: `CheckRun.conclusion`
  (SUCCESS→success, FAILURE/TIMED_OUT/STARTUP_FAILURE→failure, null/in-progress
  status→pending, NEUTRAL/SKIPPED→neutral) and `StatusContext.state`
  (SUCCESS→success, FAILURE/ERROR→failure, PENDING/EXPECTED→pending). Name comes
  from `CheckRun.name` or `StatusContext.context`.
- **Timeline** = `comments` (kind comment) + `latestReviews` with a non-empty
  body (kind review, carrying reviewState), sorted ascending by time.

### Repository (`repositories/pr_detail_repository.dart`)

- `abstract interface class PrDetailRepository` with
  `Future<Result<PrDetail>> fetchDetail(String owner, String name, int number)`.
- `GithubPrDetailRepository` (ctor: `GithubApiClient`): calls
  `graphql(prDetailQuery, {owner, name, number})`, maps
  `repository.pullRequest` → `PrDetail`. A null `pullRequest` (not found / no
  access) → `Result.failure('Pull request not found.')`. All throws caught →
  `Result.failure`.
- `MockPrDetailRepository` returns a canned `PrDetail` for tests/offline.

## Presentation (`lib/features/pr_detail/presentation/`)

- **`providers/pr_detail_provider.dart`**:
  - `@Riverpod(keepAlive: true) prDetailRepository` → `GithubPrDetailRepository(ref.watch(githubApiClientProvider))`.
  - `@riverpod Future<PrDetail> prDetail(Ref, {required String owner, required String name, required int number})`
    (family) → calls the repo, returns data or throws.
- **`view/pr_detail_screen.dart`** (`ConsumerWidget`, `routeName='prDetail'`),
  ctor takes `owner`, `repo`, `number`:
  - `prDetail(...).when`: loading → spinner; error → message + Retry
    (invalidate); data → the detail body.
  - Body (centered, max-width ~940): a back affordance ("← Back to board" →
    `context.go('/')`); header (`owner/repo`, title + `#number`, state badge
    Open/Draft/Merged/Closed, review + derived CI badges, `author → base`);
    a two-region layout on wide widths (main + aside), single-column when narrow:
    - **Main**: `PrChecksPanel` (list of `PrCheck` rows with a signal dot +
      name + summary), then the conversation `PrTimeline` (each event: author,
      relative time, optional review-state badge, `gpt_markdown`-rendered body).
    - **Aside**: `PrReviewersCard` (reviewer login + state badge) and a
      `PrCommitCard` (last commit abbreviatedOid + headline + relative date).
- **`view/widgets/`**: `pr_checks_panel.dart`, `pr_timeline.dart`
  (+ a `PrTimelineTile`), `pr_reviewers_card.dart`, `pr_commit_card.dart`,
  `markdown_body.dart` (thin wrapper around `gpt_markdown` with app text styling
  so the dependency is isolated to one file).

### PrCard becomes tappable

`PrCard` (pr_inbox) gains an `onTap` that navigates to the detail route. Because
`pr_inbox` would then import routing/navigation, the cleanest seam is: `PrCard`
exposes an optional `VoidCallback? onTap`, and the board (`pr_inbox_screen`)
supplies `() => context.goNamed('prDetail', pathParameters: {...})`. This keeps
`PrCard` navigation-agnostic and testable.

## Dependency

Add `gpt_markdown` to `pubspec.yaml`. Before relying on it: confirm it resolves
and that `flutter build web` still succeeds (it is pure Dart, so expected to
support all six targets). Isolate its use behind `markdown_body.dart`.

## Error handling

- Repository catches all network/GraphQL errors → `Result.failure` (generic
  user-facing message; token never logged).
- `pullRequest == null` → distinct "not found" failure.
- Screen renders loading / error-with-retry states; empty timeline/checks/
  reviewers render a subtle "None" rather than blank.

## Testing (`test/features/pr_detail/`)

- `data/queries/pr_detail_query_test.dart` — doc is a raw string; contains the
  key fields (smoke).
- `data/repositories/pr_detail_repository_test.dart` (mocked Dio via
  GithubApiClient): maps a full pullRequest payload → PrDetail (state, draft,
  base/head, author, body); checks mapping across success/failure/pending/
  neutral; reviewers merge (pending request + submitted review supersede);
  timeline merges comments + reviews sorted by time; `pullRequest: null` →
  failure; GraphQL error → failure.
- `presentation/view/pr_detail_screen_test.dart` (widget): renders header,
  checks, reviewers, timeline from a mock repo; loading and error+retry states.
- `presentation/view/widgets/*` — `PrChecksPanel` shows a row per check with the
  right signal; `PrTimeline` renders one tile per event with review-state badge;
  `markdown_body` renders given markdown text.
- `pr_inbox` board: tapping a `PrCard` triggers its `onTap` (navigation wired in
  the screen); router: `/pr/:owner/:repo/:number` resolves to `PrDetailScreen`
  inside the shell.
- Existing A + B tests stay green.

## Pre-completion checklist (per CLAUDE.md)

- `dart run build_runner build -d` after models/providers.
- `dart format --line-length 120 --set-exit-if-changed .`
- `dart analyze` → clean.
- `flutter test` → all pass.
- `flutter build web --no-tree-shake-icons` compiles (confirms gpt_markdown is web-safe).
- Manual smoke (deferred to the user): open a real PR's detail from the board.
