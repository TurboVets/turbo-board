// test/features/ai/presentation/providers/ai_digest_controllers_test.dart
//
// Test summary:
// - SprintSummaryController: idle (null) → data on repo success.
// - SprintSummaryController: → error when the repo fails.
// - WeeklyDigestController: idle (null) → data on repo success.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
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

final _emptyFlow = SprintFlow(start: DateTime(2026, 6, 15), end: DateTime(2026, 6, 26), days: const []);

CockpitData _cockpit() => CockpitData(
  sprint: SprintHealth(
    name: 'S24',
    daysRemaining: 6,
    endLabel: 'x',
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
  flow: _emptyFlow,
);

void main() {
  late MockAiRepository ai;
  ProviderContainer makeContainer() => ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);

  setUpAll(() => provideDummy<Result<String>>(Result.success('')));
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

  test('WeeklyDigestController: null → data on success', () async {
    when(ai.weeklyDigest(any)).thenAnswer((_) async => Result.success('- shipped 9'));
    final c = makeContainer();
    addTearDown(c.dispose);

    expect(c.read(weeklyDigestControllerProvider), isNull);
    await c.read(weeklyDigestControllerProvider.notifier).generate(_cockpit());
    expect(c.read(weeklyDigestControllerProvider), const AsyncData<String>('- shipped 9'));
  });
}
