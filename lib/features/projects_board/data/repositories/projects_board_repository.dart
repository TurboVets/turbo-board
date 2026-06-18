import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/data/queries/project_board.dart';
import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/board_data.dart';
import 'board_mapper.dart';

/// Data access for the Projects Board (read-only ProjectV2 board).
abstract class ProjectsBoardRepository {
  Future<Result<ProjectBoardData>> fetchBoard();
}

/// Reads a live org ProjectV2 board and maps it to [ProjectBoardData].
/// Mirrors GithubLeadCockpitRepository's pagination loop.
class GithubProjectsBoardRepository implements ProjectsBoardRepository {
  GithubProjectsBoardRepository(
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
  static const int _maxPages = 10;

  @override
  Future<Result<ProjectBoardData>> fetchBoard() async {
    try {
      final nodes = <Map<String, dynamic>>[];
      String? boardTitle;
      var iterations = const <Map<String, dynamic>>[];
      String? currentSprint;
      String? after;
      for (var page = 0; page < _maxPages; page++) {
        final data = await _client.graphql(projectBoardQuery, {
          'org': org,
          'number': projectNumber,
          'first': _pageSize,
          'after': after,
        });
        final project = data['organization']?['projectV2'] as Map<String, dynamic>?;
        if (project == null) {
          return Result.failure('No access to project #$projectNumber in $org.', StackTrace.current);
        }
        boardTitle ??= project['title'] as String?;
        // The field config repeats on every page; capture it once from page 1.
        if (page == 0) {
          final cfg = _iterationConfig(project);
          iterations = cfg.all;
          currentSprint = cfg.currentTitle;
        }
        final items = project['items'] as Map<String, dynamic>?;
        nodes.addAll(((items?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>());
        final pageInfo = items?['pageInfo'] as Map<String, dynamic>?;
        if ((pageInfo?['hasNextPage'] as bool?) != true) break;
        after = pageInfo?['endCursor'] as String?;
        if (after == null) break;
      }
      return Result.success(
        boardFromProjectItems(
          boardTitle ?? 'Project board',
          nodes,
          now: _clock(),
          iterations: iterations,
          currentSprint: currentSprint,
        ),
      );
    } catch (e, stackTrace) {
      log('Failed to fetch board', error: e, stackTrace: stackTrace);
      return Result.failure(_scopeAwareMessage(e, 'Failed to load the project board'), stackTrace);
    }
  }

  /// Pulls the iteration field's full iteration list (completed + active, oldest
  /// → newest) from the project `fields`, plus the title of GitHub's current
  /// (first active) iteration. Includes iterations no item is assigned to yet —
  /// e.g. the upcoming "next" sprint. Matches the first iteration field by its
  /// `configuration`, so it works whatever the field is named (Sprint / Cycle …).
  ({List<Map<String, dynamic>> all, String? currentTitle}) _iterationConfig(Map<String, dynamic> project) {
    final fields = (project['fields']?['nodes'] as List<dynamic>?) ?? const [];
    for (final f in fields) {
      if (f is! Map<String, dynamic>) continue;
      final config = f['configuration'];
      if (config is! Map<String, dynamic> || config['iterations'] == null) continue;
      final completed = ((config['completedIterations'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final active = ((config['iterations'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>().toList();
      // GitHub's "current" iteration is the first active (non-completed) one.
      return (
        all: [...completed, ...active],
        currentTitle: active.isNotEmpty ? active.first['title'] as String? : null,
      );
    }
    return (all: const [], currentTitle: null);
  }

  String _scopeAwareMessage(Object e, String fallback) => e.toString().contains('read:project')
      ? 'Your GitHub token is missing the `read:project` scope. Add it at '
            'github.com/settings/tokens, then re-enter the token in Settings.'
      : fallback;
}

/// In-memory board seeded with the design sample, for tests and tokenless runs.
class MockProjectsBoardRepository implements ProjectsBoardRepository {
  const MockProjectsBoardRepository();

  @override
  Future<Result<ProjectBoardData>> fetchBoard() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Result.success(sampleBoard);
  }
}

BoardColumn _col(IssueStatus status, String label, List<BoardCard> cards) =>
    BoardColumn(status: status, label: label, cards: cards);

/// Sample board from `Projects Board.dc.html` (In Progress is the varied column).
final ProjectBoardData sampleBoard = ProjectBoardData(
  title: 'Mobile Q3 Roadmap',
  columns: [
    _col(IssueStatus.triage, 'Triage', const [
      BoardCard(
        id: 'o/api-gateway#301',
        type: BoardItemType.issue,
        owner: 'o',
        repo: 'api-gateway',
        number: 301,
        title: 'Investigate elevated 504s on /sync between 2–4am UTC',
        status: IssueStatus.triage,
        priority: IssuePriority.p0,
      ),
      BoardCard(
        id: 'o/web-portal#488',
        type: BoardItemType.issue,
        owner: 'o',
        repo: 'web-portal',
        number: 488,
        title: 'Billing export CSV missing tax column for EU accounts',
        status: IssueStatus.triage,
        priority: IssuePriority.p2,
        assignees: ['apatel-tv'],
      ),
    ]),
    _col(IssueStatus.notStarted, 'Not Started', const [
      BoardCard(
        id: 'o/mobile-app#598',
        type: BoardItemType.issue,
        owner: 'o',
        repo: 'mobile-app',
        number: 598,
        title: 'Add offline draft autosave to compose screen',
        status: IssueStatus.notStarted,
        priority: IssuePriority.p2,
        points: 8,
        subDone: 0,
        subTotal: 5,
        assignees: ['tromero-tv'],
      ),
    ]),
    _col(IssueStatus.inProgress, 'In Progress', const [
      BoardCard(
        id: 'o/mobile-app#571',
        type: BoardItemType.issue,
        owner: 'o',
        repo: 'mobile-app',
        number: 571,
        title: 'Biometric re-auth flow for sensitive actions',
        status: IssueStatus.inProgress,
        priority: IssuePriority.p0,
        points: 13,
        subDone: 3,
        subTotal: 7,
        assignees: ['tromero-tv', 'mkim-tv'],
      ),
      BoardCard(
        id: 'o/mobile-app#482',
        type: BoardItemType.pullRequest,
        owner: 'o',
        repo: 'mobile-app',
        number: 482,
        title: 'Add biometric auth to login flow',
        status: IssueStatus.inProgress,
        priority: IssuePriority.p0,
        points: 8,
        ciState: PrCiState.passing,
        reviewState: PrReviewState.approved,
        assignees: ['tromero-tv'],
      ),
      BoardCard(
        id: 'o/web-portal#155',
        type: BoardItemType.pullRequest,
        owner: 'o',
        repo: 'web-portal',
        number: 155,
        title: 'Migrate auth context to React Server Components',
        status: IssueStatus.inProgress,
        priority: IssuePriority.p1,
        points: 5,
        ciState: PrCiState.failing,
        reviewState: PrReviewState.changesRequested,
        staleDays: 6,
        assignees: ['apatel-tv', 'snguyen-tv'],
      ),
      BoardCard(
        id: 'o/design-system#86',
        type: BoardItemType.pullRequest,
        owner: 'o',
        repo: 'design-system',
        number: 86,
        title: 'Deprecate legacy button variants ahead of v3',
        status: IssueStatus.inProgress,
        priority: IssuePriority.p3,
        isDraft: true,
        ciState: PrCiState.pending,
        reviewState: PrReviewState.review,
        assignees: ['lbarros-tv'],
      ),
    ]),
    _col(IssueStatus.inReview, 'In Review', const [
      BoardCard(
        id: 'o/api-gateway#299',
        type: BoardItemType.pullRequest,
        owner: 'o',
        repo: 'api-gateway',
        number: 299,
        title: 'Connection pool tuning for read replicas',
        status: IssueStatus.inReview,
        priority: IssuePriority.p1,
        points: 5,
        ciState: PrCiState.passing,
        reviewState: PrReviewState.review,
        assignees: ['snguyen-tv'],
      ),
    ]),
    _col(IssueStatus.done, 'Done', const [
      BoardCard(
        id: 'o/mobile-app#470',
        type: BoardItemType.pullRequest,
        owner: 'o',
        repo: 'mobile-app',
        number: 470,
        title: 'Fix cold-start crash on Android 13',
        status: IssueStatus.done,
        priority: IssuePriority.p0,
        points: 3,
        ciState: PrCiState.passing,
        reviewState: PrReviewState.approved,
        assignees: ['tromero-tv'],
      ),
    ]),
  ],
);
