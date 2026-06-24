# Sprint Report Narrative & Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a BYOK-AI-generated narrative executive Sprint Report that exports as a print-friendly PDF and a copyable/email plain-text summary.

**Architecture:** A new `export` slice inside the existing `sprint_report` feature. AI returns a structured `SprintNarrativeReport` (parsed defensively, like the existing triage path); deterministic REAL metrics come from a pure `report_metrics` function; pure builders turn the report + metrics into a `pw.Document` (PDF) or plain text (email). A thin `SprintExporter` interface wraps the only impure calls (Clipboard / url_launcher / Printing) so widgets and builders stay testable. The report is generated on demand from a CTA, never auto.

**Tech Stack:** Flutter, Riverpod (code-gen), Freezed, `pdf` + `printing` (new), `url_launcher` + `flutter/services` Clipboard (existing), mockito for repo tests.

## Global Constraints

- Depend on `turbo_core` + `turbo_ui` only — never `turbo_sdk`.
- Every new dependency must support macOS, Windows, Linux, web, iOS, Android. Verify `pdf` and `printing` on pub.dev before adding.
- No `dart:io` in shared paths without a `kIsWeb`/conditional fallback. `printing` and `pdf` are cross-platform; do not import `dart:io` directly.
- `dart format --line-length 120 --set-exit-if-changed .` must pass (CI rejects unformatted code).
- `dart analyze` must pass; `flutter test` must pass.
- AI features fire from a CTA, never auto on load. Gate the CTA behind `aiKeyReadyProvider`.
- Never log or commit secrets. Generated files (`*.freezed.dart`, `*.g.dart`) are git-ignored — run build_runner, do not commit them.
- Freezed models: `@freezed sealed class ... with _$...`, factory constructor, `@Default(...)` for lists, `fromJson`.
- Run `dart run build_runner build -d` after any Freezed/Riverpod change.
- AI must never fabricate metrics: the narrative model carries **no** metric numbers; all metrics come from `report_metrics` (REAL) or user-typed custom rows (YOU).

**Existing signatures this plan builds on (verbatim):**

- `lib/features/ai/data/services/llm_client.dart`: `Future<String> complete({required String prompt, int maxTokens = 512})`
- `lib/features/ai/presentation/providers/ai_provider.dart`: `bool aiKeyReady(Ref ref)` → `aiKeyReadyProvider`; `AiRepository aiRepository(Ref ref)` → `aiRepositoryProvider`.
- `lib/features/sprint_report/data/models/sprint_report.dart`: `SprintReport` with `sprintName, dateRange, daysRemaining, totalTickets, pointsCommitted, pointsDone, percentDone (getter), repoCount, forecastLabel, behind, status (List<StatusSlice>{kind,label,tickets,points}), estimatedTickets, unestimatedTickets, people (List<AssigneePoints>{handle,done,inProgress,remaining, total/open getters}), epics (List<EpicProgress>{title,percent getter})`.
- `turbo_core`: `Result<T>` with `ResultSuccess(:final data)` / `ResultFailure(:final message)`.
- `lib/features/sprint_report/presentation/view/sprint_report_screen.dart` header `Row` (lines ~58-74) holds the `REFRESH` action — the new CTA goes here.

---

### Task 1: `SprintNarrativeReport` model

**Files:**
- Create: `lib/features/sprint_report/data/models/sprint_narrative_report.dart`
- Test: `test/features/sprint_report/data/models/sprint_narrative_report_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum SprintOutlook { onTrack, atRisk, behind }`
  - `class Deliverable { String title; String status; String description; String impact; }`
  - `class TechHighlights { List<String> platform; List<String> product; }`
  - `class SprintNarrativeReport { String executiveSummary; List<String> keyWins; SprintOutlook overallStatus; List<Deliverable> deliverables; TechHighlights techHighlights; List<String> challenges; List<String> mitigations; List<String> learnings; List<String> nextPriorities; List<String> recognition; String outcome; }` with `fromJson` and Freezed `copyWith`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/sprint_report/data/models/sprint_narrative_report_test.dart
// Test summary:
// - fromJson builds a full report from complete JSON
// - fromJson defaults missing lists/strings instead of throwing
// - copyWith replaces overallStatus
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

