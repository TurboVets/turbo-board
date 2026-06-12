// Test summary:
// - LeadCockpitScreen renders the sprint header, team load section and stuck list once data loads.
// - The AI Sprint Brief button reveals the brief narrative when tapped.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/lead_cockpit_repository.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/view/lead_cockpit_screen.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

Widget _host() => ProviderScope(
  overrides: [leadCockpitRepositoryProvider.overrideWithValue(const MockLeadCockpitRepository())],
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
  });

  testWidgets('AI Sprint Brief button reveals the narrative', (tester) async {
    await _desktopSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sprint Brief'), findsOneWidget);
    await tester.tap(find.text('Sprint Brief'));
    await tester.pump(); // -> loading
    await tester.pump(const Duration(milliseconds: 1200)); // -> ready

    expect(find.textContaining('trending one to two days behind'), findsOneWidget);
    expect(find.text('Hide brief'), findsOneWidget);
  });
}
