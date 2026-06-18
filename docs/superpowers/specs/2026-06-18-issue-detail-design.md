# Issue Detail — Design Spec

Drafted 2026-06-18. Companion to `docs/V2-ISSUES-SCOPE.md` and the Projects Board work
(`docs/superpowers/specs/2026-06-18-projects-board-design.md`). Design source:
`Issue Detail.dc.html` (Claude Design project `9666295b-7164-4a23-bc60-7334b33ea5fc`).

## Goal

A ProjectV2-enriched GitHub **Issue Detail** drawer that mirrors the shipped PR Detail: a
right-slide overlay over a scrim, reached by a route inside the app shell. It renders a GitHub
issue page enriched with ProjectV2 field data — markdown description, sub-issue task list, linked
PRs, full activity timeline + comment composer, and a project-field sidebar topped by an AI TL;DR.

This is **interactive**, not read-only. It supersedes the "read-only" line in `V2-ISSUES-SCOPE.md`
§"Out of scope" — that constraint is stale: the shipped PR Detail already writes (comment, review,
merge), and GitHub-web parity is the target here.

## Scope decisions (resolved during brainstorming)

- **Writes:** comment, close/reopen, **create branch from issue**, and **open with GitHub Desktop**
  — matching what GitHub web offers on an issue page.
- **AI:** both sidebar AI features ship — an on-demand **TL;DR** (mirrors the PR Summary path) and a
  **Suggest next action** button (new on-demand prompt).
- **Route + feature dir:** `/issue/:owner/:repo/:number`, feature at `lib/features/issue_detail/`,
  mirroring the `pr_detail` convention (owner is in the path because the GraphQL
  `repository(owner, name)` lookup needs it).
- **Entry points (all three wired now):** Projects Board issue cards, Lead Cockpit stuck-issue rows,
  and the PR Detail ↔ Issue cross-link.

## Architecture

New feature `lib/features/issue_detail/`, data/presentation split, mirroring `pr_detail`:

```
lib/features/issue_detail/
├── data/
│   ├── models/        issue_detail.dart
│   ├── queries/       issue_detail_query.dart · issue_mutations.dart
│   └── repositories/  issue_detail_repository.dart   (interface + Github + Mock)
└── presentation/
    ├── providers/     issue_detail_provider.dart · issue_composer_provider.dart
    └── view/          issue_detail_screen.dart
        └── widgets/   issue_description_card · issue_sub_issues_card · issue_linked_prs_card
                       · issue_timeline · issue_comment_composer · issue_sidebar_fields
                       · issue_development_card
```

AI features extend the existing `ai` feature (no new feature dir). Reuses cockpit `IssueStatus` /
`IssuePriority`, the board's `PrCiState` / `PrReviewState`, `GithubApiClient`, the BYOK
`AnthropicApiClient`, and shared UI widgets (`MarkdownBody`, `TbBadge`, `OpenOnGitHubButton`,
`OpenInGitHubDesktopButton`, `TbAvatarTile`, `TbSignalDot`).

### Reuse vs new — boundaries

- **Reused, read-only (no conflict with board work):** `IssueStatus`, `IssuePriority`
  (`lead_cockpit/data/models/cockpit_data.dart`); `PrCiState`, `PrReviewState`
  (`projects_board/data/models/board_data.dart`).
- **Lifted/shared drawer chrome:** the scrim + `SlideTransition` + `_DrawerPanel` + header
  icon/close buttons currently private in `pr_detail_screen.dart`. Extract the reusable bits into a
  shared `lib/shared/ui/widgets/detail_drawer.dart` (a `DetailDrawerScaffold` taking title, width,
  onClose, onRefresh, child) and have both PR Detail and Issue Detail use it. This avoids
  copy-pasting ~120 lines and keeps the two drawers visually identical. (If extraction proves
  noisy, fall back to a private copy in `issue_detail_screen.dart` — decided in the plan.)
- **New, additive:** everything under `issue_detail/`, two `AiRepository` methods + two prompts,
  one `GoRoute`.

## Data models — `data/models/issue_detail.dart`

All Freezed `sealed class` with `fromJson` where they round-trip.

- `enum IssueState { open, closed }`
- `IssueLabel`: `String name; String colorHex;`
- `IssueRef`: `String repo; int number; String title; IssueStatus? status;` — used for the parent
  epic and any relationship rows.
