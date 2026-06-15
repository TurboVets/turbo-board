# AI Digests (Sprint Summarize / Sprint Digest / Weekly Digest) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three BYOK-Anthropic AI narratives — a full **sprint summary** and a scannable **sprint digest** on the Sprint Report screen, and a **weekly digest** on the Lead Cockpit — all driven by one shared card widget and the existing AI plumbing.

**Architecture:** Mirror the proven `sprintBrief` pattern exactly (prompt builder in `ai_prompts.dart` → `AiRepository` method calling `AnthropicApiClient.complete` → on-demand `AsyncValue<String>?` controller provider → card widget). The only new shared piece is `AiNarrativeCard`, a generalization of the cockpit brief's button/skeleton/panel/error widgets, reused by all three new narratives **and** retrofitted onto the existing cockpit brief so there is one card implementation. No new data fetching: summaries read the already-fetched `SprintReport`; the weekly digest reads the already-fetched `CockpitData` (framed as a week-in-review pulse). No new Freezed models — every narrative returns a `String`.

**Tech Stack:** Flutter, Riverpod (codegen), Anthropic Messages API via `AnthropicApiClient`, Tether tokens (`TbColors`/`TbText`/`TbSignal`), mockito + `flutter_test`.

---

## Background — existing pattern to copy

The Lead Cockpit already ships an on-demand AI narrative. Read these before starting; every new piece is a near-copy:

- Prompt: `lib/features/ai/presentation/helpers/ai_prompts.dart` → `buildSprintBriefPrompt(CockpitData)`
- Repo method: `lib/features/ai/data/repositories/ai_repository.dart` → `sprintBrief(CockpitData)` (calls `_anthropic.complete(prompt: ..., maxTokens: 320)`, trims, fails on empty)
- Controller: `lib/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart` → `CockpitBriefController` (`AsyncValue<String>?`, `null` = idle, `generate(data)`, `clear()`)
- View: `lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart` → `_BriefButton`, `_BriefSkeleton`, `_BriefPanel`, `_BriefError`, gated on `aiKeyReadyProvider`

Key models:
- `SprintReport` — `lib/features/sprint_report/data/models/sprint_report.dart` (fields used below: `sprintName`, `dateRange`, `daysRemaining`, `totalTickets`, `pointsCommitted`, `pointsDone`, `percentDone`, `forecastLabel`, `behind`, `estimatedTickets`, `unestimatedTickets`, `status` (`StatusSlice{kind,label,tickets,points}`), `people` (`AssigneePoints{handle,done,inProgress,remaining}`), `epics` (`EpicProgress{title,subsDone,subsTotal,percent}`), `burndown` (`Burndown{committedPoints,pointsLeft}`))
- `CockpitData` — `lib/features/lead_cockpit/data/models/cockpit_data.dart` (`sprint` (`SprintHealth`), `team` (`TeamMemberLoad{handle,wip,inReview,done,points,isOverloaded}`), `stuck` (`StuckIssue{title,priority,status,ageDays,assignee,critical}`))

`SprintReport` exposes `selectedSprintReportProvider`-style data via `sprintReportProvider` (an `AsyncValue<SprintReport>`); the cockpit board comes from `cockpitDataProvider` (an `AsyncValue<CockpitData>` — confirm the exact name in `lead_cockpit_provider.dart`, used already by `CockpitBriefController`).

---

## File Structure

**Create:**
- `lib/features/ai/presentation/view/widgets/ai_narrative_card.dart` — shared card (button → skeleton → panel → error); renders prose or `- ` bullet lines.
- `test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart`

**Modify:**
- `lib/features/ai/presentation/helpers/ai_prompts.dart` — add `buildSprintSummaryPrompt`, `buildSprintDigestPrompt`, `buildWeeklyDigestPrompt`.
- `lib/features/ai/data/repositories/ai_repository.dart` — add `summarizeSprint`, `digestSprint`, `weeklyDigest` to the interface + `AnthropicAiRepository`.
- `lib/features/ai/presentation/providers/ai_provider.dart` — add `SprintSummaryController`, `SprintDigestController`, `WeeklyDigestController`.
- `lib/features/sprint_report/presentation/view/sprint_report_screen.dart` — render the summary + digest cards.
- `lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart` — retrofit the brief onto `AiNarrativeCard`; add the weekly digest card (or a sibling widget under cockpit `view/widgets/`).

