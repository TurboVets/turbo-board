// test/features/pr_inbox/data/models/pr_data_test.dart
//
// Test summary:
// - commentsCount defaults to 0 when omitted.
// - commentsCount round-trips through the constructor.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

void main() {
  PrData make({int? comments}) => PrData(
    repo: 'o/r',
    number: 1,
    title: 't',
    author: 'a',
    reviewState: PrReviewState.needsReview,
    ciState: PrCiState.passing,
    updatedAt: DateTime(2026, 1, 1),
    commentsCount: comments ?? 0,
  );

  test('commentsCount defaults to 0', () {
    final pr = PrData(
      repo: 'o/r',
      number: 1,
      title: 't',
      author: 'a',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(pr.commentsCount, 0);
  });

  test('commentsCount is retained', () {
    expect(make(comments: 7).commentsCount, 7);
  });
}
