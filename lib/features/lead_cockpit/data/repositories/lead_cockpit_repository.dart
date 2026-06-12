import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/cockpit_data.dart';
import '../queries/project_board.dart';
import 'cockpit_mapper.dart';

/// Data access for the Lead Cockpit (GitHub Projects v2 board rollup).
///
/// v0 ships a mock implementation seeded with the design's sample sprint so the
/// screen can be built and tested. The real implementation reads the
/// `organization.projectV2` board via turbo_core's GraphQLClient and layers the
/// hybrid snapshot history (see `docs/V2-ISSUES-SCOPE.md`) behind this same
/// interface.
abstract class LeadCockpitRepository {
  Future<Result<CockpitData>> fetchCockpit();
}

/// Reads a live GitHub Projects v2 board and maps it to [CockpitData].
///
/// Requires a token with `read:project` + org access. Time-derived figures
/// (time-in-status, "at risk") are approximated from `updatedAt` until the
/// snapshot history lands — see `docs/V2-ISSUES-SCOPE.md`.
class GithubLeadCockpitRepository implements LeadCockpitRepository {
  GithubLeadCockpitRepository(
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
  Future<Result<CockpitData>> fetchCockpit() async {
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

      return Result.success(cockpitFromProjectItems(boardTitle ?? 'Project board', nodes, now: _clock()));
    } catch (e, stackTrace) {
      log('Failed to fetch cockpit data', error: e, stackTrace: stackTrace);
      final message = e.toString().contains('read:project')
          ? 'Your GitHub token is missing the `read:project` scope. Add it at '
                'github.com/settings/tokens, then re-enter the token in Settings.'
          : 'Failed to load the sprint cockpit';
      return Result.failure(message, stackTrace);
    }
  }
}

class MockLeadCockpitRepository implements LeadCockpitRepository {
  const MockLeadCockpitRepository();

  @override
  Future<Result<CockpitData>> fetchCockpit() async {
    try {
      // Simulated network latency.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return Result.success(_sampleCockpit);
    } catch (e, stackTrace) {
      log('Failed to fetch cockpit data', error: e, stackTrace: stackTrace);
      return Result.failure('Failed to load the sprint cockpit', stackTrace);
    }
  }
}

const _sampleCockpit = CockpitData(
  sprint: SprintHealth(
    name: 'Sprint 24 · Mobile Space',
    daysRemaining: 6,
    endLabel: 'ends Jun 17',
    totalIssues: 145,
    repoCount: 3,
    done: 58,
    inProgress: 31,
    inReview: 17,
    notStarted: 27,
    atRisk: 9,
    unestimated: 12,
  ),
  team: [
    TeamMemberLoad(
      handle: 'snguyen-tv',
      wip: 3,
      inReview: 2,
      stuck: 1,
      loadPercent: 55,
      items: [
        MemberItem(title: 'Harden deeplink cold-start routes', status: IssueStatus.inProgress),
        MemberItem(title: 'Offline queue: retry submissions with backoff', status: IssueStatus.inReview),
        MemberItem(title: 'Crash triage rotation — week 24', status: IssueStatus.notStarted),
      ],
    ),
    TeamMemberLoad(
      handle: 'tromero-tv',
      wip: 6,
      inReview: 2,
      stuck: 3,
      loadPercent: 96,
      items: [
        MemberItem(title: 'Handle permission-denied submission gracefully', status: IssueStatus.inReview),
        MemberItem(title: 'Fix keyboard inset on Android 15 form fields', status: IssueStatus.inProgress),
        MemberItem(title: 'Background sync wakelock audit', status: IssueStatus.inProgress),
      ],
    ),
    TeamMemberLoad(
      handle: 'mkim-tv',
      wip: 2,
      inReview: 1,
      stuck: 1,
      loadPercent: 32,
      items: [
        MemberItem(title: 'Migrate image picker to photo_manager', status: IssueStatus.triage),
        MemberItem(title: 'Add haptics to primary CTA flows', status: IssueStatus.inProgress),
      ],
    ),
    TeamMemberLoad(
      handle: 'apatel-tv',
      wip: 4,
      inReview: 2,
      stuck: 2,
      loadPercent: 68,
      items: [
        MemberItem(title: 'E2E: form submission flow', status: IssueStatus.inReview),
        MemberItem(title: 'Token refresh race on multi-tab web', status: IssueStatus.triage),
        MemberItem(title: 'Skeleton states for slow networks', status: IssueStatus.inProgress),
      ],
    ),
    TeamMemberLoad(
      handle: 'lbarros-tv',
      wip: 1,
      inReview: 0,
      stuck: 1,
      loadPercent: 18,
      items: [
        MemberItem(title: 'Crash: null check in resume-upload provider', status: IssueStatus.notStarted),
        MemberItem(title: 'Design-token sync from Tether v2.0', status: IssueStatus.done),
      ],
    ),
  ],
  stuck: [
    StuckIssue(
      title: 'Harden deeplink cold-start routes',
      repo: 'mobile',
      assignee: 'snguyen-tv',
      priority: IssuePriority.p0,
      status: IssueStatus.inProgress,
      ageDays: 9,
      critical: true,
      prLabel: 'PR #1198 ✕ checks failing',
    ),
    StuckIssue(
      title: 'Token refresh race on multi-tab web',
      repo: 'mobile-shared-components',
      assignee: 'apatel-tv',
      priority: IssuePriority.p3,
      status: IssueStatus.triage,
      ageDays: 13,
      critical: true,
      prLabel: '—',
    ),
    StuckIssue(
      title: 'Migrate image picker to photo_manager',
      repo: 'mobile-shared-components',
      assignee: 'mkim-tv',
      priority: IssuePriority.p2,
      status: IssueStatus.triage,
      ageDays: 11,
      critical: true,
      prLabel: '—',
    ),
    StuckIssue(
      title: 'Fix keyboard inset on Android 15 form fields',
      repo: 'mobile',
      assignee: 'tromero-tv',
      priority: IssuePriority.p1,
      status: IssueStatus.inProgress,
      ageDays: 7,
      critical: true,
      prLabel: 'PR #1210 · draft',
    ),
    StuckIssue(
      title: 'Handle permission-denied submission gracefully',
      repo: 'mobile',
      assignee: 'tromero-tv',
      priority: IssuePriority.p1,
      status: IssueStatus.inReview,
      ageDays: 6,
      prLabel: 'PR #1204 ⏳ awaiting review',
    ),
    StuckIssue(
      title: 'E2E: form submission flow',
      repo: 'recruit-mobile',
      assignee: 'apatel-tv',
      priority: IssuePriority.p2,
      status: IssueStatus.inReview,
      ageDays: 5,
      prLabel: 'PR #341 ⏳ awaiting review',
    ),
    StuckIssue(
      title: 'Crash: null check in resume-upload provider',
      repo: 'mobile',
      assignee: 'lbarros-tv',
      priority: IssuePriority.p0,
      status: IssueStatus.notStarted,
      ageDays: 5,
      critical: true,
      prLabel: '—',
    ),
    StuckIssue(
      title: 'Offline queue: retry submissions with backoff',
      repo: 'recruit-mobile',
      assignee: 'snguyen-tv',
      priority: IssuePriority.p1,
      status: IssueStatus.inReview,
      ageDays: 4,
      prLabel: 'PR #338 ✓ approved, unmerged',
    ),
  ],
);
