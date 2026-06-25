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
  // Epics (issues with sub-issues) are rollup containers, not point-bearing
  // tickets — exclude them from the unestimated count.
  final unestimated = open.where((i) => !i.isEpic && i.complexity == null).length;

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
  // Items closed this sprint, per assignee — throughput, not open load.
  final doneByAssignee = <String, int>{};
  for (final i in current.where((i) => i.status == IssueStatus.done)) {
    final who = i.assignees.firstOrNull;
    if (who == null) continue;
    doneByAssignee.update(who, (n) => n + 1, ifAbsent: () => 1);
  }

  final team =
      byAssignee.entries.map((e) {
        final list = e.value;
        final points = list.where((i) => !i.isEpic).fold<int>(0, (sum, i) => sum + (i.complexity?.round() ?? 0));
        return TeamMemberLoad(
          handle: e.key,
          wip: list.where((i) => i.status == IssueStatus.inProgress).length,
          inReview: list.where((i) => i.status == IssueStatus.inReview).length,
          done: doneByAssignee[e.key] ?? 0,
          stuck: list.where((i) => i.ageDays(now) >= stuckAfterDays).length,
          points: points,
          unestimated: list.where((i) => !i.isEpic && i.complexity == null).length,
          highPriority: list.where((i) => i.isHighPriority).length,
          items: (list..sort((a, b) => b.ageDays(now).compareTo(a.ageDays(now)))).take(3).map((i) {
            final age = i.ageDays(now);
            final stuck = age >= stuckAfterDays;
            return MemberItem(
              title: i.title,
              status: i.status ?? IssueStatus.notStarted,
              url: i.url,
              ageDays: stuck ? age : 0,
              stuck: stuck,
              subDone: i.subDone,
              subTotal: i.subTotal,
            );
          }).toList(),
        );
      }).toList()..sort((a, b) {
        final p = b.points.compareTo(a.points);
        return p != 0 ? p : (b.wip + b.inReview).compareTo(a.wip + a.inReview);
      });

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
          url: i.url,
          // Live linked-PR state is a follow-up (needs a per-issue timeline query).
          prLabel: '—',
        );
      }).toList()..sort((a, b) {
        if (a.critical != b.critical) return a.critical ? -1 : 1;
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : b.ageDays.compareTo(a.ageDays);
      });

  return CockpitData(
    sprint: sprint,
    team: team.take(6).toList(),
    stuck: stuck.take(10).toList(),
    flow: _sprintFlow(current, sprintItem, now),
  );
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Buckets the current sprint's items into per-weekday throughput (closed) and
/// inflow (created), keyed by `closedAt` / `createdAt`. Weekends are skipped so
/// the chart x-axis matches the design's working-day grid; items closed/opened
/// on a weekend simply don't get a tile. Falls back to an
/// earliest-activity→today window when the sprint has no iteration dates.
SprintFlow _sprintFlow(List<_BoardItem> current, _BoardItem? sprintItem, DateTime now) {
  DateTime start;
  DateTime end;
  if (sprintItem?.iterationStart != null) {
    start = _dateOnly(sprintItem!.iterationStart!);
    end = start.add(Duration(days: sprintItem.iterationDuration ?? 14));
  } else {
    final stamps = <DateTime>[
      for (final i in current) ...[if (i.createdAt != null) i.createdAt!, if (i.closedAt != null) i.closedAt!],
    ];
    final earliest = stamps.isEmpty
        ? now.subtract(const Duration(days: 13))
        : stamps.reduce((a, b) => a.isBefore(b) ? a : b);
    start = _dateOnly(earliest);
    end = _dateOnly(now).add(const Duration(days: 1));
  }

  final days = <DateTime, FlowDay>{};
  final order = <DateTime>[];
  for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) continue;
    final key = _dateOnly(d);
    days[key] = FlowDay(date: key);
    order.add(key);
  }
  if (order.isEmpty) return SprintFlow(start: start, end: end, days: const []);

  bool inWindow(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  for (final i in current) {
    final ticket = FlowTicket(
      number: i.number == null ? '' : '#${i.number}',
      title: i.title,
      repo: i.repo,
      assignee: i.assignees.firstOrNull ?? '',
      url: i.url,
    );
    final created = i.createdAt;
    if (created != null && inWindow(created)) {
      final day = days[_dateOnly(created)];
      if (day != null) {
        days[_dateOnly(created)] = day.copyWith(opened: day.opened + 1, openedTickets: [...day.openedTickets, ticket]);
      }
    }
    final closed = i.closedAt;
    if (closed != null && inWindow(closed)) {
      final day = days[_dateOnly(closed)];
      if (day != null) {
        days[_dateOnly(closed)] = day.copyWith(done: day.done + 1, doneTickets: [...day.doneTickets, ticket]);
      }
    }
  }

  return SprintFlow(start: start, end: end, days: [for (final k in order) days[k]!]);
}

