// Test summary:
// - leadCockpitProvider returns cockpit data (sprint, team, stuck, brief) on success.
// - leadCockpitProvider surfaces an error when the repository fails.
// - MockLeadCockpitRepository returns the sample sprint with the expected shape.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/lead_cockpit_repository.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_core/core.dart';

class _FailingRepo implements LeadCockpitRepository {
  @override
  Future<Result<CockpitData>> fetchCockpit() async => Result.failure('boom', StackTrace.current);

  @override
  Future<Result<List<ProjectRef>>> listProjects() async => Result.failure('boom', StackTrace.current);
}

void main() {
  late ProviderContainer container;

  tearDown(() => container.dispose());

  group('leadCockpitProvider', () {
    test('should return cockpit data when the repository succeeds', () async {
      container = ProviderContainer(
        overrides: [leadCockpitRepositoryProvider.overrideWithValue(const MockLeadCockpitRepository())],
      );

      final data = await container.read(leadCockpitProvider.future);

      expect(data.sprint.totalIssues, 145);
      expect(data.team, isNotEmpty);
      expect(data.stuck, isNotEmpty);
    });

    test('should surface an error when the repository fails', () async {
      container = ProviderContainer(overrides: [leadCockpitRepositoryProvider.overrideWithValue(_FailingRepo())]);
      // Hold a subscription so the auto-dispose provider stays mounted after the await.
      container.listen(leadCockpitProvider, (_, _) {}, fireImmediately: true);

      await Future<void>.delayed(Duration.zero);
      final state = container.read(leadCockpitProvider);

      expect(state.hasError, isTrue);
      expect(state.error, isA<Exception>());
    });
  });

  group('MockLeadCockpitRepository', () {
    test('should flag the overloaded member and order stuck items by severity', () async {
      final result = await const MockLeadCockpitRepository().fetchCockpit();

      final data = result.when(success: (d) => d, failure: (_, _) => null);
      expect(data, isNotNull);

      final overloaded = data!.team.where((m) => m.isOverloaded).map((m) => m.handle);
      expect(overloaded, contains('tromero-tv'));

      // The first stuck item is the critical P0 deeplink issue.
      expect(data.stuck.first.priority, IssuePriority.p0);
      expect(data.stuck.first.critical, isTrue);
    });
  });
}
