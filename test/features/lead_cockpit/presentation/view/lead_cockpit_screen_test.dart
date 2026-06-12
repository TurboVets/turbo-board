// Test summary:
// - LeadCockpitScreen renders the sprint header, team load section and stuck list once data loads.
// - The AI Sprint Brief button is hidden when no Anthropic key is set.
// - With a key + stubbed AI repo, tapping Sprint Brief generates and reveals the narrative, then hides it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/lead_cockpit_repository.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/view/lead_cockpit_screen.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
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
}

Widget _host({bool keyReady = false, AiRepository? ai}) => ProviderScope(
  overrides: [
    leadCockpitRepositoryProvider.overrideWithValue(const MockLeadCockpitRepository()),
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
    expect(find.text('AGING / STUCK · SITTING TOO LONG IN A STATUS'), findsOneWidget);
    expect(find.text('tromero-tv'), findsWidgets);
    expect(find.text('OVERLOADED'), findsOneWidget);
    // No key set → the AI brief button is not offered.
    expect(find.text('Sprint Brief'), findsNothing);
  });

  testWidgets('generates and reveals the AI brief when a key is set', (tester) async {
    await _desktopSurface(tester);
    await tester.pumpWidget(_host(keyReady: true, ai: _StubAi()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sprint Brief'), findsOneWidget);
    await tester.tap(find.text('Sprint Brief'));
    await tester.pump(); // -> loading
    await tester.pump(); // -> data (stub resolves immediately)

    expect(find.textContaining('tromero-tv is overloaded'), findsOneWidget);
    expect(find.text('Hide brief'), findsOneWidget);

    // Toggling hides the panel again.
    await tester.tap(find.text('Hide brief'));
    await tester.pump();
    expect(find.textContaining('tromero-tv is overloaded'), findsNothing);
    expect(find.text('Sprint Brief'), findsOneWidget);
  });
}
