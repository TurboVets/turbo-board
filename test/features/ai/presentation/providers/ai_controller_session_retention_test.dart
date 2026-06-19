// test/features/ai/presentation/providers/ai_controller_session_retention_test.dart
//
// Test summary:
// - PrSummaryController retains its generated summary after the last listener
//   is removed (screen navigated away) — session retention via keepAlive.
// - TriageController retains its ranking after listeners drop.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/models/triage_item.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_core/core.dart';

import '../../data/repositories/ai_repository_test.mocks.dart';

PrDetail _detail() => const PrDetail(
  repo: 'org/app',
  number: 7,
  title: 'Fix bug',
  state: PrState.open,
  author: 'sam',
  baseRefName: 'main',
  headRefName: 'fix',
  bodyMarkdown: 'desc',
);

void main() {
  late MockAiRepository ai;
  ProviderContainer makeContainer() => ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);

  setUpAll(() {
    provideDummy<Result<List<String>>>(Result.success(const []));
    provideDummy<Result<List<TriageItem>>>(Result.success(const []));
  });
  setUp(() => ai = MockAiRepository());

  test('PrSummaryController keeps the summary after the last listener drops', () async {
    when(ai.summarize(any)).thenAnswer((_) async => Result.success(['a', 'b', 'c']));
    final c = makeContainer();
    addTearDown(c.dispose);
    const slug = 'org/app#7';

    // A screen mounts and subscribes.
    final sub = c.listen(prSummaryControllerProvider(slug), (_, _) {});
    await c.read(prSummaryControllerProvider(slug).notifier).generate(_detail());
    expect(c.read(prSummaryControllerProvider(slug))?.value, ['a', 'b', 'c']);

    // Screen navigates away — its subscription is gone. Auto-dispose would reset
    // the state to null here; keepAlive must retain it for the session.
    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(prSummaryControllerProvider(slug))?.value, ['a', 'b', 'c']);
  });

  test('TriageController keeps its ranking after the last listener drops', () async {
    when(ai.triage(any)).thenAnswer(
      (_) async => Result.success(const [
        TriageItem(
          rank: 1,
          repo: 'org/app',
          number: 7,
          title: 'Fix bug',
          reason: 'review first',
          category: TriageCategory.reviewFirst,
          updatedLabel: '3d',
        ),
      ]),
    );
    final c = makeContainer();
    addTearDown(c.dispose);

    final sub = c.listen(triageControllerProvider, (_, _) {});
    await c.read(triageControllerProvider.notifier).run(const <PrData>[]);
    expect(c.read(triageControllerProvider), isA<AsyncData<List<TriageItem>>>());

    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(triageControllerProvider), isA<AsyncData<List<TriageItem>>>());
  });
}
