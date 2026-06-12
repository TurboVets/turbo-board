import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/pr_data.dart';
import '../queries/search_open_prs.dart';

/// Data access for the PR Inbox.
///
/// v0 ships a mock implementation so the UI can be built and tested.
/// The GitHub integration (REST/GraphQL via turbo_core's DioClient /
/// GraphQLClient) replaces [MockPrInboxRepository] behind the same interface.
abstract class PrInboxRepository {
  Future<Result<List<PrData>>> fetchOpenPrs();
}

class MockPrInboxRepository implements PrInboxRepository {
  const MockPrInboxRepository();

  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async {
    try {
      // Simulated network latency.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return Result.success(_samplePrs);
    } catch (e, stackTrace) {
      log('Failed to fetch open PRs', error: e, stackTrace: stackTrace);
      return Result.failure('Failed to fetch open PRs', stackTrace);
    }
  }
}

final _samplePrs = <PrData>[
  PrData(
    repo: 'TurboVets/platform',
    number: 412,
    title: 'Add rate limiting middleware to public endpoints',
    author: 'sang',
    reviewState: PrReviewState.needsReview,
    ciState: PrCiState.passing,
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  PrData(
    repo: 'TurboVets/mobile_recruit',
    number: 893,
    title: 'REC-1201: Progress timeline v2 polish',
    author: 'alex',
    reviewState: PrReviewState.changesRequested,
    ciState: PrCiState.failing,
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  PrData(
    repo: 'TurboVets/mobile-shared-components',
    number: 67,
    title: 'feat(turbo_ui): tether table component',
    author: 'jamie',
    isDraft: true,
    reviewState: PrReviewState.waitingOnAuthor,
    ciState: PrCiState.pending,
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

/// Fetches open PRs across the watched repos via GitHub's GraphQL search.
class GithubPrInboxRepository implements PrInboxRepository {
  GithubPrInboxRepository(this._client, this._watchedRepos);

  final GithubApiClient _client;
  final List<String> _watchedRepos;

  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async {
    if (_watchedRepos.isEmpty) return Result.success(const []);
    try {
      final data = await _client.graphql(searchOpenPrsQuery, {'q': buildSearchQueryString(_watchedRepos), 'first': 50});
      final nodes = (data['search']?['nodes'] as List<dynamic>?) ?? const [];
      final prs = nodes.whereType<Map<String, dynamic>>().map(prFromSearchNode).whereType<PrData>().toList();
      return Result.success(prs);
    } catch (e, stackTrace) {
      log('Failed to fetch open PRs', error: e, stackTrace: stackTrace);
      return Result.failure('Could not load pull requests.', stackTrace);
    }
  }
}

/// Maps one GraphQL `search.nodes` entry to a [PrData]. Returns null for empty
/// nodes (non-PullRequest results have no `number` under the inline fragment).
PrData? prFromSearchNode(Map<String, dynamic> node) {
  final number = node['number'];
  if (number is! int) return null;

  final rollupState =
      ((node['commits']?['nodes'] as List<dynamic>?)?.firstOrNull
              as Map<String, dynamic>?)?['commit']?['statusCheckRollup']?['state']
          as String?;

  return PrData(
    repo: (node['repository']?['nameWithOwner'] as String?) ?? '',
    number: number,
    title: (node['title'] as String?) ?? '',
    author: (node['author']?['login'] as String?) ?? 'unknown',
    isDraft: (node['isDraft'] as bool?) ?? false,
    reviewState: _reviewStateFrom(node['reviewDecision'] as String?),
    ciState: _ciStateFrom(rollupState),
    updatedAt: DateTime.tryParse((node['updatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    htmlUrl: node['url'] as String?,
    commentsCount: (node['comments']?['totalCount'] as int?) ?? 0,
  );
}

PrReviewState _reviewStateFrom(String? decision) => switch (decision) {
  'REVIEW_REQUIRED' => PrReviewState.needsReview,
  'CHANGES_REQUESTED' => PrReviewState.changesRequested,
  'APPROVED' => PrReviewState.approved,
  _ => PrReviewState.waitingOnAuthor,
};

PrCiState _ciStateFrom(String? rollup) => switch (rollup) {
  'SUCCESS' => PrCiState.passing,
  'FAILURE' || 'ERROR' => PrCiState.failing,
  _ => PrCiState.pending,
};