**Test:**
- `test/features/ai/presentation/helpers/ai_prompts_test.dart` (create if absent) — assert each prompt embeds key numbers.
- `test/features/ai/data/repositories/ai_repository_test.dart` — add success/empty-failure cases for the three methods.
- `test/features/ai/presentation/providers/ai_provider_test.dart` (or existing) — controller state transitions.

---

## Task 1: Shared `AiNarrativeCard` widget

**Files:**
- Create: `lib/features/ai/presentation/view/widgets/ai_narrative_card.dart`
- Test: `test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart
//
// Test summary:
// - idle (null state): shows the title + idle button, no panel.
// - loading: shows a skeleton, hides the idle button.
// - data: renders the narrative text + a "Hide" affordance.
// - error: shows the message + a retry button.
// - tapping the idle button invokes onGenerate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/view/widgets/ai_narrative_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

Widget _host(Widget child) => MaterialApp(theme: getAppTheme(), home: Scaffold(body: child));

void main() {
  testWidgets('idle shows title + button', (tester) async {
    var generated = false;
    await tester.pumpWidget(
      _host(
        AiNarrativeCard(
          title: 'Weekly digest',
          idleLabel: 'Generate',
          state: null,
          onGenerate: () => generated = true,
          onHide: () {},
        ),
      ),
    );
    expect(find.text('Weekly digest'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    await tester.tap(find.text('Generate'));
    expect(generated, isTrue);
  });

  testWidgets('loading shows skeleton', (tester) async {
    await tester.pumpWidget(
      _host(
        const AiNarrativeCard(
          title: 'Weekly digest',
          idleLabel: 'Generate',
          state: AsyncValue.loading(),
          onGenerate: _noop,
          onHide: _noop,
        ),
      ),
    );
    expect(find.byKey(const Key('ai-narrative-skeleton')), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
  });

  testWidgets('data renders text', (tester) async {
    await tester.pumpWidget(
      _host(
        const AiNarrativeCard(
          title: 'Weekly digest',
          idleLabel: 'Generate',
          state: AsyncValue.data('- Shipped 12 PRs\n- 3 at risk'),
          onGenerate: _noop,
          onHide: _noop,
        ),
      ),
    );
    expect(find.textContaining('Shipped 12 PRs'), findsOneWidget);
    expect(find.textContaining('3 at risk'), findsOneWidget);
  });

  testWidgets('error shows message + retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        AiNarrativeCard(
          title: 'Weekly digest',
          idleLabel: 'Generate',
          state: AsyncValue.error('boom', StackTrace.empty),
          onGenerate: () => retried = true,
          onHide: () {},
        ),
      ),
    );
    expect(find.textContaining('boom'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

void _noop() {}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart`
Expected: FAIL — `ai_narrative_card.dart` / `AiNarrativeCard` not found (compile error).

- [ ] **Step 3: Implement `AiNarrativeCard`**

