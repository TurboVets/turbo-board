// test/features/issue_detail/data/repositories/issue_detail_repository_test.dart
//
// Test summary:
// - issueDetailFromNode parses identity, body, labels, assignees, milestone, viewerCanUpdate.
// - parses ProjectV2 fields (Status/Priority/Sprint/Complexity) by field name.
// - parses sub-issues (state -> IssueStatus, done when CLOSED) and the parent epic.
// - parses linked PRs: CI rollup -> PrCiState, reviewDecision -> PrReviewState, merge/draft state.
// - builds a chronological timeline (opened first, then comments/events).
// - MockIssueDetailRepository returns sampleIssueDetail; mutations return success.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_core/core.dart';

Map<String, dynamic> repoNode() => {
  'defaultBranchRef': {
    'target': {'oid': 'base-oid'},
  },
  'issue': {
    'id': 'I_1',
    'number': 155,
    'title': 'Rotate keys',
    'url': 'https://github.com/o/r/issues/155',
    'state': 'OPEN',
    'body': 'Body text',
    'createdAt': '2026-06-10T00:00:00Z',
    'viewerCanUpdate': true,
    'author': {'login': 'apatel-tv'},
    'labels': {
      'nodes': [
        {'name': 'bug', 'color': 'e94a5f'},
      ],
    },
    'assignees': {
      'nodes': [
        {'login': 'apatel-tv'},
      ],
    },
    'participants': {
      'nodes': [
        {'login': 'apatel-tv'},
        {'login': 'snguyen-tv'},
      ],
    },
    'milestone': {'title': 'v3'},
    'comments': {
      'totalCount': 2,
      'nodes': [
        {
          'author': {'login': 'snguyen-tv'},
          'body': 'On it',
          'createdAt': '2026-06-11T00:00:00Z',
        },
      ],
    },
    'parent': {
      'number': 99,
      'title': 'RSC epic',
      'state': 'OPEN',
      'repository': {'nameWithOwner': 'o/r'},
    },
    'subIssuesSummary': {'total': 2, 'completed': 1},
    'subIssues': {
      'nodes': [
        {
          'number': 156,
          'title': 'Bind ctx',
          'state': 'CLOSED',
          'assignees': {
            'nodes': [
              {'login': 'snguyen-tv'},
            ],
          },
        },
        {
          'number': 157,
          'title': 'KMS',
          'state': 'OPEN',
          'assignees': {'nodes': []},
        },
      ],
    },
    'closedByPullRequestsReferences': {
      'nodes': [
        {
          'number': 482,
          'title': 'WIP',
          'isDraft': true,
          'state': 'OPEN',
          'url': 'u',
          'reviewDecision': 'CHANGES_REQUESTED',
          'repository': {
            'name': 'r',
            'owner': {'login': 'o'},
          },
          'commits': {
            'nodes': [
              {
                'commit': {
                  'statusCheckRollup': {'state': 'FAILURE'},
                },
              },
            ],
          },
        },
      ],
    },
    'projectItems': {
      'nodes': [
        {
          'id': 'PVTI_1',
          'project': {
            'id': 'PVT_1',
            'field': {
              'id': 'PVTF_status',
              'options': [
                {'id': 'opt_ip', 'name': 'In Progress'},
                {'id': 'opt_done', 'name': 'Done'},
              ],
            },
          },
          'fieldValues': {
            'nodes': [
              {
                '__typename': 'ProjectV2ItemFieldSingleSelectValue',
                'name': 'In Progress',
                'field': {'name': 'Status'},
              },
              {
                '__typename': 'ProjectV2ItemFieldSingleSelectValue',
                'name': 'P1',
                'field': {'name': 'Priority'},
              },
              {
                '__typename': 'ProjectV2ItemFieldNumberValue',
                'number': 5,
                'field': {'name': 'Complexity'},
              },
              {
                '__typename': 'ProjectV2ItemFieldIterationValue',
                'title': 'Sprint 24',
                'field': {'name': 'Sprint'},
              },
            ],
          },
        },
      ],
    },
    'timelineItems': {
      'nodes': [
        {
          '__typename': 'IssueComment',
          'createdAt': '2026-06-11T00:00:00Z',
          'author': {'login': 'snguyen-tv'},
          'body': 'On it',
        },
        {
          '__typename': 'ClosedEvent',
          'createdAt': '2026-06-12T00:00:00Z',
          'actor': {'login': 'apatel-tv'},
        },
      ],
    },
  },
};

void main() {
  test('parses the issue node', () {
    final d = issueDetailFromNode('o', 'r', repoNode());
    expect(d.number, 155);
    expect(d.state, IssueState.open);
    expect(d.viewerCanUpdate, isTrue);
    expect(d.repoDefaultBranchOid, 'base-oid');
    expect(d.labels.single.name, 'bug');
    expect(d.milestone, 'v3');
    expect(d.status, IssueStatus.inProgress);
    expect(d.priority, IssuePriority.p1);
    expect(d.points, 5);
    expect(d.sprint, 'Sprint 24');
    expect(d.parent?.number, 99);
    expect(d.subDone, 1);
    expect(d.subIssues.first.done, isTrue);
    final pr = d.linkedPrs.single;
    expect(pr.ciState, PrCiState.failing);
    expect(pr.reviewState, PrReviewState.changesRequested);
    expect(pr.mergeState, PrLinkMergeState.draft);
    expect(d.timeline.first.kind, IssueEventKind.opened); // synthesized from createdAt
    // ProjectV2 status-update handles.
    expect(d.projectId, 'PVT_1');
    expect(d.projectItemId, 'PVTI_1');
    expect(d.statusFieldId, 'PVTF_status');
    expect(d.statusOptions.map((o) => o.id), ['opt_ip', 'opt_done']);
    expect(d.statusOptions.first.status, IssueStatus.inProgress);
    expect(d.canUpdateStatus, isTrue);
  });

  test('mock repo returns the sample and accepts mutations', () async {
    const repo = MockIssueDetailRepository();
    final res = await repo.fetchDetail('o', 'r', 1);
    final detail = switch (res) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    };
    expect(detail.hasSubIssues, isTrue);
    expect(switch (await repo.addComment('id', 'hi')) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    }, isTrue);
    expect(switch (await repo.closeIssue('id')) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    }, isTrue);
    expect(switch (await repo.createBranch('id', 'oid', '155-rotate')) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    }, '155-rotate');
    expect(switch (await repo.updateStatus('p', 'i', 'f', 'opt')) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    }, isTrue);
  });
}
