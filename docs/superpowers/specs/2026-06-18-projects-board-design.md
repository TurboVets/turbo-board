# Projects Board — Design Spec

**Date:** 2026-06-18
**Branch:** `feat/projects-board`
**Design source:** Claude Design project `9666295b…`, file `Projects Board.dc.html`
**Status:** Approved pending review

## Goal

A GitHub ProjectV2 **kanban board** view: items grouped into Status columns
(Triage · Not Started · In Progress · In Review · Done), mixed issue + PR cards
showing priority, story points, sub-issue progress, stale age, assignees, and —
for PRs — CI / review signal dots. Each column carries a one-line "insight"
summary of what's stuck. Read-only in v1.

This is the first of two features; **Issue Detail** follows in a separate cycle.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Data source | **Live GitHub**, reusing the lead_cockpit ProjectV2 query + pagination + project picker |
| Card interaction | **Read-only** — no drag. PR cards open the existing PR Detail overlay; issue cards open on GitHub (issue detail is the next feature) |
| Placement | **New feature** `lib/features/projects_board/` + route `/projects` |
| Column "AI" summary | **Real Anthropic call** (BYOK), **on-demand via a CTA** — never auto-fires — see below |

## Scope

### In
- Board screen: topbar + horizontally-scrolling Status columns, issue + PR cards.
- Live fetch of the **currently selected** ProjectV2 board (reuses
  `SelectedProjectNotifier`, shared with the cockpit and persisted to prefs).
- In-board project picker (reuses `ProjectPickerList`) to switch boards.
- Per-column insight line — **real Anthropic summary** (BYOK), one batched call,
  triggered **on demand by a topbar CTA** (never auto). Board renders without it.
- Responsive: desktop multi-column / tablet narrower / phone single-column with
  selector pills.
- States: loading skeleton, empty board, per-column empty, error + retry.
- Nav rail + bottom nav entry; route registered.
- Card tap: PR → `/pr/:owner/:repo/:number`; Issue → open on GitHub.

### Out (follow-ups, noted not built)
- Drag-to-change-status + ProjectV2 field mutation (read-only v1).
- Group-by anything other than Status; Filter panel (topbar buttons render but
  are inert/hidden in v1).
- Per-column *drill-in* AI (chat / "explain this column") — v1 ships the one-line summary only.
- User-owned (non-org) boards — query uses `organization(login:)`, same limit
  the cockpit has today.
- Live polling ("Live" pulse from the mockup) → v1 shows manual refresh only.

## Architecture

New feature, mirrors the established data/presentation split. **Reuses** the
cockpit's network plumbing; **does not** touch `cockpit_mapper.dart` or
`CockpitData`.

```
lib/features/projects_board/
├── data/
│   ├── models/
│   │   └── board_data.dart          # BoardCard, BoardColumn, ProjectBoardData (+ enums)
│   └── repositories/
│       ├── projects_board_repository.dart   # interface + Github impl + Mock impl
│       └── board_mapper.dart                # pure: project items -> ProjectBoardData
└── presentation/
    ├── providers/
    │   └── projects_board_provider.dart     # repo provider + board future provider
    └── view/
        ├── projects_board_screen.dart       # HookConsumerWidget; responsive switch
        └── widgets/
            ├── board_column.dart            # column: accent, header, insight, cards
            ├── board_card.dart              # issue/PR card
            ├── board_topbar.dart            # title, picker, group-by, refresh
            └── phone_column_selector.dart   # pills (phone only)
```

### Shared query change (additive, safe)

`lib/features/lead_cockpit/data/queries/project_board.dart` —
`projectBoardQuery` currently fetches only `... on Issue`. Extend the `content`
selection with a `... on PullRequest` branch:

```graphql
... on PullRequest {
  number title url isDraft state reviewDecision
  repository { name }
  assignees(first: 5) { nodes { login } }
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
}
```

This is **additive**: the cockpit's `_BoardItem.parse` returns `null` for any
non-Issue content today, so the cockpit is unaffected. The board's own mapper
handles both `__typename`s.

> Rename note: the file's doc-comment says "Issues" only; update it to "Issues
> and PRs" since the query now spans both.

### Data models (`board_data.dart`, Freezed)