```dart
// lib/features/ai/presentation/view/widgets/ai_narrative_card.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';

/// A reusable BYOK-AI narrative panel: an idle "generate" button that expands
/// into a skeleton while loading, then a prose/bulleted panel (or an error with
/// retry). `state == null` means "not requested yet". Bullet lines (`- `/`• `)
/// render as bullet rows; everything else renders as paragraphs.
class AiNarrativeCard extends StatelessWidget {
  const AiNarrativeCard({
    super.key,
    required this.title,
    required this.idleLabel,
    required this.state,
    required this.onGenerate,
    required this.onHide,
  });

  final String title;
  final String idleLabel;
  final AsyncValue<String>? state;
  final VoidCallback onGenerate;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + action (Generate / Hide / Retry).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 13, color: TbColors.cyan),
                const SizedBox(width: 7),
                Text(title, style: TbText.label(size: 11, color: TbColors.muted, tracking: 1.4)),
                const Spacer(),
                if (s is! AsyncLoading) _ActionButton(label: _actionLabel(s), onTap: _actionTap(s)),
              ],
            ),
          ),
          // Body, by state.
          switch (s) {
            null => const SizedBox.shrink(),
            AsyncLoading() => const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _Skeleton(key: Key('ai-narrative-skeleton')),
            ),
            AsyncData(:final value) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _NarrativeBody(text: value),
            ),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.text)),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  String _actionLabel(AsyncValue<String>? s) => switch (s) {
    AsyncData() => 'Hide',
    AsyncError() => 'Retry',
    _ => idleLabel,
  };

  VoidCallback _actionTap(AsyncValue<String>? s) => switch (s) {
    AsyncData() => onHide,
    _ => onGenerate,
  };
}

/// Renders the narrative: bullet lines as bullet rows, others as paragraphs.
class _NarrativeBody extends StatelessWidget {
  const _NarrativeBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (_isBullet(line))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: SizedBox(width: 5, height: 5, child: ColoredBox(color: TbColors.cyan)),
                  ),
                  Expanded(
                    child: Text(_stripBullet(line), style: TbText.body(size: 13, color: TbColors.text, height: 1.5)),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: TbText.body(size: 13, color: TbColors.text, height: 1.55)),
            ),
      ],
    );
  }

  static bool _isBullet(String l) => l.startsWith('- ') || l.startsWith('• ') || l.startsWith('* ');
  static String _stripBullet(String l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), '');
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in [1.0, 0.92, 0.6])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: w,
              child: Container(
                height: 11,
                decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: TbColors.cyan),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TbText.label(size: 10, color: TbSignal.info.text, tracking: 0.8)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/ai/presentation/view/widgets/ai_narrative_card.dart test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart
dart analyze lib/features/ai/presentation/view/widgets/ai_narrative_card.dart
git add lib/features/ai/presentation/view/widgets/ai_narrative_card.dart test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart
git commit -m "feat(ai): add reusable AiNarrativeCard widget"
```

---

## Task 2: Prompt builders

**Files:**
- Modify: `lib/features/ai/presentation/helpers/ai_prompts.dart`
- Test: `test/features/ai/presentation/helpers/ai_prompts_test.dart` (create)

- [ ] **Step 1: Write the failing prompt tests**

```dart
// test/features/ai/presentation/helpers/ai_prompts_test.dart
//
// Test summary:
// - sprint summary prompt embeds sprint name, % done, days remaining.
// - sprint digest prompt asks for bullets and embeds status counts.
// - weekly digest prompt embeds throughput (done) + frames the week.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _report() => const SprintReport(
  sprintName: 'Sprint 24',
  dateRange: 'Jun 2 – Jun 16',
  daysRemaining: 6,
  totalTickets: 60,
  pointsCommitted: 168,
  repoCount: 4,
  forecastLabel: 'Trending ~2D behind',
  forecastDetail: '58 of 133 done',
  pointsDone: 84,
  estimatedTickets: 48,
  estimatedPoints: 168,
  unestimatedTickets: 12,
  burndown: Burndown(committedPoints: 168, totalDays: 14, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 14),
  status: [StatusSlice(kind: ReportStatusKind.done, label: 'Done', tickets: 30, points: 84)],
);

CockpitData _cockpit() => const CockpitData(
  sprint: SprintHealth(
    name: 'Sprint 24',
    daysRemaining: 6,
    endLabel: 'Jun 16',
    totalIssues: 60,
    repoCount: 4,
    done: 30,
    inProgress: 12,
    inReview: 8,
    notStarted: 7,
    atRisk: 3,
    unestimated: 12,
  ),
  team: [TeamMemberLoad(handle: 'sam', wip: 6, inReview: 1, done: 9, points: 38)],
  stuck: [],
);

void main() {
  test('summary prompt embeds sprint name + progress', () {
    final p = buildSprintSummaryPrompt(_report());
    expect(p, contains('Sprint 24'));
    expect(p, contains('50%')); // percentDone = 84/168
    expect(p, contains('6 days'));
  });

  test('digest prompt asks for bullets + embeds counts', () {
    final p = buildSprintDigestPrompt(_report());
    expect(p.toLowerCase(), contains('bullet'));
    expect(p, contains('84')); // points done
  });

  test('weekly digest prompt frames the week + throughput', () {
    final p = buildWeeklyDigestPrompt(_cockpit());
    expect(p.toLowerCase(), contains('week'));
    expect(p, contains('Sprint 24'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/ai/presentation/helpers/ai_prompts_test.dart`
Expected: FAIL — `buildSprintSummaryPrompt` / `buildSprintDigestPrompt` / `buildWeeklyDigestPrompt` undefined.

- [ ] **Step 3: Add the three prompt builders**

