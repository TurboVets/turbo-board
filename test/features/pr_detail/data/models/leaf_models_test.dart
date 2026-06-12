// test/features/pr_detail/data/models/leaf_models_test.dart
//
// Test summary:
// - each leaf model constructs and exposes its fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_check.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_commit.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_timeline_event.dart';

void main() {
  test('PrCheck holds name/state/summary', () {
    const c = PrCheck(name: 'build', state: PrCheckState.success, summary: 'ok');
    expect(c.name, 'build');
    expect(c.state, PrCheckState.success);
    expect(c.summary, 'ok');
  });

  test('PrReviewer holds login/state', () {
    const r = PrReviewer(login: 'sang', state: PrReviewerState.changesRequested);
    expect(r.login, 'sang');
    expect(r.state, PrReviewerState.changesRequested);
  });

  test('PrCommit holds oid/headline/date', () {
    final c = PrCommit(abbreviatedOid: 'a1b2c3d', messageHeadline: 'Fix', committedDate: DateTime(2026, 6, 10));
    expect(c.abbreviatedOid, 'a1b2c3d');
    expect(c.messageHeadline, 'Fix');
    expect(c.committedDate, DateTime(2026, 6, 10));
  });

  test('PrTimelineEvent holds fields incl optional reviewState', () {
    final e = PrTimelineEvent(
      author: 'tom',
      bodyMarkdown: 'hi',
      createdAt: DateTime(2026, 6, 10),
      kind: PrEventKind.reviewComment,
      reviewState: PrReviewerState.approved,
    );
    expect(e.kind, PrEventKind.reviewComment);
    expect(e.reviewState, PrReviewerState.approved);
  });
}
