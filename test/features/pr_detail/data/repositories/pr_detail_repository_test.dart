// test/features/pr_detail/data/repositories/pr_detail_repository_test.dart
//
// Test summary:
// - maps a full pullRequest payload (state/draft/author/base/head/body).
// - checks map across CheckRun (success/failure/in-progress) and StatusContext.
// - reviewers: a pending request is superseded by a submitted review for the same login.
// - timeline merges comments + non-empty reviews, sorted ascending by time.
// - pullRequest: null -> failure; GraphQL error -> failure.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_check.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_timeline_event.dart';
import 'package:turbo_board/features/pr_detail/data/repositories/pr_detail_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_core/core.dart';

import 'pr_detail_repository_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late GithubPrDetailRepository repo;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    repo = GithubPrDetailRepository(GithubApiClient(dio: dio));
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> data) => Response(
    requestOptions: RequestOptions(path: '/graphql'),
    statusCode: 200,
    data: {'data': data},
  );

  void stub(Map<String, dynamic> data) =>
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer((_) async => ok(data));

  test('maps a full pullRequest payload', () async {
    stub({
      'repository': {
        'pullRequest': {
          'number': 42,
          'title': 'Add thing',
          'body': '# Heading',
          'isDraft': false,
          'state': 'OPEN',
          'baseRefName': 'main',
          'headRefName': 'feat',
          'author': {'login': 'sang'},
          'reviewDecision': 'CHANGES_REQUESTED',
          'reviewRequests': {
            'nodes': [
              {
                'requestedReviewer': {'__typename': 'User', 'login': 'mira'},
              },
            ],
          },
          'latestReviews': {
            'nodes': [
              {
                'author': {'login': 'leo'},
                'state': 'APPROVED',
                'body': 'LGTM',
                'submittedAt': '2026-06-10T10:00:00Z',
              },
              {
                'author': {'login': 'mira'},
                'state': 'CHANGES_REQUESTED',
                'body': '',
                'submittedAt': '2026-06-10T11:00:00Z',
              },
            ],
          },
          'comments': {
            'nodes': [
              {
                'author': {'login': 'tom'},
                'body': 'first',
                'createdAt': '2026-06-10T09:00:00Z',
              },
            ],
          },
          'commits': {
            'nodes': [
              {
                'commit': {
                  'abbreviatedOid': 'a1b2c3d',
                  'messageHeadline': 'Fix it',
                  'committedDate': '2026-06-10T08:00:00Z',
                  'statusCheckRollup': {
                    'state': 'FAILURE',
                    'contexts': {
                      'nodes': [
                        {'__typename': 'CheckRun', 'name': 'build', 'status': 'COMPLETED', 'conclusion': 'SUCCESS'},
                        {'__typename': 'CheckRun', 'name': 'test', 'status': 'COMPLETED', 'conclusion': 'FAILURE'},
                        {'__typename': 'CheckRun', 'name': 'lint', 'status': 'IN_PROGRESS', 'conclusion': null},
                        {'__typename': 'StatusContext', 'context': 'ci/legacy', 'state': 'SUCCESS'},
                      ],
                    },
                  },
                },
              },
            ],
          },
        },
      },
    });

    final result = await repo.fetchDetail('o', 'r', 42);
    final d = (result as ResultSuccess<PrDetail>).data;

    expect(d.repo, 'o/r');
    expect(d.number, 42);
    expect(d.state, PrState.open);
    expect(d.author, 'sang');
    expect(d.baseRefName, 'main');
    expect(d.bodyMarkdown, '# Heading');
    expect(d.lastCommit?.abbreviatedOid, 'a1b2c3d');

    // checks
    expect(d.checks.map((c) => c.state), [
      PrCheckState.success,
      PrCheckState.failure,
      PrCheckState.pending,
      PrCheckState.success,
    ]);

    // reviewers: leo approved, mira superseded from pending -> changesRequested
    final byLogin = {for (final r in d.reviewers) r.login: r.state};
    expect(byLogin['leo'], PrReviewerState.approved);
    expect(byLogin['mira'], PrReviewerState.changesRequested);

    // timeline: comment(tom 09:00) + review(leo 10:00, body LGTM); mira review empty body skipped
    expect(d.timeline.map((e) => e.author), ['tom', 'leo']);
    expect(d.timeline.last.kind, PrEventKind.review);
    expect(d.timeline.last.reviewState, PrReviewerState.approved);
  });

  test('null pullRequest yields failure', () async {
    stub({
      'repository': {'pullRequest': null},
    });
    final result = await repo.fetchDetail('o', 'r', 1);
    expect(result, isA<ResultFailure<PrDetail>>());
    expect((result as ResultFailure<PrDetail>).message, contains('not found'));
  });

  test('GraphQL error yields failure', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/graphql'),
        statusCode: 200,
        data: {
          'errors': [
            {'message': 'Bad credentials'},
          ],
        },
      ),
    );
    final result = await repo.fetchDetail('o', 'r', 1);
    expect(result, isA<ResultFailure<PrDetail>>());
  });
}
