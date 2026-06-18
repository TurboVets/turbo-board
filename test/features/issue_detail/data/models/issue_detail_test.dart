// test/features/issue_detail/data/models/issue_detail_test.dart
//
// Test summary:
// - IssueDetail round-trips through JSON with project fields, sub-issues, linked PRs.
// - subDone/subTotal/hasSubIssues derive from subIssues.
// - isClosed reflects state.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

void main() {
  final detail = IssueDetail(
    repo: 'turbovets/web-portal',
    id: 'I_123',
    number: 155,
    title: 'Rotate API keys per request',
    url: 'https://github.com/turbovets/web-portal/issues/155',
    state: IssueState.open,
    author: 'apatel-tv',
    createdAt: DateTime.utc(2026, 6, 10),
    bodyMarkdown: 'Body',
    commentCount: 3,
    assignees: const ['apatel-tv'],
    labels: const [IssueLabel(name: 'bug', colorHex: 'e94a5f')],
    participants: const ['apatel-tv', 'snguyen-tv'],
    status: IssueStatus.inProgress,
    priority: IssuePriority.p1,
    sprint: 'Sprint 24',
    points: 5,
    milestone: 'v3',
    parent: const IssueRef(repo: 'turbovets/web-portal', number: 99, title: 'RSC migration epic'),
    subIssues: const [
      SubIssue(number: 156, title: 'Bind ctx', status: IssueStatus.done, done: true, assignee: 'snguyen-tv'),
      SubIssue(number: 157, title: 'KMS issue', status: IssueStatus.inProgress, done: false),
    ],
    linkedPrs: const [
      LinkedPr(
        owner: 'turbovets',
        repo: 'web-portal',
        number: 482,
        title: 'WIP',
        isDraft: true,
        ciState: PrCiState.failing,
        reviewState: PrReviewState.changesRequested,
        mergeState: PrLinkMergeState.open,
      ),
    ],
    timeline: [
      IssueTimelineEvent(author: 'apatel-tv', createdAt: DateTime.utc(2026, 6, 10), kind: IssueEventKind.opened),
    ],
    viewerCanUpdate: true,
    repoDefaultBranchOid: 'abc123',
  );

  test('IssueDetail round-trips through JSON', () {
    expect(IssueDetail.fromJson(detail.toJson()), detail);
  });

  test('sub-issue progress + state getters', () {
    expect(detail.subDone, 1);
    expect(detail.subTotal, 2);
    expect(detail.hasSubIssues, isTrue);
    expect(detail.isClosed, isFalse);
  });
}