- `SubIssue`: `int number; String title; IssueStatus status; bool done; String? assignee;`
- `LinkedPr`: `String owner; String repo; int number; String title; bool isDraft;
  PrCiState ciState; PrReviewState reviewState; PrLinkMergeState mergeState;`
  - `enum PrLinkMergeState { open, merged, closed, draft }` (drives the third dot + label in the
    Linked PRs card).
- `enum IssueEventKind { opened, comment, closed, reopened, labeled, assigned, unassigned,
  crossReferenced, renamed }`
- `IssueTimelineEvent`: `String author; DateTime createdAt; IssueEventKind kind;
  @Default('') String bodyMarkdown; String? detail;` — mirrors `PrTimelineEvent`.
- `IssueDetail`:
  - Identity: `String repo` ("owner/name"); `String? id` (GraphQL node id, for mutations);
    `int number`; `String title`; `String? url`.
  - Core: `IssueState state`; `String author`; `DateTime? createdAt`;
    `@Default('') String bodyMarkdown`; `@Default(0) int commentCount`.
  - People/labels: `@Default([]) List<String> assignees`; `@Default([]) List<IssueLabel> labels`;
    `@Default([]) List<String> participants`.
  - ProjectV2 fields: `IssueStatus? status`; `IssuePriority? priority`; `String? sprint`;
    `int? points`; `String? milestone`.
  - Relations: `IssueRef? parent`; `@Default([]) List<SubIssue> subIssues`;
    `@Default([]) List<LinkedPr> linkedPrs`.
  - Activity: `@Default([]) List<IssueTimelineEvent> timeline`.
  - Action gating: `@Default(false) bool viewerCanUpdate` (gates Close/Reopen + Comment);
    `String? repoDefaultBranchOid` (base commit for Create branch).
  - Getters: `int get subDone => subIssues.where((s) => s.done).length;`
    `int get subTotal => subIssues.length;` `bool get hasSubIssues => subTotal > 0;`
    `bool get isClosed => state == IssueState.closed;`

## Queries — `data/queries/`

### `issue_detail_query.dart` (one paged-enough query)

`query($owner, $name, $number)` →
`repository(owner, name) { defaultBranchRef { target { oid } } issue(number: $number) { … } }`

Issue selection covers:
- `id number title url state body createdAt author { login }`
- `comments(first: 50) { totalCount nodes { author { login } body createdAt } }`
- `labels(first: 20) { nodes { name color } }`
- `assignees(first: 10) { nodes { login } }`
- `participants(first: 10) { nodes { login } }`
- `milestone { title }`
- `subIssuesSummary { total completed }` and `subIssues(first: 50) { nodes { number title state
  assignees(first:1){nodes{login}} } }`
- `closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number title isDraft
  state url repository { name owner { login } } reviewDecision commits(last:1){ nodes { commit {
  statusCheckRollup { state } } } } } }` — the Linked PRs.
- `parent { number title state repository { nameWithOwner } }` (sub-issues GA field) — the epic.
- `timelineItems(first: 60, itemTypes: [ISSUE_COMMENT, CLOSED_EVENT, REOPENED_EVENT, LABELED_EVENT,
  ASSIGNED_EVENT, UNASSIGNED_EVENT, CROSS_REFERENCED_EVENT, RENAMED_TITLE_EVENT]) { nodes { … } }`
- `projectItems(first: 5) { nodes { fieldValues(first: 20) { nodes { … Status/Priority/Sprint/
  Complexity by field name } } } }` — same field-value shape the board mapper already parses; the
  Status/Priority/Sprint/Complexity extraction logic is shared with `board_mapper.dart` where
  practical (extract a small `projectFieldValues(...)` helper rather than duplicate the switch).

### `issue_mutations.dart`

- `addComment(input: {subjectId, body})` — reuse the exact mutation text already in
  `pr_mutations.dart`; either import it or keep a copy (decide in plan; importing is preferred).
- `closeIssue(input: {issueId, stateReason: COMPLETED})` → `{ issue { state } }`
- `reopenIssue(input: {issueId})` → `{ issue { state } }`
- `createLinkedBranch(input: {issueId, oid, name})` → `{ linkedBranch { ref { name } } }`

## Repository — `data/repositories/issue_detail_repository.dart`

