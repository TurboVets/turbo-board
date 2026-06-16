// Test summary:
// - With a project selected, renders the sprint header, team load section and stuck list once data loads.
// - The AI Sprint Brief button is hidden when no Anthropic key is set.
// - With a key + stubbed AI repo, tapping Sprint Brief generates and reveals the narrative, then hides it.
// - With no project selected, shows the project picker listing available boards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/ai/data/models/triage_item.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/lead_cockpit_repository.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/view/lead_cockpit_screen.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

const _briefText = 'Sprint 24 is one day behind; tromero-tv is overloaded — rebalance two P1s.';

/// AI repo stub: only [sprintBrief] is exercised here.
class _StubAi implements AiRepository {
  @override
  Future<Result<String>> sprintBrief(CockpitData cockpit) async => Result.success(_briefText);

  @override
  Future<Result<bool>> validateKey() => throw UnimplementedError();
  @override
  Future<Result<List<String>>> summarize(PrDetail detail) => throw UnimplementedError();
  @override
  Future<Result<String>> draftReply(PrDetail detail, ReplyIntent intent) => throw UnimplementedError();
  @override
  Future<Result<String>> summarizeSprint(SprintReport report) => throw UnimplementedError();
  @override
  Future<Result<String>> digestSprint(SprintReport report) => throw UnimplementedError();
  @override
  Future<Result<String>> weeklyDigest(CockpitData cockpit) async => Result.success(_briefText);
  @override
  Future<Result<List<TriageItem>>> triage(List<PrData> prs) => throw UnimplementedError();
}

/// Selection notifier with a fixed value (no shared_preferences plugin in tests).
class _FixedProject extends SelectedProjectNotifier {
  _FixedProject(this._value);
  final ProjectRef? _value;
  @override
  ProjectRef? build() => _value;
}

const _selected = ProjectRef(owner: 'TurboVets', number: 8, title: 'Mobile Space');

Widget _host({ProjectRef? selected = _selected, bool keyReady = false, AiRepository? ai}) => ProviderScope(
  overrides: [
    leadCockpitRepositoryProvider.overrideWithValue(const MockLeadCockpitRepository()),
    selectedProjectProvider.overrideWith(() => _FixedProject(selected)),
    aiKeyReadyProvider.overrideWithValue(keyReady),
    if (ai != null) aiRepositoryProvider.overrideWithValue(ai),
  ],
  child: MaterialApp(
    theme: getAppTheme(),
    home: const Scaffold(body: LeadCockpitScreen()),
  ),
);

/// The cockpit is a desktop-first screen (content max-width 1180); size the test
/// surface accordingly so fixed-width columns lay out as designed.
Future<void> _desktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('renders sprint header, sections and stuck items after load', (tester) async {
    await _desktopSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 500)); // mock latency

    expect(find.text('Sprint 24 · Mobile Space'), findsOneWidget);
    expect(find.text('TEAM LOAD'), findsOneWidget);
    // Sprint-health status tiles render above the team section.
    expect(find.text('DONE'), findsWidgets);
    expect(find.text('AT RISK'), findsOneWidget);
    // Aging/stuck section renders with its rows (a known stuck ticket title).
    expect(find.text('AGING / STUCK · SITTING TOO LONG IN A STATUS'), findsOneWidget);
    expect(find.text('Harden deeplink cold-start routes'), findsWidgets);
    expect(find.text('tromero-tv'), findsWidgets);
    // OVERLOADED badge is disabled for now (thresholds not calibrated).
    expect(find.text('OVERLOADED'), findsNothing);
    // No key set → the AI cards (and their pills) are not offered.
    expect(find.text('SPRINT BRIEF'), findsNothing);
  });

  testWidgets('generates and reveals the AI brief when a key is set', (tester) async {
    await _desktopSurface(tester);
    await tester.pumpWidget(_host(keyReady: true, ai: _StubAi()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SPRINT BRIEF'), findsOneWidget);
    await tester.tap(find.text('SPRINT BRIEF'));
    await tester.pump(); // -> loading
    await tester.pump(); // -> data (stub resolves immediately)

    expect(find.textContaining('tromero-tv is overloaded'), findsOneWidget);
    expect(find.text('HIDE'), findsOneWidget);

    // Toggling hides the panel again.
    await tester.tap(find.text('HIDE'));
    await tester.pump();
    expect(find.textContaining('tromero-tv is overloaded'), findsNothing);
    expect(find.text('SPRINT BRIEF'), findsOneWidget);
  });

  testWidgets('shows the project picker when no board is selected', (tester) async {
    await _desktopSurface(tester);
    await tester.pumpWidget(_host(selected: null));
    await tester.pump(const Duration(milliseconds: 300)); // listProjects mock latency

    expect(find.text('CHOOSE A PROJECT'), findsOneWidget);
    expect(find.text('Mobile Space'), findsOneWidget);
    expect(find.text('Platform Roadmap'), findsOneWidget);
    // The board itself is not shown until a project is picked.
    expect(find.text('TEAM LOAD'), findsNothing);
  });
}
