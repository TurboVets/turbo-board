// test/features/projects_board/presentation/providers/projects_board_provider_test.dart
//
// Test summary:
// - projectsBoardProvider yields the repo's board on success.
// - projectsBoardProvider throws (AsyncError) on repo failure.
// - BoardInsightsController: null -> loading -> data on generate; error path; clear() resets to null.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';

import 'projects_board_provider_test.mocks.dart';

class _FailRepo implements ProjectsBoardRepository {
  @override
  Future<Result<ProjectBoardData>> fetchBoard() async => Result.failure('boom', StackTrace.current);
}

@GenerateMocks([AiRepository])
void main() {
  setUpAll(() => provideDummy<Result<Map<IssueStatus, String>>>(Result.success({})));

  test('board provider yields the repo board', () async {
    final c = ProviderContainer(
      overrides: [projectsBoardRepositoryProvider.overrideWithValue(const MockProjectsBoardRepository())],
    );
    addTearDown(c.dispose);
    final data = await c.read(projectsBoardProvider.future);
    expect(data.columns, isNotEmpty);
  });

  test('board provider surfaces failure as error', () async {
    final c = ProviderContainer(overrides: [projectsBoardRepositoryProvider.overrideWithValue(_FailRepo())]);
    addTearDown(c.dispose);
    // Hold a subscription so the auto-dispose provider stays mounted after the await.
    c.listen(projectsBoardProvider, (_, _) {}, fireImmediately: true);

    await Future<void>.delayed(Duration.zero);
    final state = c.read(projectsBoardProvider);

    expect(state.hasError, isTrue);
    expect(state.error, isA<Exception>());
  });

  test('insights controller: generate then clear', () async {
    final ai = MockAiRepository();
    when(ai.boardInsights(any)).thenAnswer((_) async => Result.success({IssueStatus.inProgress: 'all good'}));
    final c = ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);
    addTearDown(c.dispose);

    expect(c.read(boardInsightsControllerProvider), isNull);
    await c.read(boardInsightsControllerProvider.notifier).generate(const ProjectBoardData(title: 'B'));
    expect(c.read(boardInsightsControllerProvider)!.value, {IssueStatus.inProgress: 'all good'});
    c.read(boardInsightsControllerProvider.notifier).clear();
    expect(c.read(boardInsightsControllerProvider), isNull);
  });

  test('insights controller: error on generate failure', () async {
    final ai = MockAiRepository();
    when(ai.boardInsights(any)).thenAnswer((_) async => Result.failure('nope', StackTrace.current));
    final c = ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);
    addTearDown(c.dispose);

    expect(c.read(boardInsightsControllerProvider), isNull);
    await c.read(boardInsightsControllerProvider.notifier).generate(const ProjectBoardData(title: 'B'));
    expect(c.read(boardInsightsControllerProvider)!.hasError, isTrue);
  });
}