Append to `lib/features/ai/presentation/helpers/ai_prompts.dart` (the file already imports `cockpit_data.dart`; add an import for `sprint_report.dart`):

```dart
// add near the top with the other imports:
import '../../../sprint_report/data/models/sprint_report.dart';
```

```dart
// ─── Sprint narratives ───────────────────────────────────────────────────────

String _statusLines(SprintReport r) =>
    r.status.map((s) => '${s.label}: ${s.tickets} tickets / ${s.points} pts').join(', ');

/// Full prose summary of the current sprint for the Sprint Report screen.
String buildSprintSummaryPrompt(SprintReport r) {
  final epics = r.epics.take(5).map((e) => '"${e.title}" ${e.percent}%').join(', ');
  final people = r.people.take(8).map((p) => '${p.handle}: ${p.done}d/${p.open}open').join(', ');
  return '''
You are summarizing an engineering sprint for the whole team. Write 4-6 sentences of plain prose —
no bullets, no heading, no preamble. Cover: overall progress vs commitment, the biggest risk to
finishing on time, where work is concentrated or stuck, and end with one concrete recommendation.
Be specific and cite the numbers.

Sprint: ${r.sprintName} (${r.dateRange}), ${r.daysRemaining} days remaining.
Progress: ${r.pointsDone} of ${r.pointsCommitted} points done (${r.percentDone}%), ${r.totalTickets} tickets across ${r.repoCount} repos.
Forecast: ${r.forecastLabel}${r.behind ? ' (behind)' : ' (on track)'}.
Estimation: ${r.estimatedTickets} estimated, ${r.unestimatedTickets} unestimated.
Status: ${_statusLines(r)}.
Epics: ${epics.isEmpty ? 'none' : epics}.
Per-assignee (done/open): ${people.isEmpty ? 'n/a' : people}.''';
}

/// Scannable bullet digest (standup-style highlights) for the Sprint Report.
String buildSprintDigestPrompt(SprintReport r) {
  return '''
Produce a scannable sprint digest for a team standup. Return ONLY markdown bullets, each starting
with "- ", grouped logically (shipped, in progress / review, at risk, recommendation). 4-7 bullets
total. No heading, no preamble. Be specific and cite numbers.

Sprint: ${r.sprintName}, ${r.daysRemaining} days remaining.
Progress: ${r.pointsDone}/${r.pointsCommitted} points (${r.percentDone}%).
Status: ${_statusLines(r)}.
Forecast: ${r.forecastLabel}.''';
}

/// Weekly team pulse for the Lead Cockpit, framed as the past week from the
/// current board snapshot (throughput = done, risks = overloaded + stuck).
String buildWeeklyDigestPrompt(CockpitData c) {
  final s = c.sprint;
  final shipped = c.team.fold<int>(0, (sum, m) => sum + m.done);
  final overloaded = c.team.where((m) => m.isOverloaded).map((m) => '${m.handle} (${m.wip} WIP)').join(', ');
  final stuck = c.stuck
      .take(5)
      .map((i) => '"${i.title}" (${i.ageDays}d)')
      .join('; ');
  return '''
Write a weekly digest for an engineering team lead reviewing the past week. Return ONLY markdown
bullets, each starting with "- ". 4-6 bullets: what the team shipped, what is in flight, who is
overloaded, what is stuck, and what to focus on next week. No heading, no preamble. Cite numbers.

Sprint context: ${s.name}, ${s.daysRemaining} days remaining.
Closed this sprint (throughput): $shipped items; currently ${s.inProgress} in progress, ${s.inReview} in review, ${s.atRisk} at risk.
Overloaded: ${overloaded.isEmpty ? 'none' : overloaded}.
Stuck items: ${stuck.isEmpty ? 'none' : stuck}.''';
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/ai/presentation/helpers/ai_prompts_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/ai/presentation/helpers/ai_prompts.dart test/features/ai/presentation/helpers/ai_prompts_test.dart
dart analyze lib/features/ai/presentation/helpers/ai_prompts.dart
git add lib/features/ai/presentation/helpers/ai_prompts.dart test/features/ai/presentation/helpers/ai_prompts_test.dart
git commit -m "feat(ai): add sprint summary/digest + weekly digest prompts"
```

---

## Task 3: Repository methods

**Files:**
- Modify: `lib/features/ai/data/repositories/ai_repository.dart`
- Test: `test/features/ai/data/repositories/ai_repository_test.dart:1-200`

