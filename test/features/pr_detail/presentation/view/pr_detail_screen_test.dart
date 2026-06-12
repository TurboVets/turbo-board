// test/features/pr_detail/presentation/view/pr_detail_screen_test.dart
//
// Test summary:
// - renders header (title), checks, reviewers, timeline from a mock repo.
// - shows error state with Retry when the repo fails.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_check.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_timeline_event.dart';
import 'package:turbo_board/features/pr_detail/data/repositories/pr_detail_repository.dart';
import 'package:turbo_board/features/pr_detail/presentation/providers/pr_detail_provider.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/pr_detail_screen.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _Repo implements PrDetailRepository {
  _Repo({this.fail = false});
  final bool fail;
  @override
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number) async => fail
      ? Result.failure('boom', StackTrace.current)
      : Result.success(
          PrDetail(
            repo: '$owner/$name',
            number: number,
            title: 'Add rate limiting',
            state: PrState.open,
            author: 'sang',
            baseRefName: 'main',
            headRefName: 'feat',
            checks: const [PrCheck(name: 'build', state: PrCheckState.success)],
            reviewers: const [PrReviewer(login: 'mira', state: PrReviewerState.pending)],
            timeline: [
              PrTimelineEvent(
                author: 'tom',
                bodyMarkdown: 'hello',
                createdAt: DateTime(2026, 6, 10),
                kind: PrEventKind.comment,
              ),
            ],
          ),
        );
}

Widget _host(PrDetailRepository repo) => ProviderScope(
  overrides: [prDetailRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: getAppTheme(),
    home: const Scaffold(
      body: PrDetailScreen(owner: 'o', repo: 'r', number: 42),
    ),
  ),
);

void main() {
  testWidgets('renders detail sections', (tester) async {
    await tester.pumpWidget(_host(_Repo()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add rate limiting'), findsOneWidget);
    expect(find.text('build'), findsOneWidget);
    expect(find.text('mira'), findsOneWidget);
    expect(find.text('tom'), findsOneWidget);
  });

  testWidgets('shows error + retry', (tester) async {
    await tester.pumpWidget(_host(_Repo(fail: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load PR'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
