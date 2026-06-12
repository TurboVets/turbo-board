// Pure transform from raw Projects v2 `items.nodes` into a SprintReport for a
// chosen sprint iteration. No network/IO — unit-tested with fixture JSON.
//
// Points come from the board's Complexity number field. The burndown actual
// line is reconstructed from each issue's `closedAt` (a closed issue = its
// points burned down on that date) — works retroactively for the whole sprint,
// no daily snapshots needed. Epic rollups use each issue's `subIssuesSummary`.
import '../models/sprint_report.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Builds the report for [selectedSprint] (by iteration title); when null, picks
/// the iteration whose window contains [now], else the latest.
SprintReport sprintReportFromProjectItems(
  String boardTitle,
  List<Map<String, dynamic>> nodes, {
  required DateTime now,
  String? selectedSprint,
}) {
  final items = nodes.map(_RItem.parse).whereType<_RItem>().toList();

  // ── Enumerate sprints (oldest → newest) from the items' iteration values. ──
  final starts = <String, DateTime>{};
  final durations = <String, int>{};
  for (final i in items) {
    final t = i.iterationTitle;
    if (t == null || i.iterationStart == null) continue;
    starts.putIfAbsent(t, () => i.iterationStart!);
    durations.putIfAbsent(t, () => i.iterationDuration ?? 14);
  }
  final sprintTitles = starts.keys.toList()..sort((a, b) => starts[a]!.compareTo(starts[b]!));

  int sprintIndex;
  if (selectedSprint != null && sprintTitles.contains(selectedSprint)) {
    sprintIndex = sprintTitles.indexOf(selectedSprint);
  } else {
    sprintIndex = sprintTitles.indexWhere((t) {
      final start = starts[t]!;
      final end = start.add(Duration(days: durations[t]!));
      return !now.isBefore(start) && now.isBefore(end);
    });
    if (sprintIndex < 0) sprintIndex = sprintTitles.length - 1; // latest, or -1 if none
  }

  final title = sprintIndex >= 0 ? sprintTitles[sprintIndex] : null;
  final current = title == null ? items : items.where((i) => i.iterationTitle == title).toList();

  final start = title == null ? null : starts[title];
  final totalDays = title == null ? 14 : durations[title]!;
  final end = start?.add(Duration(days: totalDays));
  final elapsed = start == null ? 0 : now.difference(start).inDays.clamp(0, totalDays);
  final daysRemaining = end == null ? 0 : end.difference(now).inDays.clamp(0, 999);

  int pts(Iterable<_RItem> xs) => xs.fold<num>(0, (s, i) => s + (i.complexity ?? 0)).round();
  Iterable<_RItem> withStatus(ReportStatusKind k) => current.where((i) => i.kind == k);

  final slices = [
    for (final k in ReportStatusKind.values)
      StatusSlice(kind: k, label: _statusLabel(k), tickets: withStatus(k).length, points: pts(withStatus(k))),
  ];
  final committed = slices.fold<int>(0, (s, e) => s + e.points);
  final pointsDone = slices.firstWhere((s) => s.kind == ReportStatusKind.done).points;

  final estimated = current.where((i) => i.complexity != null).toList();
  final unestimated = current.length - estimated.length;

  // ── Per-assignee point split ──
  final byAssignee = <String, List<_RItem>>{};
  for (final i in current) {
    final who = i.assignees.isEmpty ? null : i.assignees.first;
    if (who == null) continue;
    byAssignee.putIfAbsent(who, () => []).add(i);
  }
  final people =
      byAssignee.entries
          .map((e) {
            final done = pts(e.value.where((i) => i.kind == ReportStatusKind.done));
            final inProgress = pts(e.value.where((i) => i.kind == ReportStatusKind.inProgress));
            final remaining = pts(
              e.value.where((i) => i.kind == ReportStatusKind.inReview || i.kind == ReportStatusKind.notStarted),
            );
            return AssigneePoints(handle: e.key, done: done, inProgress: inProgress, remaining: remaining);
          })
          .where((p) => p.total > 0)
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  // ── Per-assignee ticket-count split ──
  final peopleTickets =
      byAssignee.entries
          .map((e) {
            final done = e.value.where((i) => i.kind == ReportStatusKind.done).length;
            final inProgress = e.value.where((i) => i.kind == ReportStatusKind.inProgress).length;
            final remaining = e.value
                .where((i) => i.kind == ReportStatusKind.inReview || i.kind == ReportStatusKind.notStarted)
                .length;
            return AssigneeTickets(handle: e.key, done: done, inProgress: inProgress, remaining: remaining);
          })
          .where((t) => t.total > 0)
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  // ── Epics (B2): in-sprint issues that have sub-issues. ──
  final epics = current.where((i) => i.subsTotal > 0).map((i) {
    final pointsTotal = (i.complexity ?? 0).round();
    final pointsDoneEpic = (pointsTotal * i.subsPercent / 100).round();
    return EpicProgress(
      title: i.title,
      subsDone: i.subsDone,
      subsTotal: i.subsTotal,
      pointsDone: pointsDoneEpic,
      pointsTotal: pointsTotal,
    );
  }).toList()..sort((a, b) => b.percent.compareTo(a.percent));

  // ── Forecast ──
  final dailyRate = totalDays == 0 ? 0.0 : committed / totalDays;
  final idealDone = dailyRate * elapsed;
  final gapPts = idealDone - pointsDone; // positive → behind
  final gapDays = dailyRate == 0 ? 0.0 : gapPts / dailyRate;
  final behind = gapDays >= 0.5;
  final ahead = gapDays <= -0.5;
  final forecastLabel = behind
      ? 'Trending ~${gapDays.round()}d behind'
      : ahead
      ? 'Trending ~${(-gapDays).round()}d ahead'
      : 'On track';
  final forecastDetail =
      '$pointsDone pts done vs ${idealDone.round()} ideal at day $elapsed of $totalDays — '
      'gap of ${gapPts.round()} pts ≈ ${gapDays.abs().toStringAsFixed(1)} days at the current rate';

  String dateRange = '';
  if (start != null && end != null) {
    dateRange = '${_months[start.month - 1]} ${start.day} – ${_months[end.month - 1]} ${end.day}';
  }

  // ── Burndown actuals from issue close dates ──
  // remaining(day d) = committed − points of in-sprint items closed by end of day d.
  // Closes before the sprint start count at day 0. Spans day 0..elapsed.
  final actualRemaining = <int>[];
  if (start != null) {
    final closedPts = current
        .where((i) => i.closed && i.closedAt != null && i.complexity != null)
        .map((i) => (start: i.closedAt!, pts: i.complexity!.round()))
        .toList();
    for (var d = 0; d <= elapsed; d++) {
      final dayEnd = start.add(Duration(days: d + 1)); // end of day d
      final burned = closedPts.where((c) => c.start.isBefore(dayEnd)).fold<int>(0, (s, c) => s + c.pts);
      actualRemaining.add((committed - burned).clamp(0, committed));
    }
  }

  return SprintReport(
    sprintName: title == null ? boardTitle : '$title · $boardTitle',
    dateRange: dateRange,
    daysRemaining: daysRemaining,
    totalTickets: current.length,
    pointsCommitted: committed,
    repoCount: current.map((i) => i.repo).where((r) => r.isNotEmpty).toSet().length,
    forecastLabel: forecastLabel,
    forecastDetail: forecastDetail,
    behind: behind,
    pointsDone: pointsDone,
    status: slices,
    estimatedTickets: estimated.length,
    estimatedPoints: pts(estimated),
    unestimatedTickets: unestimated,
    people: people.take(8).toList(),
    peopleTickets: peopleTickets.take(8).toList(),
    epics: epics.take(6).toList(),
    burndown: Burndown(
      committedPoints: committed,
      totalDays: totalDays,
      todayDay: elapsed,
      snapshotsCaptured: actualRemaining.length,
      snapshotsTotal: totalDays + 1,
      actualRemaining: actualRemaining,
    ),
    sprintTitles: sprintTitles,
    sprintIndex: sprintIndex < 0 ? 0 : sprintIndex,
  );
}