- [ ] **Step 1: Write the failing repo tests**

Add inside `main()` in `ai_repository_test.dart` (reuse the existing `stubAnthropic`, `msg`, `textContent` helpers; add the two model factories below near the other factories). Add these imports at the top of the test file:

```dart
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
```

```dart
  SprintReport report() => const SprintReport(
    sprintName: 'Sprint 24',
    dateRange: 'Jun 2 – Jun 16',
    daysRemaining: 6,
    totalTickets: 60,
    pointsCommitted: 168,
    repoCount: 4,
    forecastLabel: 'Trending ~2D behind',
    forecastDetail: '58 of 133 done',
    pointsDone: 84,
    estimatedTickets: 48,
    estimatedPoints: 168,
    unestimatedTickets: 12,
    burndown: Burndown(committedPoints: 168, totalDays: 14, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 14),
  );

  CockpitData cockpit() => const CockpitData(
    sprint: SprintHealth(
      name: 'Sprint 24',
      daysRemaining: 6,
      endLabel: 'Jun 16',
      totalIssues: 60,
      repoCount: 4,
      done: 30,
      inProgress: 12,
      inReview: 8,
      notStarted: 7,
      atRisk: 3,
      unestimated: 12,
    ),
    team: [],
    stuck: [],
  );

  group('sprint narratives', () {
    test('summarizeSprint returns trimmed prose', () async {
      stubAnthropic(msg(textContent('  Sprint 24 is on track.  ')));
      final r = await repo.summarizeSprint(report());
      expect(r, isA<ResultSuccess<String>>());
      expect((r as ResultSuccess<String>).data, 'Sprint 24 is on track.');
    });

    test('summarizeSprint fails on empty model output', () async {
      stubAnthropic(msg(textContent('   ')));
      expect(await repo.summarizeSprint(report()), isA<ResultFailure<String>>());
    });

    test('digestSprint returns trimmed bullets', () async {
      stubAnthropic(msg(textContent('- Shipped 12\n- 3 at risk')));
      final r = await repo.digestSprint(report());
      expect((r as ResultSuccess<String>).data, contains('Shipped 12'));
    });

    test('weeklyDigest returns trimmed bullets', () async {
      stubAnthropic(msg(textContent('- Shipped 9 items this week')));
      final r = await repo.weeklyDigest(cockpit());
      expect((r as ResultSuccess<String>).data, contains('this week'));
    });

    test('weeklyDigest surfaces a failure on a 500', () async {
      stubAnthropic(msg(null, status: 500));
      expect(await repo.weeklyDigest(cockpit()), isA<ResultFailure<String>>());
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/ai/data/repositories/ai_repository_test.dart`
Expected: FAIL — `summarizeSprint` / `digestSprint` / `weeklyDigest` not defined on `AiRepository`.

- [ ] **Step 3: Add the methods**

In `ai_repository.dart`, add to the `AiRepository` interface (after `sprintBrief`):

```dart
  /// Full prose summary of the current sprint (Sprint Report screen).
  Future<Result<String>> summarizeSprint(SprintReport report);

  /// Scannable bullet digest of the current sprint (Sprint Report screen).
  Future<Result<String>> digestSprint(SprintReport report);

  /// Weekly team pulse for the Lead Cockpit, from the current board snapshot.
  Future<Result<String>> weeklyDigest(CockpitData cockpit);
```

Add the import at the top:

```dart
import '../../../sprint_report/data/models/sprint_report.dart';
```

Add to `AnthropicAiRepository` (after the `sprintBrief` implementation) — a shared private helper keeps these DRY:

```dart
  Future<Result<String>> _narrative(String prompt, {int maxTokens = 400, required String failure}) async {
    try {
      final text = (await _anthropic.complete(prompt: prompt, maxTokens: maxTokens)).trim();
      if (text.isEmpty) return Result.failure('The model returned an empty response.', StackTrace.current);
      return Result.success(text);
    } catch (e, stackTrace) {
      log(failure, error: e, stackTrace: stackTrace);
      return Result.failure(failure, stackTrace);
    }
  }

  @override
  Future<Result<String>> summarizeSprint(SprintReport report) =>
      _narrative(buildSprintSummaryPrompt(report), maxTokens: 500, failure: 'Could not summarize the sprint.');

  @override
  Future<Result<String>> digestSprint(SprintReport report) =>
      _narrative(buildSprintDigestPrompt(report), maxTokens: 450, failure: 'Could not generate the sprint digest.');

  @override
  Future<Result<String>> weeklyDigest(CockpitData cockpit) =>
      _narrative(buildWeeklyDigestPrompt(cockpit), maxTokens: 450, failure: 'Could not generate the weekly digest.');
```

