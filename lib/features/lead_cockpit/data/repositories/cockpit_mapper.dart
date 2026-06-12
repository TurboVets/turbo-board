// Pure transform from raw Projects v2 `items.nodes` into CockpitData.
//
// Kept free of any network/IO so it can be unit-tested with fixture JSON.
// Time-derived figures (time-in-status, "at risk") are approximations until
// the snapshot history lands — see `docs/V2-ISSUES-SCOPE.md`.
import '../models/cockpit_data.dart';

/// An item is "stuck" once it has sat in its status this many days without an
/// update; past [_criticalAgeDays] it is flagged critical (red).
const int stuckAfterDays = 4;
const int _criticalAgeDays = 7;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

CockpitData cockpitFromProjectItems(String boardTitle, List<Map<String, dynamic>> nodes, {required DateTime now}) {
  final items = nodes.map((n) => _BoardItem.parse(n)).whereType<_BoardItem>().toList();

  // ── Current sprint = the iteration window containing `now` (else latest). ──
  final iterations = items.where((i) => i.iterationStart != null).toList();
  _BoardItem? sprintItem;
  for (final i in iterations) {
    final start = i.iterationStart!;
    final end = start.add(Duration(days: i.iterationDuration ?? 14));
    if (!now.isBefore(start) && now.isBefore(end)) {
      sprintItem = i;
      break;
    }
  }
  sprintItem ??= (iterations..sort((a, b) => b.iterationStart!.compareTo(a.iterationStart!))).firstOrNull;

  final sprintTitle = sprintItem?.iterationTitle;
  final current = sprintTitle == null ? items : items.where((i) => i.iterationTitle == sprintTitle).toList();

  // ── Sprint health ──────────────────────────────────────────────────────────
  int countStatus(IssueStatus s) => current.where((i) => i.status == s).length;
  final open = current.where((i) => i.isOpen).toList();
  final atRisk = open.where((i) => i.isHighPriority && i.ageDays(now) >= stuckAfterDays).length;
  final unestimated = open.where((i) => i.complexity == null).length;

  String endLabel = '';
  int daysRemaining = 0;
  if (sprintItem?.iterationStart != null) {
    final end = sprintItem!.iterationStart!.add(Duration(days: sprintItem.iterationDuration ?? 14));
    endLabel = 'ends ${_months[end.month - 1]} ${end.day}';
    daysRemaining = end.difference(now).inDays.clamp(0, 999);
  }

  final sprint = SprintHealth(
    name: sprintTitle == null ? boardTitle : '$sprintTitle · $boardTitle',
    daysRemaining: daysRemaining,
    endLabel: endLabel,
    totalIssues: current.length,
    repoCount: current.map((i) => i.repo).where((r) => r.isNotEmpty).toSet().length,
    done: countStatus(IssueStatus.done),
    inProgress: countStatus(IssueStatus.inProgress),
    inReview: countStatus(IssueStatus.inReview),
    notStarted: countStatus(IssueStatus.notStarted),
    atRisk: atRisk,
    unestimated: unestimated,
  );

  // ── Per-person load ──────────────────────────────────────────────────────────
  final byAssignee = <String, List<_BoardItem>>{};
  for (final i in open) {
    final who = i.assignees.firstOrNull;
    if (who == null) continue;
    byAssignee.putIfAbsent(who, () => []).add(i);
  }
  final maxOpen = byAssignee.values.fold(0, (m, l) => l.length > m ? l.length : m);
  final team = byAssignee.entries.map((e) {
    final list = e.value;
    return TeamMemberLoad(
      handle: e.key,
      wip: list.where((i) => i.status == IssueStatus.inProgress).length,
      inReview: list.where((i) => i.status == IssueStatus.inReview).length,
      stuck: list.where((i) => i.ageDays(now) >= stuckAfterDays).length,
      loadPercent: maxOpen == 0 ? 0 : ((list.length / maxOpen) * 100).round().clamp(0, 100),
      items: (list..sort((a, b) => b.ageDays(now).compareTo(a.ageDays(now))))
          .take(3)
          .map((i) => MemberItem(title: i.title, status: i.status ?? IssueStatus.notStarted))
          .toList(),
    );
  }).toList()..sort((a, b) => b.loadPercent.compareTo(a.loadPercent));

  // ── Aging / stuck ──────────────────────────────────────────────────────────
  final stuck =
      open.where((i) => i.ageDays(now) >= stuckAfterDays).map((i) {
        final age = i.ageDays(now);
        return StuckIssue(
          title: i.title,
          repo: i.repo,
          assignee: i.assignees.firstOrNull ?? '—',
          priority: i.priority ?? IssuePriority.p3,
          status: i.status ?? IssueStatus.notStarted,
          ageDays: age,
          critical: age >= _criticalAgeDays || i.priority == IssuePriority.p0,
          // Live linked-PR state is a follow-up (needs a per-issue timeline query).
          prLabel: '—',
        );
      }).toList()..sort((a, b) {
        if (a.critical != b.critical) return a.critical ? -1 : 1;
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : b.ageDays.compareTo(a.ageDays);
      });

  return CockpitData(sprint: sprint, team: team.take(6).toList(), stuck: stuck.take(10).toList());
}

