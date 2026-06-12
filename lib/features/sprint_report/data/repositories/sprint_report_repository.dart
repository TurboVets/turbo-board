import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/data/queries/project_board.dart';
import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/sprint_report.dart';
import 'sprint_report_mapper.dart';

/// Data access for the Sprint Report (GitHub Projects v2 board rollup).
///
/// Reads the same `projectV2` board as the Lead Cockpit and rolls it up for one
/// sprint iteration (points come from the Complexity field; epics from each
/// issue's sub-issue summary). [sprintTitle] selects the iteration; null = the
/// current one. The burndown's daily history is a separate follow-up
/// (docs/plans) — see the mapper.
abstract class SprintReportRepository {
  Future<Result<SprintReport>> fetchReport({String? sprintTitle});
}

/// Reads a live GitHub Projects v2 board. Requires a token with `read:project`
/// + org access.
class GithubSprintReportRepository implements SprintReportRepository {
  GithubSprintReportRepository(
    this._client, {
    required this.org,
    required this.projectNumber,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GithubApiClient _client;
  final String org;
  final int projectNumber;
  final DateTime Function() _clock;

  static const int _pageSize = 100;
  static const int _maxPages = 10; // safety cap (≈1000 items)

  @override
  Future<Result<SprintReport>> fetchReport({String? sprintTitle}) async {
    try {
      final nodes = <Map<String, dynamic>>[];
      String? boardTitle;
      String? after;

      for (var page = 0; page < _maxPages; page++) {
        final data = await _client.graphql(projectBoardQuery, {
          'org': org,
          'number': projectNumber,
          'first': _pageSize,
          'after': after,
        });

        final project = data['organization']?['projectV2'] as Map<String, dynamic>?;
        if (project == null) return Result.failure('No access to project #$projectNumber in $org.', StackTrace.current);
        boardTitle ??= project['title'] as String?;

        final items = project['items'] as Map<String, dynamic>?;
        nodes.addAll(((items?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>());

        final pageInfo = items?['pageInfo'] as Map<String, dynamic>?;
        if ((pageInfo?['hasNextPage'] as bool?) != true) break;
        after = pageInfo?['endCursor'] as String?;
        if (after == null) break;
      }

      return Result.success(
        sprintReportFromProjectItems(boardTitle ?? 'Project board', nodes, now: _clock(), selectedSprint: sprintTitle),
      );
    } catch (e, stackTrace) {
      log('Failed to fetch sprint report', error: e, stackTrace: stackTrace);
      final message = e.toString().contains('read:project')
          ? 'Your GitHub token is missing the `read:project` scope. Add it at '
                'github.com/settings/tokens, then re-enter the token in Settings.'
          : 'Failed to load the sprint report';
      return Result.failure(message, stackTrace);
    }
  }
}

/// Mock seeded with the design's sample sprint, for tests / offline dev.
class MockSprintReportRepository implements SprintReportRepository {
  const MockSprintReportRepository();

  @override
  Future<Result<SprintReport>> fetchReport({String? sprintTitle}) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final index = _sample.sprintTitles.indexOf(sprintTitle ?? '');
      return Result.success(index >= 0 ? _sample.copyWith(sprintIndex: index) : _sample);
    } catch (e, stackTrace) {
      log('Failed to load the sprint report', error: e, stackTrace: stackTrace);
      return Result.failure('Failed to load the sprint report', stackTrace);
    }
  }
}

const _sample = SprintReport(
  sprintName: 'Sprint 24 · Mobile Space',
  dateRange: 'Jun 3 – Jun 17',
  daysRemaining: 6,
  totalTickets: 145,
  pointsCommitted: 168,
  repoCount: 3,
  forecastLabel: 'Trending ~2d behind',
  forecastDetail: '74 pts done vs 96 ideal at day 8 of 14 — gap of 22 pts ≈ 2.4 days at the current rate',
  behind: true,
  pointsDone: 74,
  status: [
    StatusSlice(kind: ReportStatusKind.done, label: 'Done', tickets: 58, points: 74),
    StatusSlice(kind: ReportStatusKind.inProgress, label: 'In progress', tickets: 31, points: 39),
    StatusSlice(kind: ReportStatusKind.inReview, label: 'In review', tickets: 17, points: 22),
    StatusSlice(kind: ReportStatusKind.notStarted, label: 'Not started', tickets: 27, points: 33),
  ],
  estimatedTickets: 133,
  estimatedPoints: 168,
  unestimatedTickets: 12,
  people: [
    AssigneePoints(handle: 'tromero-tv', done: 12, inProgress: 16, remaining: 10),
    AssigneePoints(handle: 'snguyen-tv', done: 14, inProgress: 8, remaining: 8),
    AssigneePoints(handle: 'apatel-tv', done: 16, inProgress: 6, remaining: 5),
    AssigneePoints(handle: 'mkim-tv', done: 21, inProgress: 5, remaining: 4),
    AssigneePoints(handle: 'lbarros-tv', done: 8, inProgress: 3, remaining: 1),
  ],
  peopleTickets: [
    AssigneeTickets(handle: 'tromero-tv', done: 12, inProgress: 6, remaining: 4),
    AssigneeTickets(handle: 'mkim-tv', done: 21, inProgress: 2, remaining: 2),
    AssigneeTickets(handle: 'apatel-tv', done: 16, inProgress: 4, remaining: 5),
    AssigneeTickets(handle: 'snguyen-tv', done: 14, inProgress: 3, remaining: 3),
    AssigneeTickets(handle: 'lbarros-tv', done: 8, inProgress: 1, remaining: 2),
  ],
  epics: [
    EpicProgress(title: 'Recruit application flow v2', subsDone: 8, subsTotal: 12, pointsDone: 34, pointsTotal: 52),
    EpicProgress(
      title: 'Shared component library migration',
      subsDone: 11,
      subsTotal: 14,
      pointsDone: 30,
      pointsTotal: 38,
    ),
    EpicProgress(title: 'Deeplink & cold-start hardening', subsDone: 3, subsTotal: 8, pointsDone: 10, pointsTotal: 26),
    EpicProgress(title: 'Offline-first submissions', subsDone: 1, subsTotal: 6, pointsDone: 6, pointsTotal: 24),
  ],
  burndown: Burndown(
    committedPoints: 168,
    totalDays: 14,
    todayDay: 8,
    snapshotsCaptured: 2,
    snapshotsTotal: 14,
    actualRemaining: [168, 168, 160, 148, 142, 128, 120, 104, 94],
  ),
  sprintTitles: ['Sprint 22', 'Sprint 23', 'Sprint 24', 'Sprint 25'],
  sprintIndex: 2,
);