> Note: leave the existing `sprintBrief` as-is (do not refactor it onto `_narrative` in this task — keep the diff focused; an optional cleanup can fold it in later).

- [ ] **Step 4: Regenerate mocks, run tests**

`MockAiRepository` may be generated for provider tests; regenerate so the new interface methods exist:

```bash
dart run build_runner build -d
flutter test test/features/ai/data/repositories/ai_repository_test.dart
```
Expected: PASS (all prior + 5 new).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/ai/data/repositories/ai_repository.dart test/features/ai/data/repositories/ai_repository_test.dart
dart analyze lib/features/ai/data/repositories/ai_repository.dart
git add lib/features/ai/data/repositories/ai_repository.dart test/features/ai/data/repositories/ai_repository_test.dart
git commit -m "feat(ai): add summarizeSprint/digestSprint/weeklyDigest repository methods"
```

---

## Task 4: Controller providers

**Files:**
- Modify: `lib/features/ai/presentation/providers/ai_provider.dart`
- Test: `test/features/ai/presentation/providers/ai_provider_test.dart` (create if absent)

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/ai/presentation/providers/ai_provider_test.dart
//
// Test summary:
// - SprintSummaryController: idle (null) → loading → data on success.
// - SprintSummaryController: → error when the repo fails.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_core/core.dart';

import '../../data/repositories/ai_repository_test.mocks.dart';

SprintReport _report() => const SprintReport(
  sprintName: 'S24',
  dateRange: 'x',
  daysRemaining: 6,
  totalTickets: 60,
  pointsCommitted: 168,
  repoCount: 4,
  forecastLabel: 'f',
  forecastDetail: 'd',
  pointsDone: 84,
  estimatedTickets: 48,
  estimatedPoints: 168,
  unestimatedTickets: 12,
  burndown: Burndown(committedPoints: 168, totalDays: 14, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 14),
);

void main() {
  late MockAiRepository ai;
  ProviderContainer makeContainer() => ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);

  setUp(() => ai = MockAiRepository());

  test('SprintSummaryController: null → data on success', () async {
    when(ai.summarizeSprint(any)).thenAnswer((_) async => Result.success('ok summary'));
    final c = makeContainer();
    addTearDown(c.dispose);

    expect(c.read(sprintSummaryControllerProvider), isNull);
    await c.read(sprintSummaryControllerProvider.notifier).generate(_report());
    expect(c.read(sprintSummaryControllerProvider), const AsyncData<String>('ok summary'));
  });

  test('SprintSummaryController: → error on failure', () async {
    when(ai.summarizeSprint(any)).thenAnswer((_) async => Result.failure('nope', StackTrace.current));
    final c = makeContainer();
    addTearDown(c.dispose);

    await c.read(sprintSummaryControllerProvider.notifier).generate(_report());
    expect(c.read(sprintSummaryControllerProvider), isA<AsyncError<String>>());
  });
}
```