```dart
abstract interface class IssueDetailRepository {
  Future<Result<IssueDetail>> fetchDetail(String owner, String name, int number);
  Future<Result<bool>> addComment(String subjectId, String body);
  Future<Result<bool>> closeIssue(String issueId);
  Future<Result<bool>> reopenIssue(String issueId);
  /// Returns the created branch name on success.
  Future<Result<String>> createBranch(String issueId, String oid, String name);
}
```

- `GithubIssueDetailRepository(GithubApiClient)` — pure node→model mapping in a top-level
  `issueDetailFromNode(owner, name, repoNode, issueNode)` (IO-free, unit-testable with fixtures),
  mirroring `prDetailFromNode`. `viewerCanUpdate` from `issue.viewerCanUpdate` (add to query).
- `MockIssueDetailRepository` — returns the `Issue Detail.dc.html` sample (auth-rotation issue with
  acceptance criteria, 5 sub-issues, 2 linked PRs, a timeline, full sidebar fields). Mutations
  return `Result.success`. Exported for widget tests and tokenless runs.

Error handling: `try/catch` only in the repo; surface `Result.failure` above. Scope-aware message
for missing `read:project` (reuse the board repo's phrasing).

## AI — extend the `ai` feature

`AiRepository` (interface + `AnthropicAiRepository`):

```dart
/// 3-bullet TL;DR of the issue (title + body + key fields). Mirrors summarize().
Future<Result<List<String>>> summarizeIssue(IssueDetail issue);
/// One short recommended next action, grounded in state + fields + linked PRs.
Future<Result<String>> suggestNextAction(IssueDetail issue);
```

Prompts in `ai_prompts.dart`: `buildIssueSummaryPrompt(IssueDetail)` (reuse `parseBullets`) and
`buildNextActionPrompt(IssueDetail)` (returns a single terse sentence). No diff fetch — the issue
body + fields are enough. Regenerate mockito mocks after the interface change; existing AI tests
must still compile.

## Providers — `presentation/providers/`

- `issueDetailProvider(owner, repo, number)` — autodispose `Future<IssueDetail>`; `keepAlive()` on
  success (mirror `prDetailProvider`). Surfaces repo failure as an `AsyncError`.
- `issueComposerProvider` (mirror `pr_composer_provider`) — holds the comment draft + submit state;
  exposes `comment(body)`, `close()`, `reopen()` delegating to the repo, then invalidates
  `issueDetailProvider`.
- `issueSummaryController` and `issueNextActionController` — on-demand `@riverpod` notifiers with
  `AsyncValue<…>? build() => null` (null = not requested), `generate(IssueDetail)` + `clear()`.
  Never auto-fire. Mirror `PrSummaryController` / the cockpit brief controller.
- `issueDetailRepositoryProvider` (keepAlive) → builds `GithubIssueDetailRepository` from
  `githubApiClientProvider`.

## Presentation — `presentation/view/`

`issue_detail_screen.dart` — `ConsumerWidget`, `static routeName = 'issueDetail'`. Uses the shared
`DetailDrawerScaffold` (scrim + slide + 58px header bar "ISSUE #n" with refresh + close). Body has
loading / error (with Retry) / data states.

`_DetailBody` layout (LayoutBuilder, two-column ≥720px, stacked below — same breakpoint as PR
Detail):

- **Header section:** repo line + `OpenOnGitHubButton`; title + `#number`; state badge
  (Open → green, Closed → gray/red); author avatar + "opened {relative}"; comment count.
- **Main (left):**
  - `issue_description_card` — author header + `MarkdownBody(bodyMarkdown)`. `MarkdownBody` already
    renders task-list checkboxes, fenced code, and tables, so the design's acceptance-criteria
    checklist / code block / table need no bespoke widgets.
  - `issue_sub_issues_card` — header (`{done}/{total} done` + progress bar), rows (checkbox glyph,
    number, title with strikethrough when done, status badge, assignee avatar). Row tap pushes that
    sub-issue's detail.
  - `issue_linked_prs_card` — rows (PR number, title, Draft badge, CI dot, Review dot, merge-state
    dot + label). Row tap pushes `/pr/{owner}/{repo}/{number}`.
  - **Activity:** `issue_timeline` (events + comment cards, chronological, stable sort like
    `_timelineFrom`) then `issue_comment_composer` (textarea, "Markdown supported" hint,
    **Close/Reopen issue** button, **Comment** button). Composer + close gated on `viewerCanUpdate`.
- **Sidebar (right, 322px; stacked-first on phone):**
  - `issue_summary_card` (AI) — gradient top rule, "AI · TL;DR", bullets when generated, a generate
    CTA when null, **"✦ Suggest next action"** button driving `issueNextActionController`
    (`issue_next_action_card` renders its result).
  - `issue_sidebar_fields` — assignees (avatar + login rows), labels (color chips), Status + Priority
    chips, Sprint / Complexity / Milestone field rows, parent-epic relationship row, participant
    avatar cluster. Sub-issue progress bar mirrored here per design.
  - `issue_development_card` — **Create branch from issue** (calls `createBranch`, default name
    `{number}-{slugified-title}`, base `repoDefaultBranchOid`; shows the created branch + a hint to
    fetch it), **Open with GitHub Desktop** (`OpenInGitHubDesktopButton`), **Open on GitHub**.

AI widgets live in `ai/presentation/view/widgets/`: `issue_summary_card.dart` (mirror
`pr_summary_card.dart`) and `issue_next_action_card.dart` (mirror `reply_drafter.dart`).

## Routing — `lib/shared/router/app_router.dart`

Add inside the ShellRoute `routes:` list:

```dart
GoRoute(
  path: '/issue/:owner/:repo/:number',
  name: IssueDetailScreen.routeName,
  pageBuilder: (context, state) => /* transparent/overlay page, like PR Detail */,
)
```

Match PR Detail's overlay page transition (so the scrim shows the board behind). Deep-linkable and
refresh-safe (path URL strategy is already on).

## Wiring the three entry points

1. **Projects Board** — change the issue-card tap in `ProjectsBoardScreen` from "open GitHub URL"
   to `context.push('/issue/${card.owner}/${card.repo}/${card.number}')`. PR cards keep pushing
   `/pr/...`. (Touches board work's screen file — coordinate the one-line change; additive.)
2. **Lead Cockpit** — `stuck_issue_row.dart`: route its tap to the in-app drawer instead of the
   GitHub URL helper.
3. **PR Detail cross-link** — add `closingIssuesReferences(first: 10) { nodes { number title state
   repository { name owner { login } } } }` to `pr_detail_query.dart`, carry them on `PrDetail`
   (`@Default([]) List<IssueRef> linkedIssues`), and add a "Linked issues" card to the PR Detail
   sidebar that pushes `/issue/...`. This is the only change outside `issue_detail/` + the additive
   AI/router edits, and the only PR-side scope.

## Responsive

- **≥720px drawer width:** two columns (main + 322px sidebar).
- **<720px:** single column; per the design's phone variant, AI TL;DR renders first, then
  description, sub-issues, sidebar field cards, timeline, composer.
- Drawer width: `avail*0.96` on phone, else `min(avail*0.96, (avail*0.7).clamp(560,1060))` — the
  exact formula PR Detail uses.

## Testing

Mirror `pr_detail` tests. Each file opens with a test-summary comment.

- `issue_detail_repository_test.dart` — `issueDetailFromNode` parses issue fields, sub-issues,
  linked PRs (CI/review/merge mapping), ProjectV2 status/priority/sprint/complexity, timeline order,
  `viewerCanUpdate`; mock repo returns the sample; mutations return success.
- `issue_detail_provider_test.dart` — provider yields detail on success, surfaces failure as error;
  composer comment/close/reopen invalidate; AI controllers null → loading → data, error path,
  `clear()` resets to null.
- `ai_issue_test.dart` — `buildIssueSummaryPrompt` embeds title/body/fields and yields bullets;
  `buildNextActionPrompt` asks for one action; both parse model output.
- Widget tests for `issue_sub_issues_card`, `issue_linked_prs_card`, `issue_comment_composer`
  (close gated on `viewerCanUpdate`), `issue_development_card` (create-branch CTA).

## Out of scope (this spec)

- Issue Inbox / Needs-Attention-for-issues views (separate feature, later — `V2-ISSUES-SCOPE`).
- Editing labels/assignees/status/priority/sprint from the drawer (read those fields; only
  comment/close/reopen/create-branch write).
- Jira write-back (Jira Key stays a read-only deeplink if present).
- Snapshot history / live updates.

## Design tokens

Dark-first, verbatim from `Issue Detail.dc.html` and the shared `tb_tokens.dart`: card radius 8 /
badge radius 2; drawer top bar 58px (phone 52px); sidebar 312–322px; 2-col gap 18px; status-dot
colors via the cockpit/board palettes; AI accent gradient `#0a3161 → #13acff → #0a3161`.