```dart
enum BoardItemType { issue, pullRequest }
enum PrCiState { passing, failing, pending, none }       // statusCheckRollup
enum PrReviewState { approved, changesRequested, review, none } // reviewDecision

BoardCard {
  String id;                 // node id or owner/repo#number
  BoardItemType type;
  String repo;               // short repo name -> TbRepoColor.forSlug
  int number;
  String title;
  bool isDraft;
  IssueStatus status;        // reuse cockpit enum
  IssuePriority? priority;   // reuse cockpit enum
  int? points;               // complexity
  int? subDone, subTotal;
  int? staleDays;            // set when aged past stuckAfterDays
  List<String> assignees;    // logins -> TbAvatar.initials/bgFor
  PrCiState? ciState;        // PR only
  PrReviewState? reviewState;// PR only
  String? url;               // owner/repo for routing derived at tap
}

BoardColumn {
  IssueStatus status;
  String label;              // CockpitPalette.statusLabel
  Color accent;              // see column accent map
  List<BoardCard> cards;
  int count;
  String? insight;           // heuristic summary, null when nothing notable
}

ProjectBoardData { String title; List<BoardColumn> columns; }
```

**Column accents** (from the mockup, not the cockpit status-dot map):
Triage `#BABBBF` · Not Started `#6E6E76` · In Progress `#0073FF` ·
In Review `#FFB000` · Done `#54AE39`. Add to `CockpitPalette` (or a new
`BoardPalette`) as `columnAccent(IssueStatus)`.

### Mapper (`board_mapper.dart`, pure)

`ProjectBoardData boardFromProjectItems(String title, List<Map> nodes, {required DateTime now})`

1. Parse each node into a `BoardCard`, handling Issue **and** PullRequest content
   (lift the field-value parsing pattern from `_BoardItem.parse`). PR CI from
   `statusCheckRollup.state` (SUCCESS→passing, FAILURE/ERROR→failing,
   PENDING→pending). PR review from `reviewDecision` (APPROVED→approved,
   CHANGES_REQUESTED→changesRequested, REVIEW_REQUIRED→review).
2. `staleDays` = `now - updatedAt` in days when `>= stuckAfterDays` (reuse the
   cockpit constant), else null.
3. Group into the 5 visible columns in fixed order. `cancelled` items are
   dropped. Items with null/unknown status bucket into **Not Started**.
4. The mapper does **not** populate `insight` — `BoardColumn.insight` stays
   null at the data layer. Insights are filled in by a separate AI provider
   (below) so the board renders instantly and the API call streams in after.
   The mapper does compute the **signal facts** each column carries
   (`ColumnFacts`: p0Unowned, missingEstimate, stuckCount, ciRedNumbers) so the
   AI prompt is grounded in numbers, not raw card dumps.

### Repository (`projects_board_repository.dart`)

- `abstract ProjectsBoardRepository { Future<Result<ProjectBoardData>> fetchBoard(); }`
- `GithubProjectsBoardRepository(GithubApiClient, {org, projectNumber})` —
  paginates `projectBoardQuery` (copy the loop from
  `GithubLeadCockpitRepository.fetchCockpit`, `_pageSize=100`, `_maxPages=10`),
  then `boardFromProjectItems`. Same scope-aware error message for the
  missing `read:project` case.
- `MockProjectsBoardRepository` — returns the design's sample columns (the exact
  cards in `Projects Board.dc.html`) so the screen renders without a token and
  is unit/widget testable.

### Providers (`projects_board_provider.dart`)

```dart
@Riverpod(keepAlive: true)
ProjectsBoardRepository projectsBoardRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final sel = ref.watch(selectedProjectProvider);     // shared with cockpit
  return GithubProjectsBoardRepository(client, org: sel?.owner ?? '', projectNumber: sel?.number ?? 0);
}

@riverpod
Future<ProjectBoardData> projectsBoard(Ref ref) async { ... keepAlive on success ... }
```

Reuses `availableProjectsProvider` for the picker.

### Column insights — on-demand AI (CTA, never auto)

Mirrors the cockpit's `CockpitBriefController` pattern exactly.

- **AI repo method** (`ai_repository.dart`): add
  `Future<Result<Map<IssueStatus, String>>> boardInsights(ProjectBoardData board)`.
  One batched Anthropic call. The prompt is grounded in the mapper's
  per-column `ColumnFacts` (counts, not raw cards) and asks for one terse line
  per non-empty column (≤ ~8 words, e.g. "2 stuck >5d · 1 P0 blocking · CI red on #155").
  Returns a status→line map; columns the model omits simply get no line.
- **Controller** (`projects_board_provider.dart`):

  ```dart
  @riverpod
  class BoardInsightsController extends _$BoardInsightsController {
    @override
    AsyncValue<Map<IssueStatus, String>>? build() => null; // null = not requested
    Future<void> generate(ProjectBoardData board) async {
      state = const AsyncValue.loading();
      final r = await ref.read(aiRepositoryProvider).boardInsights(board);
      state = switch (r) {
        ResultSuccess(:final data) => AsyncValue.data(data),
        ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
      };
    }
    void clear() => state = null;
  }
  ```