> If `MockAiRepository` is not yet generated, add `AiRepository` to the `@GenerateMocks([...])` list in `ai_repository_test.dart` (e.g. `@GenerateMocks([Dio, AiRepository])`) and re-run build_runner in Task 3 Step 4.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/ai/presentation/providers/ai_provider_test.dart`
Expected: FAIL — `sprintSummaryControllerProvider` undefined.

- [ ] **Step 3: Add the three controllers**

Append to `lib/features/ai/presentation/providers/ai_provider.dart` (add the import for `SprintReport` and `CockpitData` if not present):

```dart
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../sprint_report/data/models/sprint_report.dart';
```

```dart
/// On-demand full sprint summary (Sprint Report). `null` = not requested yet.
@riverpod
class SprintSummaryController extends _$SprintSummaryController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).summarizeSprint(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand scannable sprint digest (Sprint Report). `null` = not requested.
@riverpod
class SprintDigestController extends _$SprintDigestController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).digestSprint(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand weekly digest (Lead Cockpit). `null` = not requested yet.
@riverpod
class WeeklyDigestController extends _$WeeklyDigestController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(CockpitData cockpit) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).weeklyDigest(cockpit);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
```

- [ ] **Step 4: Regenerate, run**

```bash
dart run build_runner build -d
flutter test test/features/ai/presentation/providers/ai_provider_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/ai/presentation/providers/ai_provider.dart test/features/ai/presentation/providers/ai_provider_test.dart
dart analyze lib/features/ai/presentation/providers/ai_provider.dart
git add lib/features/ai/presentation/providers/ai_provider.dart lib/features/ai/presentation/providers/ai_provider.g.dart test/features/ai/presentation/providers/ai_provider_test.dart
git commit -m "feat(ai): add sprint summary/digest + weekly digest controllers"
```

---

## Task 5: Wire summary + digest into the Sprint Report screen

**Files:**
- Modify: `lib/features/sprint_report/presentation/view/sprint_report_screen.dart`

> The screen is a `ConsumerWidget` that renders a `SprintReport` (see `sprintReportProvider`). Confirm the exact provider name and the spot where the report is in scope (the data-loaded branch around `sprint_report_screen.dart:175-220`, inside the `maxWidth: 960` column). Insert the two cards at the top of that column, below the header.

- [ ] **Step 1: Add the cards (manual verification — UI)**

Inside the data-loaded column (where `report` is available), add — gated on the AI key:

```dart
// imports at top of the file:
import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../ai/presentation/view/widgets/ai_narrative_card.dart';
```

```dart
// at the top of the report column, after the sprint header:
if (ref.watch(aiKeyReadyProvider)) ...[
  AiNarrativeCard(
    title: 'AI Sprint Summary',
    idleLabel: 'Summarize sprint',
    state: ref.watch(sprintSummaryControllerProvider),
    onGenerate: () => ref.read(sprintSummaryControllerProvider.notifier).generate(report),
    onHide: () => ref.read(sprintSummaryControllerProvider.notifier).clear(),
  ),
  const SizedBox(height: 12),
  AiNarrativeCard(
    title: 'AI Sprint Digest',
    idleLabel: 'Generate digest',
    state: ref.watch(sprintDigestControllerProvider),
    onGenerate: () => ref.read(sprintDigestControllerProvider.notifier).generate(report),
    onHide: () => ref.read(sprintDigestControllerProvider.notifier).clear(),
  ),
  const SizedBox(height: 12),
],
```

- [ ] **Step 2: Analyze + run the app**

```bash
dart analyze lib/features/sprint_report/presentation/view/sprint_report_screen.dart
flutter run -d macos   # navigate to Sprint Report; with a key set, tap "Summarize sprint" / "Generate digest"
```
Expected: both cards render; tapping shows the skeleton then the narrative; "Hide" collapses; with no key set, neither card shows.

- [ ] **Step 3: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/sprint_report/presentation/view/sprint_report_screen.dart
dart analyze
git add lib/features/sprint_report/presentation/view/sprint_report_screen.dart
git commit -m "feat(sprint-report): add AI sprint summary + digest cards"
```

---

## Task 6: Retrofit the cockpit brief onto `AiNarrativeCard` + add the weekly digest

**Files:**
- Modify: `lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart`

> Goal: one card implementation. Replace the bespoke `_BriefButton`/`_BriefSkeleton`/`_BriefPanel`/`_BriefError` usage with `AiNarrativeCard` for the brief, then add a second `AiNarrativeCard` for the weekly digest. Keep the existing `CockpitBriefController` wiring. Confirm the cockpit-data provider name used by `CockpitBriefController.generate` and reuse it here.

- [ ] **Step 1: Replace the brief panel with `AiNarrativeCard`**

In `sprint_health_strip.dart`, where the brief is rendered (`switch (brief) { AsyncLoading() => _BriefSkeleton() ... }`), replace with:

```dart
// imports:
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../../ai/presentation/view/widgets/ai_narrative_card.dart';
```

