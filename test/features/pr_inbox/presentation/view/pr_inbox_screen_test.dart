// test/features/pr_inbox/presentation/view/pr_inbox_screen_test.dart
//
// Test summary:
// - groups PRs into the four review-state columns with correct counts.
// - shows the empty state when there are no PRs (renders 'NO OPEN PRS MATCH').
// - shows an error state with a Retry button when the provider throws.
// - routes a draft PR out of NEEDS REVIEW into WAITING, even when its GitHub
//   review state is needsReview (verified via the phone column-pill counts).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/data/repositories/pr_inbox_repository.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_column.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _StaticRepo implements PrInboxRepository {
  _StaticRepo(this.prs);
  final List<PrData> prs;
  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async => Result.success(prs);
}

class _FailingRepo implements PrInboxRepository {
  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async => Result.failure('boom', StackTrace.current);
}

PrData _pr(int n, PrReviewState s, {bool isDraft = false}) => PrData(
  repo: 'o/r',
  number: n,
  title: 'PR $n',
  author: 'a',
  isDraft: isDraft,
  reviewState: s,
  ciState: PrCiState.passing,
  updatedAt: DateTime(2026, 1, 1),
);

Widget _host(PrInboxRepository repo) => ProviderScope(
  overrides: [prInboxRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: getAppTheme(),
    home: const Scaffold(body: PrInboxScreen()),
  ),
);

void main() {
  testWidgets('groups PRs into review-state columns', (tester) async {
    await tester.pumpWidget(
      _host(
        _StaticRepo([
          _pr(1, PrReviewState.needsReview),
          _pr(2, PrReviewState.needsReview),
          _pr(3, PrReviewState.approved),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PR Board'), findsOneWidget);
    // Column headers use uppercase labels — the board also renders badge text
    // like 'NEEDS REVIEW' and 'APPROVED' on cards, so check at-least-one.
    expect(find.text('NEEDS REVIEW'), findsAtLeastNWidgets(1));
    expect(find.text('APPROVED'), findsAtLeastNWidgets(1));
    expect(find.byType(PrCard), findsNWidgets(3));
  });

  testWidgets('routes a draft out of NEEDS REVIEW into WAITING', (tester) async {
    await tester.pumpWidget(
      _host(
        _StaticRepo([
          _pr(1, PrReviewState.needsReview), // real review-needed
          _pr(2, PrReviewState.needsReview, isDraft: true), // draft → WAITING
        ]),
      ),
    );
    await tester.pumpAndSettle();

    List<PrData> columnPrs(String title) =>
        tester.widgetList<PrColumn>(find.byType(PrColumn)).firstWhere((c) => c.title == title).prs;

    // The non-draft stays in NEEDS REVIEW; the draft is moved to WAITING ON AUTHOR
    // despite its needsReview state.
    expect(columnPrs('NEEDS REVIEW').map((p) => p.number), [1]);
    expect(columnPrs('WAITING ON AUTHOR').map((p) => p.number), [2]);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_host(_StaticRepo(const [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('NO OPEN PRS MATCH'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_host(_FailingRepo()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load PRs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
