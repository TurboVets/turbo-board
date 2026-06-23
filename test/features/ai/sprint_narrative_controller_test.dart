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
  sprintName: 'S',
  dateRange: 'r',
  daysRemaining: 2,
  totalTickets: 4,
  pointsCommitted: 10,
  repoCount: 1,
  forecastLabel: 'f',
  forecastDetail: 'd',
  behind: behind,
  pointsDone: 5,
  estimatedTickets: 4,
  estimatedPoints: 9,
  unestimatedTickets: 0,
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