```dart
if (keyReady) ...[
  const SizedBox(height: 12),
  AiNarrativeCard(
    title: 'AI Sprint Brief',
    idleLabel: 'Sprint Brief',
    state: ref.watch(cockpitBriefControllerProvider),
    onGenerate: () => ref.read(cockpitBriefControllerProvider.notifier).generate(cockpit),
    onHide: () => ref.read(cockpitBriefControllerProvider.notifier).clear(),
  ),
  const SizedBox(height: 12),
  AiNarrativeCard(
    title: 'AI Weekly Digest',
    idleLabel: 'Weekly digest',
    state: ref.watch(weeklyDigestControllerProvider),
    onGenerate: () => ref.read(weeklyDigestControllerProvider.notifier).generate(cockpit),
    onHide: () => ref.read(weeklyDigestControllerProvider.notifier).clear(),
  ),
],
```

Then delete the now-unused private widgets `_BriefButton`, `_BriefButtonState`, `_BriefSkeleton`, `_BriefPanel`, `_BriefError`, `_SkeletonBar` (only those used solely by the brief — keep `_StatusBar`, `_TileRow`, `_Tile`). Remove the now-dead `btnLabel`/`onBriefTap` locals.

> `cockpit` here is the `CockpitData` already in scope in the strip (the same value passed to the old `controller.generate(data)`). If it is fetched via a provider, watch it the same way the old code did.

- [ ] **Step 2: Analyze + run the existing cockpit test**

```bash
dart analyze lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart
flutter test test/features/lead_cockpit/
```
Expected: analyze clean; cockpit tests pass. If a test referenced a deleted private widget (e.g. `_BriefPanel`), update it to assert on `AiNarrativeCard` text instead.

- [ ] **Step 3: Run the app to verify both cards**

```bash
flutter run -d macos   # Lead Cockpit: with a key, "Sprint Brief" + "Weekly digest" both generate
```
Expected: brief renders as prose; weekly digest renders as bullets; both gated on key.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format --line-length 120 lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart
dart analyze
git add lib/features/lead_cockpit/presentation/view/widgets/sprint_health_strip.dart test/features/lead_cockpit/
git commit -m "feat(cockpit): add AI weekly digest; unify brief on AiNarrativeCard"
```

---

## Task 7: Full verification

- [ ] **Step 1: Codegen + full suite + format + analyze**

```bash
dart run build_runner build -d
flutter test
dart format --line-length 120 --set-exit-if-changed .
dart analyze
```
Expected: all tests pass; format reports zero changed files; analyze finds no issues.

- [ ] **Step 2: Manual smoke (both screens, no-key + key)**

```bash
flutter run -d macos
```
- No key set: Settings prompts for key; neither screen shows AI cards.
- Key set: Sprint Report shows Summary + Digest; Cockpit shows Brief + Weekly Digest; each generates, hides, and retries on error.

- [ ] **Step 3: Commit any formatting fixups**

```bash
git add -A
git commit -m "chore(ai): formatting + codegen for AI digests"
```

---

## Self-Review

**Spec coverage:**
- Sprint summarize → Task 2 (`buildSprintSummaryPrompt`) + Task 3 (`summarizeSprint`) + Task 4 (`SprintSummaryController`) + Task 5 (Sprint Report card). ✅
- Sprint digest → Task 2/3/4 + Task 5. ✅
- Weekly digest → Task 2/3/4 + Task 6 (Cockpit card). ✅
- "Reuse for both, one engine" → `_narrative` helper (repo) + `AiNarrativeCard` (UI, Task 1) reused by all three and retrofitted onto the existing brief (Task 6). ✅
- Loading indicator on async work (project rule) → `AiNarrativeCard` `_Skeleton` while `AsyncLoading`. ✅

**Placeholder scan:** No TBD/TODO; every code step is complete. Provider names to confirm against the codebase are flagged inline (`sprintReportProvider`, the cockpit-data provider used by `CockpitBriefController`) — the engineer must read those two files and substitute the exact symbol; everything else is literal.

**Type consistency:** Controllers all expose `generate(...)` + `clear()` and `AsyncValue<String>?` state; `AiNarrativeCard` takes `state`/`onGenerate`/`onHide` consistently across Tasks 5 and 6; repo methods return `Future<Result<String>>` matching the controllers' `switch`. Prompt builders take `SprintReport`/`CockpitData` matching the repo signatures and tests.

**Known follow-ups (out of scope, YAGNI):**
- Weekly digest currently summarizes the cockpit board framed as "this week" rather than a true 7-day merged-PR window. A real weekly aggregation (merged PRs / closed issues over the last 7 days) is a future data-layer task.
- `sprintBrief` could fold onto `_narrative` for full DRY; left as-is to keep diffs focused.
