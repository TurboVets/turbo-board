import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/cockpit_data.dart';
import '../queries/list_projects.dart';
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

  /// Lists the Projects v2 boards the user can pick from (own + org boards).
  Future<Result<List<ProjectRef>>> listProjects();
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
      return Result.failure(_scopeAwareMessage(e, 'Failed to load the sprint cockpit'), stackTrace);
    }
  }

  @override
  Future<Result<List<ProjectRef>>> listProjects() async {
    try {
      final data = await _client.graphql(listProjectsQuery, const {});
      final viewer = data['viewer'] as Map<String, dynamic>?;
      final projects = <ProjectRef>[];

      void addNodes(String owner, dynamic projectsV2) {
        final nodes = (projectsV2?['nodes'] as List<dynamic>?) ?? const [];
        for (final raw in nodes.whereType<Map<String, dynamic>>()) {
          if (raw['closed'] == true) continue;
          final number = raw['number'];
          if (number is! int) continue;
          projects.add(ProjectRef(owner: owner, number: number, title: (raw['title'] as String?) ?? 'Untitled'));
        }
      }

      final viewerLogin = (viewer?['login'] as String?) ?? '';
      if (viewerLogin.isNotEmpty) addNodes(viewerLogin, viewer?['projectsV2']);
      for (final org
          in ((viewer?['organizations']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
        addNodes((org['login'] as String?) ?? '', org['projectsV2']);
      }

      projects.sort((a, b) => a.key.compareTo(b.key));
      return Result.success(projects);
    } catch (e, stackTrace) {
      log('Failed to list projects', error: e, stackTrace: stackTrace);
      return Result.failure(_scopeAwareMessage(e, 'Could not list your GitHub projects'), stackTrace);
    }
  }

  /// Surfaces the missing-scope case with an actionable hint; otherwise [fallback].
  String _scopeAwareMessage(Object e, String fallback) => e.toString().contains('read:project')
      ? 'Your GitHub token is missing the `read:project` scope. Add it at '
            'github.com/settings/tokens, then re-enter the token in Settings.'
      : fallback;
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

  @override
  Future<Result<List<ProjectRef>>> listProjects() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return Result.success(const [
      ProjectRef(owner: 'TurboVets', number: 8, title: 'Mobile Space'),
      ProjectRef(owner: 'TurboVets', number: 3, title: 'Platform Roadmap'),
    ]);
  }
}