void main() {
  test('fromJson builds a full report', () {
    final r = SprintNarrativeReport.fromJson({
      'executiveSummary': 'Closed 82/120 points.',
      'keyWins': ['Released Checkout v2'],
      'overallStatus': 'onTrack',
      'deliverables': [
        {'title': 'Checkout v2', 'status': 'Complete', 'description': 'Dashboard', 'impact': 'Self-service'}
      ],
      'techHighlights': {'platform': ['Redis caching'], 'product': ['Analytics dashboard']},
      'challenges': ['Security review pending'],
      'mitigations': ['Scheduled next sprint'],
      'learnings': ['Caching helped'],
      'nextPriorities': ['AI workflow MVP'],
      'recognition': ['@ko migration'],
      'outcome': 'Successful sprint.',
    });
    expect(r.executiveSummary, 'Closed 82/120 points.');
    expect(r.keyWins.single, 'Released Checkout v2');
    expect(r.deliverables.single.impact, 'Self-service');
    expect(r.techHighlights.platform.single, 'Redis caching');
    expect(r.outcome, 'Successful sprint.');
  });

  test('fromJson tolerates missing fields', () {
    final r = SprintNarrativeReport.fromJson({'executiveSummary': 'x'});
    expect(r.keyWins, isEmpty);
    expect(r.deliverables, isEmpty);
    expect(r.techHighlights.platform, isEmpty);
    expect(r.outcome, '');
  });

  test('copyWith replaces overallStatus', () {
    final r = SprintNarrativeReport.fromJson({'executiveSummary': 'x'});
    expect(r.copyWith(overallStatus: SprintOutlook.behind).overallStatus, SprintOutlook.behind);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/data/models/sprint_narrative_report_test.dart`
Expected: FAIL — `sprint_narrative_report.dart` / `SprintNarrativeReport` not found.

- [ ] **Step 3: Write the model**

```dart
// lib/features/sprint_report/data/models/sprint_narrative_report.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sprint_narrative_report.freezed.dart';
part 'sprint_narrative_report.g.dart';

/// Overall sprint health. Set deterministically from the forecast after the AI
/// call — the model never trusts the AI for this value.
enum SprintOutlook { onTrack, atRisk, behind }

@freezed
sealed class Deliverable with _$Deliverable {
  const factory Deliverable({
    @Default('') String title,
    @Default('') String status,
    @Default('') String description,
    @Default('') String impact,
  }) = _Deliverable;

  factory Deliverable.fromJson(Map<String, dynamic> json) => _$DeliverableFromJson(json);
}

@freezed
sealed class TechHighlights with _$TechHighlights {
  const factory TechHighlights({
    @Default(<String>[]) List<String> platform,
    @Default(<String>[]) List<String> product,
  }) = _TechHighlights;

  factory TechHighlights.fromJson(Map<String, dynamic> json) => _$TechHighlightsFromJson(json);
}

/// The structured narrative the AI produces and the export builders consume.
/// Carries NO metric numbers — metrics are computed (REAL) or user-entered (YOU).
@freezed
sealed class SprintNarrativeReport with _$SprintNarrativeReport {
  const factory SprintNarrativeReport({
    @Default('') String executiveSummary,
    @Default(<String>[]) List<String> keyWins,
    @Default(SprintOutlook.onTrack) SprintOutlook overallStatus,
    @Default(<Deliverable>[]) List<Deliverable> deliverables,
    @Default(TechHighlights()) TechHighlights techHighlights,
    @Default(<String>[]) List<String> challenges,
    @Default(<String>[]) List<String> mitigations,
    @Default(<String>[]) List<String> learnings,
    @Default(<String>[]) List<String> nextPriorities,
    @Default(<String>[]) List<String> recognition,
    @Default('') String outcome,
  }) = _SprintNarrativeReport;

  factory SprintNarrativeReport.fromJson(Map<String, dynamic> json) => _$SprintNarrativeReportFromJson(json);
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `sprint_narrative_report.freezed.dart` and `.g.dart`, no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/sprint_report/data/models/sprint_narrative_report_test.dart`
Expected: PASS (3 tests).

> Note: Freezed `@Default(SprintOutlook.onTrack)` with `json_serializable` maps the enum by name (`'onTrack'`). The "missing fields" test relies on generated `fromJson` defaulting absent keys — verified by Step 5.

- [ ] **Step 6: Commit**

```bash
git add lib/features/sprint_report/data/models/sprint_narrative_report.dart test/features/sprint_report/data/models/sprint_narrative_report_test.dart
git commit -m "feat(sprint_report): add SprintNarrativeReport model"
```

---

### Task 2: AI prompt + defensive parser

**Files:**
- Modify: `lib/features/ai/presentation/helpers/ai_prompts.dart` (append at end)
- Test: `test/features/ai/sprint_report_prompt_test.dart`

**Interfaces:**
- Consumes: `SprintReport` (existing); `SprintNarrativeReport`, `Deliverable`, `TechHighlights` (Task 1).
- Produces:
  - `String buildSprintReportPrompt(SprintReport r)`
  - `SprintNarrativeReport parseSprintReport(String response)` — extracts the first `{`…`}` block, `jsonDecode`s it, builds the model defensively; on any failure returns `const SprintNarrativeReport()` (empty), mirroring `parseTriage`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ai/sprint_report_prompt_test.dart
// Test summary:
// - buildSprintReportPrompt forbids inventing metrics and cites real numbers
// - parseSprintReport reads a fenced/loose JSON object into the model
// - parseSprintReport returns an empty report on malformed input
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _report() => const SprintReport(
      sprintName: 'Sprint 24',
      dateRange: 'Jun 10 - Jun 24',
      daysRemaining: 2,
      totalTickets: 47,
      pointsCommitted: 120,
      repoCount: 3,
      forecastLabel: 'Trending ~2d behind',
      forecastDetail: 'detail',
      behind: true,
      pointsDone: 82,
      estimatedTickets: 41,
      estimatedPoints: 110,
      unestimatedTickets: 6,
      burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
    );

void main() {
  test('prompt cites numbers and forbids fabrication', () {
    final p = buildSprintReportPrompt(_report());
    expect(p, contains('Sprint 24'));
    expect(p, contains('82'));
    expect(p.toLowerCase(), contains('do not invent'));
  });

  test('parseSprintReport reads a loose JSON object', () {
    const raw = 'Here you go:\n{"executiveSummary":"Closed 82/120.","keyWins":["Shipped X"],'
        '"deliverables":[{"title":"X","status":"Complete","description":"d","impact":"i"}],'
        '"techHighlights":{"platform":["Redis"],"product":["Dash"]},"outcome":"Good."} done';
    final r = parseSprintReport(raw);
    expect(r.executiveSummary, 'Closed 82/120.');
    expect(r.keyWins.single, 'Shipped X');
    expect(r.deliverables.single.title, 'X');
    expect(r.techHighlights.product.single, 'Dash');
    expect(r.outcome, 'Good.');
  });

  test('parseSprintReport returns empty report on garbage', () {
    expect(parseSprintReport('no json here').executiveSummary, '');
    expect(parseSprintReport('no json here').keyWins, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/sprint_report_prompt_test.dart`
Expected: FAIL — `buildSprintReportPrompt` / `parseSprintReport` undefined.

- [ ] **Step 3: Append prompt + parser**

Add to the end of `lib/features/ai/presentation/helpers/ai_prompts.dart` (the file already imports `dart:convert` for `jsonDecode` and the sprint_report model; add the narrative import at the top with the other local imports):

```dart
// add near the other local imports at the top of the file:
import '../../../sprint_report/data/models/sprint_narrative_report.dart';
```

```dart
// ─── Sprint narrative report ─────────────────────────────────────────────────

/// Prompt for the narrative executive Sprint Report. Asks for a single JSON
/// object matching [SprintNarrativeReport]. Explicitly forbids inventing any
/// metric, date, or name not present in the supplied board data — parsed by
/// [parseSprintReport].
String buildSprintReportPrompt(SprintReport r) {
  final epics = r.epics.take(8).map((e) => '"${e.title}" ${e.percent}%').join(', ');
  final people = r.people.take(10).map((p) => '${p.handle}: ${p.done}d/${p.open}open').join(', ');
  return '''
You are writing an executive end-of-sprint report for engineering leadership, based ONLY on the
board data below. Ground every statement in this data. DO NOT invent metrics, percentages, dates,
customer names, or people that are not present here. Do not include latency, uptime, or coverage
numbers — they are not provided.

Reply with ONLY a JSON object (no prose, no markdown fences), with these keys:
{
  "executiveSummary": "2-3 sentence overview citing the real numbers",
  "keyWins": ["short win", ...],                 // from completed epics / high-progress work
  "deliverables": [{"title": "...", "status": "Complete|In Progress|Released", "description": "<= 8 words", "impact": "<= 8 words"}],
  "techHighlights": {"platform": ["..."], "product": ["..."]},
  "challenges": ["risk grounded in stuck/behind work"],
  "mitigations": ["..."],
  "learnings": ["..."],
  "nextPriorities": ["from unfinished/low-progress epics"],
  "recognition": ["@handle — what they did, from per-assignee load"],
  "outcome": "one-sentence verdict"
}
Omit a key rather than fabricate its contents.

Sprint: ${r.sprintName} (${r.dateRange}), ${r.daysRemaining} days remaining, ${r.repoCount} repos.
Progress: ${r.pointsDone} of ${r.pointsCommitted} points done (${r.percentDone}%), ${r.totalTickets} tickets.
Forecast: ${r.forecastLabel}${r.behind ? ' (behind)' : ' (on track)'}.
Estimation: ${r.estimatedTickets} estimated, ${r.unestimatedTickets} unestimated.
Status: ${_statusLines(r)}.
Epics: ${epics.isEmpty ? 'none' : epics}.
Per-assignee (done/open): ${people.isEmpty ? 'n/a' : people}.''';
}

/// Parses the narrative JSON object defensively. Extracts the first `{`…`}`
/// block, decodes it, and builds the model field-by-field. Returns an empty
/// report on any failure (mirrors [parseTriage]). `overallStatus` is left at its
/// default here — the controller overwrites it from the deterministic forecast.
SprintNarrativeReport parseSprintReport(String response) {
  final start = response.indexOf('{');
  final end = response.lastIndexOf('}');
  if (start < 0 || end <= start) return const SprintNarrativeReport();

  final Map<String, dynamic> raw;
  try {
    raw = jsonDecode(response.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return const SprintNarrativeReport();
  }

  List<String> strs(Object? v) =>
      v is List ? v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : const [];
  String str(Object? v) => v?.toString().trim() ?? '';

  final deliverables = (raw['deliverables'] is List ? raw['deliverables'] as List : const [])
      .whereType<Map<String, dynamic>>()
      .map((d) => Deliverable(
            title: str(d['title']),
            status: str(d['status']),
            description: str(d['description']),
            impact: str(d['impact']),
          ))
      .toList();

  final th = raw['techHighlights'] is Map<String, dynamic> ? raw['techHighlights'] as Map<String, dynamic> : const {};

  return SprintNarrativeReport(
    executiveSummary: str(raw['executiveSummary']),
    keyWins: strs(raw['keyWins']),
    deliverables: deliverables,
    techHighlights: TechHighlights(platform: strs(th['platform']), product: strs(th['product'])),
    challenges: strs(raw['challenges']),
    mitigations: strs(raw['mitigations']),
    learnings: strs(raw['learnings']),
    nextPriorities: strs(raw['nextPriorities']),
    recognition: strs(raw['recognition']),
    outcome: str(raw['outcome']),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ai/sprint_report_prompt_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/presentation/helpers/ai_prompts.dart test/features/ai/sprint_report_prompt_test.dart
git commit -m "feat(ai): add sprint report prompt and defensive parser"
```

---

### Task 3: `AiRepository.generateSprintReport`

**Files:**
- Modify: `lib/features/ai/data/repositories/ai_repository.dart` (add abstract method ~line 36 area + impl near `boardInsights`)
- Test: `test/features/ai/generate_sprint_report_test.dart`

**Interfaces:**
- Consumes: `buildSprintReportPrompt`, `parseSprintReport` (Task 2); `LlmClient.complete` (existing).
- Produces: `Future<Result<SprintNarrativeReport>> generateSprintReport(SprintReport report)` on both `AiRepository` (abstract) and `LlmAiRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ai/generate_sprint_report_test.dart
// Test summary:
// - valid JSON from the LLM yields a populated Result.success report
// - malformed JSON yields a Result.success EMPTY report (parser is lenient) -> we treat empty exec summary as failure
// - LLM throwing yields Result.failure
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/data/services/llm_client.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

import 'generate_sprint_report_test.mocks.dart';

@GenerateMocks([LlmClient, GithubApiClient])
SprintReport _report() => const SprintReport(
      sprintName: 'Sprint 24', dateRange: 'Jun 10 - Jun 24', daysRemaining: 2, totalTickets: 47,
      pointsCommitted: 120, repoCount: 3, forecastLabel: 'behind', forecastDetail: 'd', behind: true,
      pointsDone: 82, estimatedTickets: 41, estimatedPoints: 110, unestimatedTickets: 6,
      burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
    );

void main() {
  late MockLlmClient llm;
  late MockGithubApiClient gh;
  late AiRepository repo;

  setUp(() {
    llm = MockLlmClient();
    gh = MockGithubApiClient();
    repo = LlmAiRepository(llm, gh);
  });

  test('valid JSON yields a populated report', () async {
    when(llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens')))
        .thenAnswer((_) async => '{"executiveSummary":"Closed 82/120.","outcome":"Good."}');
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultSuccess>());
    expect((result as ResultSuccess).data.executiveSummary, 'Closed 82/120.');
  });

  test('empty/garbage response yields failure', () async {
    when(llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens')))
        .thenAnswer((_) async => 'sorry no json');
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultFailure>());
  });

  test('LLM throwing yields failure', () async {
    when(llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens')))
        .thenThrow(Exception('boom'));
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultFailure>());
  });
}
```

> Confirm the `GithubApiClient` import path matches the existing repo's constructor (`LlmAiRepository(this._llm, this._github)`). If the class lives elsewhere, fix the import to match — check `lib/features/ai/data/repositories/ai_repository.dart` imports.

- [ ] **Step 2: Generate mocks + run test to verify it fails**

Run: `dart run build_runner build -d` then `flutter test test/features/ai/generate_sprint_report_test.dart`
Expected: FAIL — `generateSprintReport` not defined on `AiRepository`.

- [ ] **Step 3: Add the method**

In the abstract `AiRepository` class, beside the other declarations (near `digestSprint`):

```dart
  /// Generates the structured narrative executive Sprint Report.
  Future<Result<SprintNarrativeReport>> generateSprintReport(SprintReport report);
```

In `LlmAiRepository`, beside `boardInsights`:

```dart
  @override
  Future<Result<SprintNarrativeReport>> generateSprintReport(SprintReport report) async {
    try {
      final text = await _llm.complete(prompt: buildSprintReportPrompt(report), maxTokens: 900);
      final parsed = parseSprintReport(text);
      if (parsed.executiveSummary.isEmpty && parsed.keyWins.isEmpty && parsed.deliverables.isEmpty) {
        return Result.failure('The model returned an unusable report.', StackTrace.current);
      }
      return Result.success(parsed);
    } catch (e, stackTrace) {
      log('Failed to generate sprint report', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not generate the sprint report.'), stackTrace);
    }
  }
```

Add the import at the top of `ai_repository.dart` if not already present:

```dart
import '../../../sprint_report/data/models/sprint_narrative_report.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ai/generate_sprint_report_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/data/repositories/ai_repository.dart test/features/ai/generate_sprint_report_test.dart
git commit -m "feat(ai): add generateSprintReport repository method"
```

---

### Task 4: `SprintNarrativeController`

**Files:**
- Modify: `lib/features/ai/presentation/providers/ai_provider.dart` (append a new controller near `SprintDigestController`)
- Test: `test/features/ai/sprint_narrative_controller_test.dart`

**Interfaces:**
- Consumes: `aiRepositoryProvider` → `generateSprintReport` (Task 3); `SprintReport`; `SprintOutlook`.
- Produces: `sprintNarrativeControllerProvider` exposing `AsyncValue<SprintNarrativeReport>?` with `generate(SprintReport)` and `clear()`. `generate` stamps `overallStatus` from the report forecast (`behind ? SprintOutlook.behind : SprintOutlook.onTrack`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ai/sprint_narrative_controller_test.dart
// Test summary:
// - generate() success sets AsyncData with overallStatus overwritten from forecast
// - generate() failure sets AsyncError
// - clear() resets to null
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

class _FakeRepo implements AiRepository {
  _FakeRepo(this._result);
  final Result<SprintNarrativeReport> _result;
  @override
  Future<Result<SprintNarrativeReport>> generateSprintReport(SprintReport report) async => _result;
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

SprintReport _report({required bool behind}) => SprintReport(
      sprintName: 'S', dateRange: 'r', daysRemaining: 2, totalTickets: 4, pointsCommitted: 10, repoCount: 1,
      forecastLabel: 'f', forecastDetail: 'd', behind: behind, pointsDone: 5, estimatedTickets: 4,
      estimatedPoints: 9, unestimatedTickets: 0,
      burndown: const Burndown(committedPoints: 10, totalDays: 5, todayDay: 3, snapshotsCaptured: 3, snapshotsTotal: 5),
    );

ProviderContainer _container(AiRepository repo) =>
    ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(repo)]);

void main() {
  test('generate success stamps forecast status', () async {
    final c = _container(_FakeRepo(Result.success(const SprintNarrativeReport(executiveSummary: 'x'))));
    addTearDown(c.dispose);
    await c.read(sprintNarrativeControllerProvider.notifier).generate(_report(behind: true));
    final state = c.read(sprintNarrativeControllerProvider);
    expect(state!.value!.overallStatus, SprintOutlook.behind);
  });

  test('generate failure sets error', () async {
    final c = _container(_FakeRepo(Result.failure('nope', StackTrace.current)));
    addTearDown(c.dispose);
    await c.read(sprintNarrativeControllerProvider.notifier).generate(_report(behind: false));
    expect(c.read(sprintNarrativeControllerProvider)!.hasError, isTrue);
  });

  test('clear resets to null', () async {
    final c = _container(_FakeRepo(Result.success(const SprintNarrativeReport(executiveSummary: 'x'))));
    addTearDown(c.dispose);
    await c.read(sprintNarrativeControllerProvider.notifier).generate(_report(behind: false));
    c.read(sprintNarrativeControllerProvider.notifier).clear();
    expect(c.read(sprintNarrativeControllerProvider), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/sprint_narrative_controller_test.dart`
Expected: FAIL — `sprintNarrativeControllerProvider` undefined.

- [ ] **Step 3: Add the controller**

Append to `lib/features/ai/presentation/providers/ai_provider.dart` (after `SprintDigestController`). Add the import for `sprint_narrative_report.dart` at the top if missing:

```dart
/// On-demand structured narrative Sprint Report. `null` = not requested yet.
@Riverpod(keepAlive: true)
class SprintNarrativeController extends _$SprintNarrativeController {
  @override
  AsyncValue<SprintNarrativeReport>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).generateSprintReport(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(
          // Forecast status is deterministic — never trust the AI for it.
          data.copyWith(overallStatus: report.behind ? SprintOutlook.behind : SprintOutlook.onTrack),
        ),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
```

- [ ] **Step 4: Generate code + run test**

Run: `dart run build_runner build -d` then `flutter test test/features/ai/sprint_narrative_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/presentation/providers/ai_provider.dart test/features/ai/sprint_narrative_controller_test.dart
git commit -m "feat(ai): add SprintNarrativeController"
```

---

### Task 5: `report_metrics` (REAL metrics, pure)

**Files:**
- Create: `lib/features/sprint_report/data/export/report_metrics.dart`
- Test: `test/features/sprint_report/data/export/report_metrics_test.dart`

**Interfaces:**
- Consumes: `SprintReport`.
- Produces:
  - `class MetricRow { String label; String? previous; String current; String? delta; }` (Freezed)
  - `List<MetricRow> computeReportMetrics(SprintReport current, {SprintReport? previous})` — rows for points delivered, tickets, % done, unestimated coverage; deltas only when `previous` is supplied.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/sprint_report/data/export/report_metrics_test.dart
// Test summary:
// - current-only report produces rows with null previous/delta
// - with a previous sprint, points/tickets rows carry a delta
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _r({required int done, required int tickets}) => SprintReport(
      sprintName: 'S', dateRange: 'r', daysRemaining: 2, totalTickets: tickets, pointsCommitted: 120,
      repoCount: 3, forecastLabel: 'f', forecastDetail: 'd', behind: true, pointsDone: done,
      estimatedTickets: tickets, estimatedPoints: 110, unestimatedTickets: 6,
      burndown: const Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
    );

void main() {
  test('current-only rows have no delta', () {
    final rows = computeReportMetrics(_r(done: 82, tickets: 47));
    expect(rows, isNotEmpty);
    expect(rows.every((m) => m.previous == null && m.delta == null), isTrue);
    expect(rows.any((m) => m.label.toLowerCase().contains('points') && m.current == '82'), isTrue);
  });

  test('previous sprint yields deltas', () {
    final rows = computeReportMetrics(_r(done: 82, tickets: 47), previous: _r(done: 71, tickets: 38));
    final points = rows.firstWhere((m) => m.label.toLowerCase().contains('points'));
    expect(points.previous, '71');
    expect(points.delta, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/data/export/report_metrics_test.dart`
Expected: FAIL — `report_metrics.dart` not found.

- [ ] **Step 3: Write the model + function**

```dart
// lib/features/sprint_report/data/export/report_metrics.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/sprint_report.dart';

part 'report_metrics.freezed.dart';

/// One row in the report's Metrics table. `previous`/`delta` are null when no
/// prior sprint is available (current-only). Custom (user-typed) rows reuse this.
@freezed
sealed class MetricRow with _$MetricRow {
  const factory MetricRow({
    required String label,
    String? previous,
    required String current,
    String? delta,
  }) = _MetricRow;
}

String _deltaPct(int prev, int curr) {
  if (prev == 0) return curr == 0 ? '0%' : '+$curr';
  final pct = ((curr - prev) / prev * 100).round();
  return '${pct >= 0 ? '↑' : '↓'} ${pct.abs()}%';
}

/// REAL metrics computed deterministically from the board. Never fabricated.
List<MetricRow> computeReportMetrics(SprintReport current, {SprintReport? previous}) {
  return [
    MetricRow(
      label: 'Points delivered',
      previous: previous?.pointsDone.toString(),
      current: current.pointsDone.toString(),
      delta: previous == null ? null : _deltaPct(previous.pointsDone, current.pointsDone),
    ),
    MetricRow(
      label: 'Tickets',
      previous: previous?.totalTickets.toString(),
      current: current.totalTickets.toString(),
      delta: previous == null ? null : _deltaPct(previous.totalTickets, current.totalTickets),
    ),
    MetricRow(
      label: 'Completion',
      previous: previous == null ? null : '${previous.percentDone}%',
      current: '${current.percentDone}%',
      delta: previous == null ? null : _deltaPct(previous.percentDone, current.percentDone),
    ),
    MetricRow(
      label: 'Unestimated tickets',
      previous: previous?.unestimatedTickets.toString(),
      current: current.unestimatedTickets.toString(),
      delta: previous == null ? null : _deltaPct(previous.unestimatedTickets, current.unestimatedTickets),
    ),
  ];
}
```

- [ ] **Step 4: Generate code + run test**

Run: `dart run build_runner build -d` then `flutter test test/features/sprint_report/data/export/report_metrics_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sprint_report/data/export/report_metrics.dart test/features/sprint_report/data/export/report_metrics_test.dart
git commit -m "feat(sprint_report): add REAL report metrics computation"
```

---

### Task 6: Export format enum + email/text builder (pure)

**Files:**
- Create: `lib/features/sprint_report/data/export/sprint_export_format.dart`
- Create: `lib/features/sprint_report/data/export/sprint_email_builder.dart`
- Test: `test/features/sprint_report/data/export/sprint_email_builder_test.dart`

**Interfaces:**
- Consumes: `SprintNarrativeReport`, `SprintOutlook` (Task 1); `MetricRow` (Task 5).
- Produces:
  - `enum SprintExportFormat { fullReport, digest }`
  - `({String subject, String body}) buildSprintEmail({required String sprintName, required String dateRange, required SprintNarrativeReport report, required List<MetricRow> metrics, required SprintExportFormat format})`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/sprint_report/data/export/sprint_email_builder_test.dart
// Test summary:
// - full body contains sprint name, exec summary, a metric, a key win
// - digest body is shorter than full and omits the per-section detail
// - subject carries the sprint name
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_email_builder.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_export_format.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

const _report = SprintNarrativeReport(
  executiveSummary: 'Closed 82 of 120 points.',
  keyWins: ['Released Checkout v2'],
  overallStatus: SprintOutlook.behind,
  outcome: 'Solid sprint.',
);
const _metrics = [MetricRow(label: 'Points delivered', current: '82')];

void main() {
  test('full body contains the key content', () {
    final mail = buildSprintEmail(
      sprintName: 'Sprint 24', dateRange: 'Jun 10 - Jun 24', report: _report, metrics: _metrics,
      format: SprintExportFormat.fullReport,
    );
    expect(mail.subject, contains('Sprint 24'));
    expect(mail.body, contains('Closed 82 of 120 points.'));
    expect(mail.body, contains('Released Checkout v2'));
    expect(mail.body, contains('Points delivered'));
  });

  test('digest is shorter than full', () {
    final full = buildSprintEmail(
      sprintName: 'Sprint 24', dateRange: 'r', report: _report, metrics: _metrics,
      format: SprintExportFormat.fullReport).body;
    final digest = buildSprintEmail(
      sprintName: 'Sprint 24', dateRange: 'r', report: _report, metrics: _metrics,
      format: SprintExportFormat.digest).body;
    expect(digest.length, lessThan(full.length));
    expect(digest, contains('Closed 82 of 120 points.'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/data/export/sprint_email_builder_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Write the enum + builder**

```dart
// lib/features/sprint_report/data/export/sprint_export_format.dart
/// Length variants for an exported sprint report.
enum SprintExportFormat { fullReport, digest }
```

```dart
// lib/features/sprint_report/data/export/sprint_email_builder.dart
import '../models/sprint_narrative_report.dart';
import 'report_metrics.dart';
import 'sprint_export_format.dart';

String _statusLabel(SprintOutlook h) => switch (h) {
  SprintOutlook.onTrack => '🟢 On Track',
  SprintOutlook.atRisk => '🟡 At Risk',
  SprintOutlook.behind => '🔴 Behind Schedule',
};

void _section(StringBuffer b, String title, List<String> items) {
  if (items.isEmpty) return;
  b.writeln();
  b.writeln(title.toUpperCase());
  for (final i in items) {
    b.writeln('  - $i');
  }
}

/// Builds the plain-text email subject + body (also used for clipboard copy).
({String subject, String body}) buildSprintEmail({
  required String sprintName,
  required String dateRange,
  required SprintNarrativeReport report,
  required List<MetricRow> metrics,
  required SprintExportFormat format,
}) {
  final subject = 'Sprint Report — $sprintName';
  final b = StringBuffer()
    ..writeln('Sprint Report — $sprintName')
    ..writeln(dateRange)
    ..writeln()
    ..writeln('STATUS: ${_statusLabel(report.overallStatus)}')
    ..writeln()
    ..writeln(report.executiveSummary);

  _section(b, 'Key Wins', report.keyWins);

  if (metrics.isNotEmpty) {
    b.writeln();
    b.writeln('METRICS');
    for (final m in metrics) {
      final prev = m.previous == null ? '' : ' (prev ${m.previous})';
      final delta = m.delta == null ? '' : ' ${m.delta}';
      b.writeln('  - ${m.label}: ${m.current}$prev$delta');
    }
  }

  if (format == SprintExportFormat.fullReport) {
    _section(b, 'Major Deliverables',
        report.deliverables.map((d) => '${d.title} — ${d.status}: ${d.impact}').toList());
    _section(b, 'Platform Highlights', report.techHighlights.platform);
    _section(b, 'Product Highlights', report.techHighlights.product);
    _section(b, 'Challenges & Risks', report.challenges);
    _section(b, 'Mitigations', report.mitigations);
    _section(b, 'Learnings', report.learnings);
    _section(b, 'Next Sprint Priorities', report.nextPriorities);
    _section(b, 'Team Recognition', report.recognition);
  }

  if (report.outcome.isNotEmpty) {
    b.writeln();
    b.writeln('OUTCOME: ${report.outcome}');
  }
  b.writeln();
  b.writeln('— TurboBoard');
  return (subject: subject, body: b.toString());
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sprint_report/data/export/sprint_email_builder_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sprint_report/data/export/sprint_export_format.dart lib/features/sprint_report/data/export/sprint_email_builder.dart test/features/sprint_report/data/export/sprint_email_builder_test.dart
git commit -m "feat(sprint_report): add export format enum and email/text builder"
```

---

### Task 7: PDF builder (add `pdf` + `printing` deps)

**Files:**
- Modify: `pubspec.yaml` (add `pdf`, `printing`)
- Create: `lib/features/sprint_report/data/export/sprint_pdf_builder.dart`
- Test: `test/features/sprint_report/data/export/sprint_pdf_builder_test.dart`

**Interfaces:**
- Consumes: `SprintNarrativeReport`, `SprintOutlook`, `Deliverable` (Task 1); `MetricRow` (Task 5); `SprintExportFormat` (Task 6).
- Produces: `pw.Document buildSprintPdf({required String sprintName, required String dateRange, required String reportDate, required SprintNarrativeReport report, required List<MetricRow> metrics, required SprintExportFormat format})` — a light-themed document.

- [ ] **Step 1: Add dependencies**

Verify on pub.dev that `pdf` and `printing` list macOS, Windows, Linux, web, iOS, Android, then:

```bash
flutter pub add pdf printing
```

Expected: `pubspec.yaml` gains `pdf:` and `printing:` under dependencies; `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/sprint_report/data/export/sprint_pdf_builder_test.dart
// Test summary:
// - full report builds a non-empty PDF (document.save() returns bytes)
// - digest builds a non-empty PDF
// - builds without throwing when narrative lists and metrics are empty
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_export_format.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_pdf_builder.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

const _report = SprintNarrativeReport(
  executiveSummary: 'Closed 82 of 120 points.',
  keyWins: ['Released Checkout v2'],
  overallStatus: SprintOutlook.behind,
  deliverables: [Deliverable(title: 'Checkout v2', status: 'Complete', description: 'Dashboard', impact: 'Self-service')],
  outcome: 'Solid sprint.',
);
const _metrics = [MetricRow(label: 'Points delivered', previous: '71', current: '82', delta: '↑ 15%')];

void main() {
  test('full report builds non-empty PDF', () async {
    final doc = buildSprintPdf(
      sprintName: 'Sprint 24', dateRange: 'Jun 10 - Jun 24', reportDate: 'Jun 24, 2026',
      report: _report, metrics: _metrics, format: SprintExportFormat.fullReport);
    final bytes = await doc.save();
    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('digest builds non-empty PDF', () async {
    final doc = buildSprintPdf(
      sprintName: 'Sprint 24', dateRange: 'r', reportDate: 'd',
      report: _report, metrics: _metrics, format: SprintExportFormat.digest);
    expect((await doc.save()).lengthInBytes, greaterThan(0));
  });

  test('empty narrative builds without throwing', () async {
    final doc = buildSprintPdf(
      sprintName: 'S', dateRange: 'r', reportDate: 'd',
      report: const SprintNarrativeReport(executiveSummary: 'x'), metrics: const [],
      format: SprintExportFormat.fullReport);
    expect((await doc.save()).lengthInBytes, greaterThan(0));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/data/export/sprint_pdf_builder_test.dart`
Expected: FAIL — `sprint_pdf_builder.dart` not found.

- [ ] **Step 4: Write the builder**

```dart
// lib/features/sprint_report/data/export/sprint_pdf_builder.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/sprint_narrative_report.dart';
import 'report_metrics.dart';
import 'sprint_export_format.dart';

// Light, print-friendly palette (the on-screen app is dark; printed docs are not).
const _ink = PdfColor.fromInt(0xFF1A1A1F);
const _muted = PdfColor.fromInt(0xFF8A8A94);
const _rule = PdfColor.fromInt(0xFFE6E6EA);
const _accent = PdfColor.fromInt(0xFF0E9FBD);

String _statusLabel(SprintOutlook h) => switch (h) {
  SprintOutlook.onTrack => 'On Track',
  SprintOutlook.atRisk => 'At Risk',
  SprintOutlook.behind => 'Behind Schedule',
};

pw.Widget _h(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule))),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
    );

pw.Widget _bullets(List<String> items) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items
          .map((i) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('• $i', style: const pw.TextStyle(fontSize: 10, color: _ink)),
              ))
          .toList(),
    );

pw.Widget? _section(String title, List<String> items) =>
    items.isEmpty ? null : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_h(title), _bullets(items)]);

/// Builds the narrative Sprint Report PDF on a light theme. `format` controls
/// whether every section renders (full) or only summary + status + deliverables
/// + metrics (digest).
pw.Document buildSprintPdf({
  required String sprintName,
  required String dateRange,
  required String reportDate,
  required SprintNarrativeReport report,
  required List<MetricRow> metrics,
  required SprintExportFormat format,
}) {
  final doc = pw.Document();
  final isFull = format == SprintExportFormat.fullReport;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      build: (context) {
        final blocks = <pw.Widget>[
          // Header
          pw.Text('Sprint Report — $sprintName',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text('$dateRange  ·  Report date: $reportDate', style: const pw.TextStyle(fontSize: 10, color: _muted)),
          pw.SizedBox(height: 4),
          pw.Text('Status: ${_statusLabel(report.overallStatus)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accent)),
          // Executive summary
          _h('Executive Summary'),
          pw.Text(report.executiveSummary, style: const pw.TextStyle(fontSize: 10, color: _ink)),
        ];

        if (report.keyWins.isNotEmpty) blocks.add(_section('Key Wins', report.keyWins)!);

        if (report.deliverables.isNotEmpty) {
          blocks.add(_h('Major Deliverables'));
          blocks.add(pw.Table.fromTextArray(
            cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
            headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule))),
            cellAlignment: pw.Alignment.centerLeft,
            border: null,
            headers: const ['Initiative', 'Status', 'Description', 'Impact'],
            data: report.deliverables.map((d) => [d.title, d.status, d.description, d.impact]).toList(),
          ));
        }

        if (metrics.isNotEmpty) {
          blocks.add(_h('Metrics'));
          blocks.add(pw.Table.fromTextArray(
            cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
            headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule))),
            border: null,
            headers: const ['Metric', 'Previous', 'Current', 'Change'],
            data: metrics.map((m) => [m.label, m.previous ?? '—', m.current, m.delta ?? '—']).toList(),
          ));
        }

        if (isFull) {
          blocks.add(_section('Platform Highlights', report.techHighlights.platform) ?? pw.SizedBox());
          blocks.add(_section('Product Highlights', report.techHighlights.product) ?? pw.SizedBox());
          blocks.add(_section('Challenges & Risks', report.challenges) ?? pw.SizedBox());
          blocks.add(_section('Mitigations', report.mitigations) ?? pw.SizedBox());
          blocks.add(_section('Learnings', report.learnings) ?? pw.SizedBox());
          blocks.add(_section('Next Sprint Priorities', report.nextPriorities) ?? pw.SizedBox());
          blocks.add(_section('Team Recognition', report.recognition) ?? pw.SizedBox());
        }

        if (report.outcome.isNotEmpty) {
          blocks.add(_h('Sprint Outcome'));
          blocks.add(pw.Text(report.outcome,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)));
        }

        return blocks;
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('TurboBoard · page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ),
    ),
  );
  return doc;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/sprint_report/data/export/sprint_pdf_builder_test.dart`
Expected: PASS (3 tests).

> If `pw.Table.fromTextArray` is unavailable in the installed `pdf` version, use `pw.TableHelper.fromTextArray` (same parameters) — newer `pdf` versions moved it to `TableHelper`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/features/sprint_report/data/export/sprint_pdf_builder.dart test/features/sprint_report/data/export/sprint_pdf_builder_test.dart
git commit -m "feat(sprint_report): add light-theme PDF builder (pdf+printing deps)"
```

---

### Task 8: `SprintExporter` interface + default impl + provider

**Files:**
- Create: `lib/features/sprint_report/data/export/sprint_exporter.dart`
- Create: `lib/features/sprint_report/presentation/providers/sprint_export_provider.dart`
- Test: `test/features/sprint_report/data/export/sprint_exporter_test.dart`

**Interfaces:**
- Consumes: `pw.Document` (from `pdf`); existing `url_launcher`, `flutter/services` Clipboard, `printing`.
- Produces:
  - `abstract interface class SprintExporter { Future<void> copySummary(String text); Future<bool> openEmail({required String subject, required String body}); Future<void> sharePdf(pw.Document doc, {required String filename}); }`
  - `class DefaultSprintExporter implements SprintExporter`
  - `sprintExporterProvider` (`@Riverpod(keepAlive: true) SprintExporter sprintExporter(Ref ref) => const DefaultSprintExporter();`)

- [ ] **Step 1: Write the failing test (interface contract via a fake)**

```dart
// test/features/sprint_report/data/export/sprint_exporter_test.dart
// Test summary:
// - a fake SprintExporter records calls (proves the interface shape compiles/usable)
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:turbo_board/features/sprint_report/data/export/sprint_exporter.dart';

class _Fake implements SprintExporter {
  String? copied;
  ({String subject, String body})? emailed;
  String? pdfName;
  @override
  Future<void> copySummary(String text) async => copied = text;
  @override
  Future<bool> openEmail({required String subject, required String body}) async {
    emailed = (subject: subject, body: body);
    return true;
  }
  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) async => pdfName = filename;
}

void main() {
  test('fake exporter records calls', () async {
    final f = _Fake();
    await f.copySummary('hi');
    await f.openEmail(subject: 's', body: 'b');
    await f.sharePdf(pw.Document(), filename: 'r.pdf');
    expect(f.copied, 'hi');
    expect(f.emailed!.subject, 's');
    expect(f.pdfName, 'r.pdf');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/data/export/sprint_exporter_test.dart`
Expected: FAIL — `sprint_exporter.dart` not found.

- [ ] **Step 3: Write the interface + default impl**

```dart
// lib/features/sprint_report/data/export/sprint_exporter.dart
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps the only impure export side-effects so widgets and pure builders stay
/// testable. Substitute a fake in tests / mock mode.
abstract interface class SprintExporter {
  Future<void> copySummary(String text);

  /// Opens the OS mail composer via `mailto:`. Returns false if no handler.
  Future<bool> openEmail({required String subject, required String body});

  /// Routes the PDF to the native print/save dialog (desktop), share sheet
  /// (mobile), or browser print (web).
  Future<void> sharePdf(pw.Document doc, {required String filename});
}

class DefaultSprintExporter implements SprintExporter {
  const DefaultSprintExporter();

  @override
  Future<void> copySummary(String text) => Clipboard.setData(ClipboardData(text: text));

  @override
  Future<bool> openEmail({required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) =>
      Printing.layoutPdf(onLayout: (_) => doc.save(), name: filename);
}
```

```dart
// lib/features/sprint_report/presentation/providers/sprint_export_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/export/sprint_exporter.dart';

part 'sprint_export_provider.g.dart';

@Riverpod(keepAlive: true)
SprintExporter sprintExporter(Ref ref) => const DefaultSprintExporter();
```

- [ ] **Step 4: Generate code + run test**

Run: `dart run build_runner build -d` then `flutter test test/features/sprint_report/data/export/sprint_exporter_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sprint_report/data/export/sprint_exporter.dart lib/features/sprint_report/presentation/providers/sprint_export_provider.dart test/features/sprint_report/data/export/sprint_exporter_test.dart
git commit -m "feat(sprint_report): add SprintExporter interface, default impl, provider"
```

---

### Task 9: `report_export_dialog` (preview, format toggle, custom rows, actions)

**Files:**
- Create: `lib/features/sprint_report/presentation/view/widgets/report_export_dialog.dart`
- Test: `test/features/sprint_report/presentation/report_export_dialog_test.dart`

**Interfaces:**
- Consumes: `sprintNarrativeControllerProvider` (Task 4); `sprintExporterProvider` (Task 8); `computeReportMetrics` + `MetricRow` (Task 5); `buildSprintEmail` (Task 6); `buildSprintPdf` (Task 7); `SprintExportFormat` (Task 6); `SprintReport` (existing).
- Produces: `class ReportExportDialog extends HookConsumerWidget` taking `final SprintReport report;`. Renders: generate step (if narrative null/error) → preview + `TetherSegmentedButtonGroup` Full/Digest + custom-metric mini-form + actions `Copy summary` / `Email` / `PDF`. Each action assembles `metrics = computeReportMetrics(report) + customRows`, calls builder, then the exporter; wraps in try/catch → `ScaffoldMessenger` SnackBar. Email failure path also calls `copySummary` and shows "summary copied".

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/sprint_report/presentation/report_export_dialog_test.dart
// Test summary:
// - with a generated narrative, tapping "Copy summary" calls exporter.copySummary with the built text
// - tapping "PDF" calls exporter.sharePdf
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_exporter.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/features/sprint_report/presentation/providers/sprint_export_provider.dart';
import 'package:turbo_board/features/sprint_report/presentation/view/widgets/report_export_dialog.dart';

class _Fake implements SprintExporter {
  String? copied;
  bool pdfCalled = false;
  @override
  Future<void> copySummary(String text) async => copied = text;
  @override
  Future<bool> openEmail({required String subject, required String body}) async => true;
  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) async => pdfCalled = true;
}

SprintReport _report() => const SprintReport(
      sprintName: 'Sprint 24', dateRange: 'Jun 10 - Jun 24', daysRemaining: 2, totalTickets: 47,
      pointsCommitted: 120, repoCount: 3, forecastLabel: 'behind', forecastDetail: 'd', behind: true,
      pointsDone: 82, estimatedTickets: 41, estimatedPoints: 110, unestimatedTickets: 6,
      burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
    );

void main() {
  testWidgets('Copy summary invokes exporter with built text', (tester) async {
    final fake = _Fake();
    final report = _report();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sprintExporterProvider.overrideWithValue(fake),
        // Seed a generated narrative so the dialog shows the preview + actions.
        sprintNarrativeControllerProvider.overrideWith(() => _SeededController()),
      ],
      child: MaterialApp(home: Scaffold(body: ReportExportDialog(report: report))),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy summary'));
    await tester.pumpAndSettle();
    expect(fake.copied, isNotNull);
    expect(fake.copied, contains('Sprint 24'));
  });

  testWidgets('PDF invokes exporter.sharePdf', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sprintExporterProvider.overrideWithValue(fake),
        sprintNarrativeControllerProvider.overrideWith(() => _SeededController()),
      ],
      child: MaterialApp(home: Scaffold(body: ReportExportDialog(report: _report()))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(fake.pdfCalled, isTrue);
  });
}

class _SeededController extends SprintNarrativeController {
  @override
  AsyncValue<SprintNarrativeReport>? build() => const AsyncValue.data(
        SprintNarrativeReport(executiveSummary: 'Closed 82/120.', keyWins: ['Shipped X'], outcome: 'Good.'),
      );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sprint_report/presentation/report_export_dialog_test.dart`
Expected: FAIL — `report_export_dialog.dart` not found.

- [ ] **Step 3: Write the dialog**

```dart
// lib/features/sprint_report/presentation/view/widgets/report_export_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../data/export/report_metrics.dart';
import '../../../data/export/sprint_email_builder.dart';
import '../../../data/export/sprint_export_format.dart';
import '../../../data/export/sprint_pdf_builder.dart';
import '../../../data/models/sprint_report.dart';
import '../../providers/sprint_export_provider.dart';

/// On-demand narrative report + export surface. Generates via the BYOK AI CTA
/// (never auto), previews the result, and exports as copy / email / PDF.
class ReportExportDialog extends HookConsumerWidget {
  const ReportExportDialog({super.key, required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrative = ref.watch(sprintNarrativeControllerProvider);
    final format = useState(SprintExportFormat.fullReport);
    final customRows = useState<List<MetricRow>>(const []);

    // Not requested yet, or errored → show the generate step.
    if (narrative == null || narrative is AsyncError) {
      return _GenerateStep(
        error: narrative is AsyncError ? narrative.error.toString() : null,
        onGenerate: () => ref.read(sprintNarrativeControllerProvider.notifier).generate(report),
      );
    }
    if (narrative is AsyncLoading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }

    final data = narrative.value!;
    final metrics = [...computeReportMetrics(report), ...customRows.value];

    Future<void> run(Future<void> Function() action, {String? copyFallback}) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (e) {
        if (copyFallback != null) {
          await ref.read(sprintExporterProvider).copySummary(copyFallback);
        }
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }

    final exporter = ref.read(sprintExporterProvider);

    ({String subject, String body}) mail() => buildSprintEmail(
          sprintName: report.sprintName,
          dateRange: report.dateRange,
          report: data,
          metrics: metrics,
          format: format.value,
        );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sprint Report', style: TbText.display(size: 14, tracking: 1.5)),
          const SizedBox(height: 12),
          // Format toggle.
          Row(
            children: [
              for (final f in SprintExportFormat.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f == SprintExportFormat.fullReport ? 'Full' : 'Digest'),
                    selected: format.value == f,
                    onSelected: (_) => format.value = f,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Text(mail().body, style: TbText.body(size: 12)),
            ),
          ),
          const SizedBox(height: 8),
          _AddMetricRow(onAdd: (row) => customRows.value = [...customRows.value, row]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => run(() => exporter.copySummary(mail().body)),
                child: const Text('Copy summary'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => run(() async {
                  final m = mail();
                  final ok = await exporter.openEmail(subject: m.subject, body: m.body);
                  if (!ok) {
                    await exporter.copySummary(m.body);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('No mail client — summary copied to clipboard')));
                    }
                  }
                }, copyFallback: mail().body),
                child: const Text('Email'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => run(() => exporter.sharePdf(
                      buildSprintPdf(
                        sprintName: report.sprintName,
                        dateRange: report.dateRange,
                        reportDate: report.dateRange,
                        report: data,
                        metrics: metrics,
                        format: format.value,
                      ),
                      filename: 'sprint-report-${report.sprintName}.pdf',
                    )),
                child: const Text('PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenerateStep extends StatelessWidget {
  const _GenerateStep({required this.onGenerate, this.error});

  final VoidCallback onGenerate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Generate Sprint Report', style: TbText.display(size: 14, tracking: 1.5)),
          const SizedBox(height: 8),
          Text(
            error ?? 'Writes an executive summary from the sprint board using your BYOK AI key.',
            textAlign: TextAlign.center,
            style: TbText.body(size: 12, color: error != null ? TbSignal.bad.border : TbColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onGenerate, child: Text(error != null ? 'Retry' : 'Generate')),
        ],
      ),
    );
  }
}

/// Minimal in-memory custom metric entry (label / previous / current).
class _AddMetricRow extends HookWidget {
  const _AddMetricRow({required this.onAdd});

  final void Function(MetricRow) onAdd;

  @override
  Widget build(BuildContext context) {
    final label = useTextEditingController();
    final prev = useTextEditingController();
    final curr = useTextEditingController();
    return Row(
      children: [
        Expanded(flex: 2, child: TextField(controller: label, decoration: const InputDecoration(hintText: 'Metric'))),
        const SizedBox(width: 6),
        Expanded(child: TextField(controller: prev, decoration: const InputDecoration(hintText: 'Prev'))),
        const SizedBox(width: 6),
        Expanded(child: TextField(controller: curr, decoration: const InputDecoration(hintText: 'Now'))),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          onPressed: () {
            if (label.text.trim().isEmpty || curr.text.trim().isEmpty) return;
            onAdd(MetricRow(
              label: label.text.trim(),
              previous: prev.text.trim().isEmpty ? null : prev.text.trim(),
              current: curr.text.trim(),
            ));
            label.clear();
            prev.clear();
            curr.clear();
          },
        ),
      ],
    );
  }
}
```

> The test seeds the controller with `overrideWith(() => _SeededController())`, so the generate step is skipped and Copy/PDF actions are present. `TbText`/`TbColors`/`TbSignal` come from `shared/ui/theme/` (same imports the sprint report screen uses). If `ChoiceChip` styling clashes with the dark theme in manual testing, swap to `TetherSegmentedButtonGroup` from turbo_ui — read its API first.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sprint_report/presentation/report_export_dialog_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sprint_report/presentation/view/widgets/report_export_dialog.dart test/features/sprint_report/presentation/report_export_dialog_test.dart
git commit -m "feat(sprint_report): add report export dialog"
```

---

### Task 10: Wire the CTA into the Sprint Report header

**Files:**
- Modify: `lib/features/sprint_report/presentation/view/sprint_report_screen.dart` (header `Row`, ~lines 58-74; the `data: (r) => _Body(report: r)` path provides the loaded `SprintReport`)
- Test: manual (covered by Task 9 widget test for the dialog itself)

**Interfaces:**
- Consumes: `ReportExportDialog` (Task 9); `aiKeyReadyProvider` (existing); the loaded `SprintReport r` in the header scope.

- [ ] **Step 1: Add an EXPORT action beside REFRESH**

The header `Row` currently watches `report` (an `AsyncValue<SprintReport>`). Add an EXPORT pill that is enabled only when there is loaded data and a ready BYOK key. Insert before the existing `REFRESH` `GestureDetector` (after the `TbBadge('Issues', …)` + `SizedBox`):

```dart
// inside the header Row, with `report` (AsyncValue<SprintReport>) and `ref` in scope:
if (report.hasValue) ...[
  Builder(
    builder: (context) {
      final keyReady = ref.watch(aiKeyReadyProvider);
      return GestureDetector(
        onTap: keyReady
            ? () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: TbColors.surface,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ReportExportDialog(report: report.value!),
                    ),
                  ),
                )
            : null,
        child: Text(
          'EXPORT',
          style: TbText.label(
            size: 11,
            color: keyReady ? TbColors.cyan : TbColors.muted,
            tracking: 0.8,
          ),
        ),
      );
    },
  ),
  const SizedBox(width: 14),
],
```

Add the import at the top of the file:

```dart
import 'widgets/report_export_dialog.dart';
```

- [ ] **Step 2: Verify it builds and analyzes**

Run: `dart analyze lib/features/sprint_report/presentation/view/sprint_report_screen.dart`
Expected: No issues.

- [ ] **Step 3: Manual smoke (one desktop + web)**

Run: `flutter run -d macos` then `flutter run -d chrome`. With a BYOK key set, open Sprint Report → tap EXPORT → Generate → toggle Full/Digest → Copy / Email / PDF. Confirm the PDF dialog opens and the copied text matches the preview. Without a key, EXPORT is muted/disabled.

- [ ] **Step 4: Commit**

```bash
git add lib/features/sprint_report/presentation/view/sprint_report_screen.dart
git commit -m "feat(sprint_report): add EXPORT CTA to header"
```

---

### Task 11: Full verification pass

**Files:** none (gate)

- [ ] **Step 1: Format**

Run: `dart format --line-length 120 --set-exit-if-changed .`
Expected: zero files changed. If any change, run `dart format --line-length 120 .` and re-run.

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: No issues.

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 4: Commit any formatting fixes**

```bash
git add -A
git commit -m "chore(sprint_report): formatting and analysis pass" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:**
- Narrative exec report model → Task 1. ✓
- AI generation grounded + no-fabrication → Tasks 2, 3 (prompt forbids invented metrics; model has no metric fields). ✓
- On-demand CTA, never auto, BYOK-gated → Tasks 4 (controller), 9 (generate step), 10 (`aiKeyReadyProvider` gate). ✓
- REAL metrics + prev-sprint delta (with current-only fallback) → Task 5. ✓
- YOU custom rows (in-memory) → Task 9 `_AddMetricRow`. ✓
- Light PDF, Full/Digest → Tasks 6, 7. ✓
- Copy / email(mailto)+fallback / PDF via printing → Tasks 8, 9. ✓
- SprintExporter interface for testability → Task 8. ✓
- Cross-platform deps verified → Task 7 Step 1. ✓
- Pre-completion gate → Task 11. ✓
- Out of scope honored: no inline prose editor, no persistence, no programmatic send. ✓

**Open item (flagged in spec):** previous-sprint fetching for deltas. `computeReportMetrics` accepts an optional `previous`; Task 10 currently passes none, so metrics render current-only. Wiring a previous-sprint fetch is a clean follow-up (pass `previous:` from a provider) and does not block this plan.

**Placeholder scan:** none — every code step is complete.

**Type consistency:** `SprintNarrativeReport`/`Deliverable`/`TechHighlights`/`SprintOutlook` (Task 1) used consistently in 2/3/4/6/7/9. `MetricRow` (Task 5) used in 6/7/9. `SprintExportFormat` (Task 6) used in 6/7/9. `SprintExporter` method names (`copySummary`/`openEmail`/`sharePdf`) consistent across 8/9 and both test fakes. `buildSprintEmail` returns `({String subject, String body})` consistently. ✓
