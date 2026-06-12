// Test summary:
// - renders the big total and a tile per category with its count.
// - shows "ALL CLEAR ✓" for an empty category.
// - tapping a tile expands it in place (reveals the repo #number subline) and
//   the footer swaps to "COLLAPSE ▴"; tapping again collapses.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/needs_attention/presentation/providers/needs_attention_provider.dart';
import 'package:turbo_board/features/needs_attention/presentation/view/needs_attention_screen.dart';
import 'package:turbo_board/features/needs_attention/presentation/helpers/triage.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

PrData _pr(String repo, int n, {PrReviewState review = PrReviewState.needsReview, PrCiState ci = PrCiState.passing}) {
  return PrData(
    repo: repo,
    number: n,
    title: 'PR title $n',
    author: 'octocat',
    reviewState: review,
    ciState: ci,
    updatedAt: DateTime(2026, 6, 1),
  );
}

Future<void> _pump(WidgetTester tester, Map<NeedsAttentionCategory, List<PrData>> groups) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [needsAttentionProvider.overrideWith((ref) async => groups)],
      child: MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(body: SizedBox(width: 1280, height: 900, child: NeedsAttentionScreen())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<NeedsAttentionCategory, List<PrData>> _empty() => {for (final c in NeedsAttentionCategory.values) c: <PrData>[]};

void main() {
  testWidgets('renders total and per-category tiles with counts', (tester) async {
    final groups = _empty()
      ..[NeedsAttentionCategory.needsMyReview] = [_pr('org/a', 1), _pr('org/b', 2)]
      ..[NeedsAttentionCategory.failingChecks] = [_pr('org/a', 1, ci: PrCiState.failing)];

    await _pump(tester, groups);

    // 3 rows across, deduped to 2 distinct PRs (org/a#1 appears in two tiles).
    expect(find.text('2'), findsWidgets); // total + the needsMyReview count
    expect(find.text('NEEDS MY REVIEW'), findsOneWidget);
    expect(find.text('FAILING CHECKS'), findsOneWidget);
    expect(find.text('PRS NEED ATTENTION'), findsOneWidget);
  });

  testWidgets('shows ALL CLEAR for an empty category', (tester) async {
    final groups = _empty()..[NeedsAttentionCategory.draft] = [_pr('org/a', 9, review: PrReviewState.waitingOnAuthor)];
    await _pump(tester, groups);
    expect(find.text('ALL CLEAR ✓'), findsWidgets);
  });

  testWidgets('tapping a tile expands it in place then collapses', (tester) async {
    final groups = _empty()..[NeedsAttentionCategory.needsMyReview] = [_pr('org/a', 1)];
    await _pump(tester, groups);

    // Collapsed: footer CTA shows "VIEW ALL …", no repo#number subline yet.
    expect(find.textContaining('VIEW ALL'), findsOneWidget);
    expect(find.text('org/a #1'), findsNothing);

    await tester.tap(find.text('NEEDS MY REVIEW'));
    await tester.pumpAndSettle();

    // Expanded: full row reveals the repo #number subline; footer collapses.
    expect(find.text('org/a #1'), findsOneWidget);
    expect(find.text('COLLAPSE ▴'), findsOneWidget);

    await tester.tap(find.text('NEEDS MY REVIEW'));
    await tester.pumpAndSettle();
    expect(find.text('org/a #1'), findsNothing);
  });
}