final _sampleCockpit = CockpitData(
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
      handle: 'tromero-tv',
      wip: 6,
      inReview: 2,
      done: 12,
      stuck: 3,
      points: 38,
      unestimated: 0,
      highPriority: 2,
      items: [
        MemberItem(
          title: 'Handle permission-denied submission gracefully',
          status: IssueStatus.inReview,
          ageDays: 6,
          stuck: true,
          subDone: 3,
          subTotal: 7,
        ),
        MemberItem(
          title: 'Fix keyboard inset on Android 15 form fields',
          status: IssueStatus.inProgress,
          ageDays: 7,
          stuck: true,
        ),
        MemberItem(title: 'Background sync wakelock audit', status: IssueStatus.inProgress),
      ],
    ),
    TeamMemberLoad(
      handle: 'apatel-tv',
      wip: 4,
      inReview: 2,
      done: 16,
      stuck: 2,
      points: 28,
      unestimated: 2,
      highPriority: 0,
      items: [
        MemberItem(title: 'E2E: form submission flow', status: IssueStatus.inReview, ageDays: 5, stuck: true),
        MemberItem(title: 'Token refresh race on multi-tab web', status: IssueStatus.triage, ageDays: 13, stuck: true),
        MemberItem(title: 'Skeleton states for slow networks', status: IssueStatus.inProgress, subDone: 2, subTotal: 5),
      ],
    ),
    TeamMemberLoad(
      handle: 'snguyen-tv',
      wip: 3,
      inReview: 2,
      done: 14,
      stuck: 1,
      points: 26,
      unestimated: 0,
      highPriority: 1,
      items: [
        MemberItem(
          title: 'Harden deeplink cold-start routes',
          status: IssueStatus.inProgress,
          ageDays: 9,
          stuck: true,
          subDone: 5,
          subTotal: 8,
        ),
        MemberItem(title: 'Offline queue: retry submissions with backoff', status: IssueStatus.inReview),
        MemberItem(title: 'Crash triage rotation — week 24', status: IssueStatus.notStarted),
      ],
    ),
    TeamMemberLoad(
      handle: 'mkim-tv',
      wip: 2,
      inReview: 1,
      done: 21,
      stuck: 1,
      points: 14,
      unestimated: 1,
      highPriority: 0,
      items: [
        MemberItem(
          title: 'Migrate image picker to photo_manager',
          status: IssueStatus.triage,
          ageDays: 11,
          stuck: true,
        ),
        MemberItem(title: 'Add haptics to primary CTA flows', status: IssueStatus.inProgress),
      ],
    ),
    TeamMemberLoad(
      handle: 'lbarros-tv',
      wip: 1,
      inReview: 0,
      done: 8,
      stuck: 1,
      points: 8,
      unestimated: 0,
      highPriority: 0,
      items: [
        MemberItem(
          title: 'Crash: null check in resume-upload provider',
          status: IssueStatus.notStarted,
          ageDays: 5,
          stuck: true,
        ),
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
  flow: _sampleFlow,
);

/// Sample sprint flow: two work weeks (Mon Jun 15 → Fri Jun 26 2026), with
/// "today" = Tue Jun 23. Counts drive the burnup; two days carry ticket lists
/// so the daily-detail popup has something to show.
final _sampleFlow = SprintFlow(
  start: _d15,
  end: _d27,
  days: [
    FlowDay(
      date: _d15,
      done: 3,
      opened: 5,
      openedTickets: [
        FlowTicket(
          number: '#455',
          title: 'Offline queue: retry submissions with backoff',
          repo: 'recruit-mobile',
          assignee: 'tromero-tv',
        ),
        FlowTicket(number: '#456', title: 'Skeleton states for slow networks', repo: 'mobile', assignee: 'apatel-tv'),
        FlowTicket(number: '#457', title: 'Crash triage rotation — week 24', repo: 'mobile', assignee: 'snguyen-tv'),
        FlowTicket(number: '#458', title: 'Add haptics to primary CTA flows', repo: 'mobile', assignee: 'mkim-tv'),
        FlowTicket(
          number: '#459',
          title: 'Design-token sync from Tether v2.0',
          repo: 'mobile-shared-components',
          assignee: 'lbarros-tv',
        ),
      ],
    ),
    FlowDay(
      date: _d16,
      done: 3,
      opened: 2,
      doneTickets: [
        FlowTicket(number: '#412', title: 'Fix deeplink cold-start routes', repo: 'mobile', assignee: 'snguyen-tv'),
        FlowTicket(
          number: '#418',
          title: 'Token refresh race on multi-tab web',
          repo: 'mobile-shared-components',
          assignee: 'apatel-tv',
        ),
        FlowTicket(
          number: '#401',
          title: 'Migrate image picker to photo_manager',
          repo: 'mobile-shared-components',
          assignee: 'lbarros-tv',
        ),
      ],
      openedTickets: [
        FlowTicket(number: '#460', title: 'Background sync wakelock audit', repo: 'mobile', assignee: 'tromero-tv'),
        FlowTicket(number: '#461', title: 'E2E: form submission flow', repo: 'recruit-mobile', assignee: 'mkim-tv'),
      ],
    ),
    FlowDay(date: _d17, done: 2, opened: 1),
    FlowDay(date: _d18, done: 0, opened: 3),
    FlowDay(
      date: _d19,
      done: 4,
      doneTickets: [
        FlowTicket(number: '#427', title: 'Background sync wakelock audit', repo: 'mobile', assignee: 'tromero-tv'),
        FlowTicket(number: '#431', title: 'Add haptics to primary CTA flows', repo: 'mobile', assignee: 'mkim-tv'),
        FlowTicket(number: '#402', title: 'Harden deeplink cold-start routes', repo: 'mobile', assignee: 'snguyen-tv'),
        FlowTicket(
          number: '#410',
          title: 'Crash: null check in resume-upload provider',
          repo: 'mobile',
          assignee: 'lbarros-tv',
        ),
      ],
    ),
    FlowDay(date: _d22, done: 6, opened: 2),
    FlowDay(date: _d23, done: 3, opened: 1),
    FlowDay(date: _d24),
    FlowDay(date: _d25),
    FlowDay(date: _d26),
  ],
);

final _d15 = DateTime(2026, 6, 15);
final _d16 = DateTime(2026, 6, 16);
final _d17 = DateTime(2026, 6, 17);
final _d18 = DateTime(2026, 6, 18);
final _d19 = DateTime(2026, 6, 19);
final _d22 = DateTime(2026, 6, 22);
final _d23 = DateTime(2026, 6, 23);
final _d24 = DateTime(2026, 6, 24);
final _d25 = DateTime(2026, 6, 25);
final _d26 = DateTime(2026, 6, 26);
final _d27 = DateTime(2026, 6, 27);
