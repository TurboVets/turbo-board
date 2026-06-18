// Test summary:
// - MockPrInboxRepository returns a successful Result with a non-empty PR list
// - Every sample PR has a valid slug ("owner/name#number")
// - GithubPrInboxRepository returns empty list (no network call) when no repos watched
// - GithubPrInboxRepository maps a PullRequest node across review and CI states
// - null reviewDecision maps to waitingOnAuthor; missing rollup maps to pending
// - CONFLICTING mergeable maps to conflicting; missing mergeable maps to unknown
// - GithubPrInboxRepository returns failure when the GraphQL call throws
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/data/repositories/pr_inbox_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_core/core.dart';

import 'pr_inbox_repository_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('MockPrInboxRepository', () {
    test('should return success with a non-empty list when fetching open PRs', () async {
      // Arrange
      const repo = MockPrInboxRepository();

      // Act
      final result = await repo.fetchOpenPrs();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.value, isNotEmpty);
    });

    test('should expose a valid slug for every PR', () async {
      // Arrange
      const repo = MockPrInboxRepository();

      // Act
      final result = await repo.fetchOpenPrs();

      // Assert
      for (final pr in result.value) {
        expect(pr.slug, matches(RegExp(r'^[\w-]+/[\w.-]+#\d+$')));
      }
    });
  });

  group('GithubPrInboxRepository', () {
    late MockDio dio;

    setUp(() {
      dio = MockDio();
      when(dio.options).thenReturn(BaseOptions());
    });

    Response<Map<String, dynamic>> ok(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: '/graphql'),
      statusCode: 200,
      data: {'data': data},
    );

    test('returns empty list when no repos are watched (no network call)', () async {
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), const []);
      final result = await repo.fetchOpenPrs();
      expect(result, isA<ResultSuccess<List<PrData>>>());
      expect((result as ResultSuccess<List<PrData>>).data, isEmpty);
      verifyNever(dio.post<Map<String, dynamic>>(any, data: anyNamed('data')));
    });

    test('maps a PullRequest node across review and CI states', () async {
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
        (_) async => ok({
          'search': {
            'nodes': [
              {
                'number': 42,
                'title': 'Add thing',
                'isDraft': false,
                'updatedAt': '2026-06-10T12:00:00Z',
                'url': 'https://github.com/o/r/pull/42',
                'author': {'login': 'sang'},
                'repository': {'nameWithOwner': 'o/r'},
                'reviewDecision': 'CHANGES_REQUESTED',
                'mergeable': 'CONFLICTING',
                'comments': {'totalCount': 4},
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
              {}, // non-PR node -> skipped
            ],
          },
        }),
      );

      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final result = await repo.fetchOpenPrs();

      final prs = (result as ResultSuccess<List<PrData>>).data;
      expect(prs, hasLength(1));
      expect(prs.single.number, 42);
      expect(prs.single.repo, 'o/r');
      expect(prs.single.author, 'sang');
      expect(prs.single.reviewState, PrReviewState.changesRequested);
      expect(prs.single.ciState, PrCiState.failing);
      expect(prs.single.mergeState, PrMergeState.conflicting);
      expect(prs.single.commentsCount, 4);
    });

    test('null reviewDecision maps to waitingOnAuthor and missing rollup to pending', () async {
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
        (_) async => ok({
          'search': {
            'nodes': [
              {
                'number': 1,
                'title': 't',
                'updatedAt': '2026-06-10T12:00:00Z',
                'author': {'login': 'a'},
                'repository': {'nameWithOwner': 'o/r'},
                'reviewDecision': null,
                'comments': {'totalCount': 0},
                'commits': {'nodes': []},
              },
            ],
          },
        }),
      );
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final prs = (await repo.fetchOpenPrs() as ResultSuccess<List<PrData>>).data;
      expect(prs.single.reviewState, PrReviewState.waitingOnAuthor);
      expect(prs.single.ciState, PrCiState.pending);
      expect(prs.single.mergeState, PrMergeState.unknown);
    });

    test('returns failure when the GraphQL call throws', () async {
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
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final result = await repo.fetchOpenPrs();
      expect(result, isA<ResultFailure<List<PrData>>>());
    });
  });
}