String _statusLabel(ReportStatusKind k) => switch (k) {
  ReportStatusKind.done => 'Done',
  ReportStatusKind.inProgress => 'In progress',
  ReportStatusKind.inReview => 'In review',
  ReportStatusKind.notStarted => 'Not started',
};

/// A flattened board item for the report rollup.
class _RItem {
  _RItem({
    required this.title,
    required this.repo,
    required this.assignees,
    required this.kind,
    required this.complexity,
    required this.iterationTitle,
    required this.iterationStart,
    required this.iterationDuration,
    required this.subsTotal,
    required this.subsDone,
    required this.subsPercent,
    required this.closed,
    required this.closedAt,
  });

  final String title;
  final String repo;
  final List<String> assignees;
  final bool closed;
  final DateTime? closedAt;

  /// Status mapped to a report bucket; null for Triage/Cancelled/unknown (those
  /// are excluded from the committed total and the status slices).
  final ReportStatusKind? kind;
  final num? complexity;
  final String? iterationTitle;
  final DateTime? iterationStart;
  final int? iterationDuration;
  final int subsTotal;
  final int subsDone;
  final double subsPercent;

  static _RItem? parse(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! Map<String, dynamic> || content['__typename'] != 'Issue') return null;

    ReportStatusKind? kind;
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
          if (fieldName == 'status') kind = _kindFrom(raw['name'] as String?);
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

    final subs = content['subIssuesSummary'] as Map<String, dynamic>?;

    return _RItem(
      title: (content['title'] as String?) ?? '',
      repo: (content['repository']?['name'] as String?) ?? '',
      assignees: assignees,
      kind: kind,
      complexity: complexity,
      iterationTitle: iterationTitle,
      iterationStart: iterationStart,
      iterationDuration: iterationDuration,
      subsTotal: (subs?['total'] as num?)?.toInt() ?? 0,
      subsDone: (subs?['completed'] as num?)?.toInt() ?? 0,
      subsPercent: (subs?['percentCompleted'] as num?)?.toDouble() ?? 0,
      closed: (content['closed'] as bool?) ?? false,
      closedAt: DateTime.tryParse((content['closedAt'] as String?) ?? ''),
    );
  }

  static ReportStatusKind? _kindFrom(String? name) => switch (name) {
    'Not Started' => ReportStatusKind.notStarted,
    'In Progress' => ReportStatusKind.inProgress,
    'In Review' => ReportStatusKind.inReview,
    'Done' => ReportStatusKind.done,
    _ => null, // Triage / Cancelled / unknown — excluded
  };
}