/// A flattened board item parsed out of the GraphQL `fieldValues` shape.
class _BoardItem {
  _BoardItem({
    required this.title,
    required this.repo,
    required this.assignees,
    required this.updatedAt,
    this.status,
    this.priority,
    this.complexity,
    this.iterationTitle,
    this.iterationStart,
    this.iterationDuration,
  });

  final String title;
  final String repo;
  final List<String> assignees;
  final DateTime updatedAt;
  final IssueStatus? status;
  final IssuePriority? priority;
  final num? complexity;
  final String? iterationTitle;
  final DateTime? iterationStart;
  final int? iterationDuration;

  bool get isOpen => status != IssueStatus.done && status != IssueStatus.cancelled;
  bool get isHighPriority => priority == IssuePriority.p0 || priority == IssuePriority.p1;
  int ageDays(DateTime now) => now.difference(updatedAt).inDays.clamp(0, 9999);

  static _BoardItem? parse(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! Map<String, dynamic> || content['__typename'] != 'Issue') return null;

    IssueStatus? status;
    IssuePriority? priority;
    num? complexity;
    String? iterationTitle;
    DateTime? iterationStart;
    int? iterationDuration;

    final fieldNodes = (node['fieldValues']?['nodes'] as List<dynamic>?) ?? const [];
    for (final raw in fieldNodes) {
      if (raw is! Map<String, dynamic>) continue;
      final fieldName = (raw['field']?['name'] as String?)?.toLowerCase() ?? '';
      switch (raw['__typename']) {
        case 'ProjectV2ItemFieldSingleSelectValue':
          final value = raw['name'] as String?;
          if (fieldName == 'status') {
            status = _statusFrom(value);
          } else if (fieldName == 'priority') {
            priority = _priorityFrom(value);
          }
        case 'ProjectV2ItemFieldNumberValue':
          if (fieldName == 'complexity') complexity = raw['number'] as num?;
        case 'ProjectV2ItemFieldIterationValue':
          if (fieldName == 'sprint') {
            iterationTitle = raw['title'] as String?;
            iterationStart = DateTime.tryParse((raw['startDate'] as String?) ?? '');
            iterationDuration = (raw['duration'] as num?)?.toInt();
          }
      }
    }

    final assignees = ((content['assignees']?['nodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((a) => a['login'] as String?)
        .whereType<String>()
        .toList();

    return _BoardItem(
      title: (content['title'] as String?) ?? '',
      repo: (content['repository']?['name'] as String?) ?? '',
      assignees: assignees,
      updatedAt: DateTime.tryParse((node['updatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: status,
      priority: priority,
      complexity: complexity,
      iterationTitle: iterationTitle,
      iterationStart: iterationStart,
      iterationDuration: iterationDuration,
    );
  }

  static IssueStatus? _statusFrom(String? name) => switch (name) {
    'Not Started' => IssueStatus.notStarted,
    'In Progress' => IssueStatus.inProgress,
    'In Review' => IssueStatus.inReview,
    'Triage' => IssueStatus.triage,
    'Done' => IssueStatus.done,
    'Cancelled' => IssueStatus.cancelled,
    _ => null,
  };

  static IssuePriority? _priorityFrom(String? name) => switch (name) {
    'P0' => IssuePriority.p0,
    'P1' => IssuePriority.p1,
    'P2' => IssuePriority.p2,
    'P3' => IssuePriority.p3,
    _ => null,
  };
}