/// A flattened board item parsed out of the GraphQL `fieldValues` shape.
class _BoardItem {
  _BoardItem({
    required this.title,
    required this.repo,
    required this.assignees,
    required this.updatedAt,
    this.number,
    this.createdAt,
    this.closedAt,
    this.url,
    this.status,
    this.priority,
    this.complexity,
    this.subTotal,
    this.subDone,
    this.iterationTitle,
    this.iterationStart,
    this.iterationDuration,
  });

  final String title;
  final String repo;
  final List<String> assignees;
  final DateTime updatedAt;
  final int? number;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final String? url;
  final int? subTotal;
  final int? subDone;
  final IssueStatus? status;
  final IssuePriority? priority;
  final num? complexity;
  final String? iterationTitle;
  final DateTime? iterationStart;
  final int? iterationDuration;

  bool get isOpen => status != IssueStatus.done && status != IssueStatus.cancelled;

  /// Issues with sub-issues are epics — rollup containers, not point-bearing
  /// tickets — so they're excluded from point/estimate counts.
  bool get isEpic => (subTotal ?? 0) > 0;
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

    final subSummary = content['subIssuesSummary'];
    final subTotal = subSummary is Map<String, dynamic> ? (subSummary['total'] as num?)?.toInt() : null;
    final subDone = subSummary is Map<String, dynamic> ? (subSummary['completed'] as num?)?.toInt() : null;

    return _BoardItem(
      title: (content['title'] as String?) ?? '',
      repo: (content['repository']?['name'] as String?) ?? '',
      number: (content['number'] as num?)?.toInt(),
      // GitHub stamps are UTC (`…Z`); convert to local so per-day bucketing
      // lines up with the viewer's calendar (and the local `now`).
      createdAt: DateTime.tryParse((content['createdAt'] as String?) ?? '')?.toLocal(),
      closedAt: DateTime.tryParse((content['closedAt'] as String?) ?? '')?.toLocal(),
      url: content['url'] as String?,
      subTotal: subTotal,
      subDone: subDone,
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

  /// Map a board's Status option to our enum. Tolerant of casing/spacing and of
  /// the common naming variants different boards use ("Backlog", "Doing",
  /// "Review", "Closed", …) so the sprint counts populate beyond the canonical
  /// option names. Unknown values stay null (the item is still treated as open).
  static IssueStatus? _statusFrom(String? name) {
    final n = name?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (n == null || n.isEmpty) return null;
    return switch (n) {
      'not started' || 'backlog' || 'to do' || 'todo' || 'new' || 'open' => IssueStatus.notStarted,
      'in progress' || 'doing' || 'wip' || 'started' || 'in dev' || 'development' => IssueStatus.inProgress,
      'in review' || 'review' || 'code review' || 'in qa' || 'qa' || 'testing' => IssueStatus.inReview,
      'triage' || 'needs triage' || 'blocked' || 'on hold' => IssueStatus.triage,
      'done' || 'closed' || 'shipped' || 'complete' || 'completed' || 'merged' => IssueStatus.done,
      'cancelled' || 'canceled' || "won't do" || 'wont do' || 'duplicate' || 'invalid' => IssueStatus.cancelled,
      _ => null,
    };
  }

  static IssuePriority? _priorityFrom(String? name) {
    final n = name?.trim().toLowerCase();
    if (n == null || n.isEmpty) return null;
    return switch (n) {
      'p0' || 'critical' || 'urgent' || 'highest' => IssuePriority.p0,
      'p1' || 'high' => IssuePriority.p1,
      'p2' || 'medium' || 'normal' => IssuePriority.p2,
      'p3' || 'low' || 'lowest' => IssuePriority.p3,
      _ => null,
    };
  }
}
