import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../models/pr_data.dart';

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