- **CTA**: a topbar button **"✨ AI Insights"** (cyan, matches the mockup's AI
  chip palette). States:
  - `null` (not yet run) → button enabled; **no insight lines** rendered on columns.
  - loading → button shows spinner; each non-empty column's insight slot shows a
    shimmer placeholder (project loading-indicator convention).
  - data → button becomes "↻ Regenerate"; columns with a line render the cyan
    "AI" insight row; columns without stay clean.
  - error → button shows a small error affordance + retry; surfaces the
    scope/no-key message (BYOK key missing → "Add an Anthropic key in Settings").
  - Invalidated/cleared whenever the selected project changes (stale board).
- `BoardColumn.insight` stays null at the data layer; the column widget reads the
  controller and overlays the line for its own status. No auto-fetch anywhere.

### Presentation

- **`projects_board_screen.dart`** (`HookConsumerWidget`): if no project selected
  → picker empty-state (reuse `ProjectPickerList`, mirror the cockpit empty
  state). Else watch `projectsBoardProvider`:
  - loading → skeleton columns
  - error → message + Retry (`ref.invalidate`)
  - data, no columns with cards → empty-board state
  - data → `LayoutBuilder`: width < `TbBreakpoints.mobile` → phone layout
    (`PhoneColumnSelector` + single `BoardColumn`); else desktop row of
    `BoardColumn`s in a horizontal scroller. Phone selected-column index held in
    a `useState` hook.
- **`board_topbar.dart`**: board title (Akshar), project-picker button (opens a
  popover/menu hosting `ProjectPickerList`; on select → `SelectedProjectNotifier.select`
  + invalidate board + `BoardInsightsController.clear()`), static "Group by:
  Status" + "Filter" (inert v1), the **"✨ AI Insights" CTA** (drives
  `BoardInsightsController`, states above), and a refresh `IconButton`
  (invalidate). Always show a loading indicator while the board future is
  refreshing (project convention).
- **`board_column.dart`**: width 236px (272 for In Progress), `surface` bg, 2px
  top accent, header (dot + label + count badge + ⋯), insight line (cyan 2px
  left bar + "AI" chip + text) — rendered only when `BoardInsightsController`
  holds a line for this column's status (shimmer while loading); scrollable card
  list, per-column empty dashed box, inert "+ Add item" affordance.
- **`board_card.dart`**: `surface2` bg, P0 cards get a `#5E2230` border; repo
  dot + name + `#number` + type glyph (◇ issue / ⑃ PR); 2-line title with inline
  Draft badge; meta row of `TbBadge`s (priority via `CockpitPalette.prioritySignal`,
  `N SP`, sub-progress bar + `done/total`, stale `⏱ Nd` orange); footer with PR
  CI/Rev dots + assignee monogram cluster (`TbAvatarTile`). Tap: PR → `context.push('/pr/{owner}/{repo}/{number}')` (owner from selected project); Issue → open `url` on GitHub.

### Routing & nav

- `app_router.dart`: add inside the ShellRoute
  `GoRoute(path: '/projects', name: ProjectsBoardScreen.routeName, builder: _opaque(const ProjectsBoardScreen()))`.
  `static const routeName = 'projectsBoard'`.
- `nav_rail.dart` + `bottom_nav.dart`: add a "Board" entry (icon
  `LucideIcons.kanban` or `columns3`) pointing at `/projects`, placed under
  WORKSPACE near Lead Cockpit.

## Testing

- `board_mapper_test.dart` — pure mapper over fixture JSON: issue + PR parsing,
  CI/review mapping, status bucketing (incl. null→Not Started, cancelled
  dropped), stale flag, `ColumnFacts` counts (p0Unowned / missingEstimate /
  stuckCount / ciRedNumbers).
- `projects_board_provider_test.dart` — `ProviderContainer` with an overridden
  repo (mock + failing) asserting board success/error; `BoardInsightsController`
  with an overridden `aiRepository` asserting null→loading→data and the error
  (no-key) path, and `clear()` on project change.
- `board_card_test.dart` (widget) — issue vs PR rendering, draft badge, P0
  border, sub-progress, stale chip, PR dots; tap routing.
- `projects_board_screen_test.dart` (widget) — no-project picker, loading,
  empty, error/retry, and phone vs desktop layout switch.
- Test summaries at the top of each file per CLAUDE.md.

## Pre-completion
`dart run build_runner build -d` (new Freezed models + providers) →
`dart format --line-length 120` → `dart analyze` → `flutter test`.

## Verified design tokens
bg `#0B0B0C` · canvas `#18181B` · surface `#1E1E21` · surface2 `#27272A` ·
border `#303036` · text `#F4F4F6` · muted `#A6A6AD` · dim `#6E6E76` ·
blue `#0073FF` · cyan `#13ACFF`. Signals & priority recipes already in
`TbSignal` / `CockpitPalette`. Card radius 8 / badge 2; column gap 14; card
padding 12 — all verbatim from `Projects Board.dc.html`.
```
