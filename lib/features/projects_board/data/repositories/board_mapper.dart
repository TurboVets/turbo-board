// Pure transform from raw ProjectV2 `items.nodes` into ProjectBoardData.
// IO-free so it unit-tests with fixture JSON. Handles both Issue and
// PullRequest content; cancelled items are dropped and unknown statuses fall
// into Not Started.
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/data/repositories/cockpit_mapper.dart' show stuckAfterDays;
import '../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../models/board_data.dart';

/// [iterations] is the Sprint field's full iteration config (oldest → newest,
/// from the project `fields`); when supplied it defines the catalog so empty
/// future iterations still appear. When empty (mock/tests) the catalog is
/// derived from the iteration values present on the items.
ProjectBoardData boardFromProjectItems(
  String title,
  List<Map<String, dynamic>> nodes, {
  required DateTime now,
  List<Map<String, dynamic>> iterations = const [],
}) {
  final cards = nodes.map((n) => _parseCard(n, now)).whereType<BoardCard>().toList();
  final sprints = iterations.isNotEmpty ? _sprintsFromConfig(iterations, now) : _sprintsFromItems(nodes, now);
  return ProjectBoardData(title: title, columns: _columnsFrom(cards), sprints: sprints);
}

/// Returns a copy of [board] with every column filtered to the items in the
/// iteration titled [sprintTitle] (facts recomputed). A null title (the "All
/// Tasks" tab) returns the board unchanged.
ProjectBoardData boardForSprint(ProjectBoardData board, String? sprintTitle) {
  if (sprintTitle == null) return board;
  final kept = board.columns.expand((c) => c.cards).where((c) => c.sprint == sprintTitle).toList();
  return board.copyWith(columns: _columnsFrom(kept));
}

/// Resolves a [SprintTab] to the iteration title it filters by, using the
/// board's sprint catalog. Returns null for "All Tasks" and for a relative tab
/// (previous/next) that has no neighbouring iteration.
String? sprintTitleForTab(List<BoardSprint> sprints, SprintTab tab) {
  if (tab == SprintTab.all || sprints.isEmpty) return null;
  final currentIdx = sprints.indexWhere((s) => s.isCurrent);
  if (currentIdx < 0) return null;
  final idx = switch (tab) {
    SprintTab.current => currentIdx,
    SprintTab.previous => currentIdx - 1,
    SprintTab.next => currentIdx + 1,
    SprintTab.all => -1,
  };
  if (idx < 0 || idx >= sprints.length) return null;
  return sprints[idx].title;
}

List<BoardColumn> _columnsFrom(List<BoardCard> cards) => [
  for (final status in boardColumnOrder)
    BoardColumn(
      status: status,
      label: CockpitPalette.statusLabel(status),
      cards: cards.where((c) => c.status == status).toList(),
      facts: _factsFor(cards.where((c) => c.status == status).toList()),
    ),
];

/// Builds the catalog from the Sprint field's iteration config (each entry has
/// `title` / `startDate` / `duration`). Authoritative — includes iterations no
/// item is assigned to yet, such as the upcoming "next" sprint.
List<BoardSprint> _sprintsFromConfig(List<Map<String, dynamic>> iterations, DateTime now) {
  final starts = <String, DateTime>{};
  final durations = <String, int>{};
  for (final it in iterations) {
    final title = it['title'] as String?;
    final start = DateTime.tryParse((it['startDate'] as String?) ?? '');
    if (title == null || start == null) continue;
    starts.putIfAbsent(title, () => start);
    durations.putIfAbsent(title, () => (it['duration'] as num?)?.toInt() ?? 14);
  }
  return _buildCatalog(starts, durations, now);
}

/// Fallback catalog derived from the iteration values present on the items.
/// Used for mock data and tests where no field config is supplied; misses
/// iterations with no assigned items. Mirrors `sprint_report_mapper`.
List<BoardSprint> _sprintsFromItems(List<Map<String, dynamic>> nodes, DateTime now) {
  final starts = <String, DateTime>{};
  final durations = <String, int>{};
  for (final node in nodes) {
    for (final raw in (node['fieldValues']?['nodes'] as List<dynamic>?) ?? const []) {
      if (raw is! Map<String, dynamic> || raw['__typename'] != 'ProjectV2ItemFieldIterationValue') continue;
      if ((raw['field']?['name'] as String?)?.toLowerCase() != 'sprint') continue;
      final title = raw['title'] as String?;
      final start = DateTime.tryParse((raw['startDate'] as String?) ?? '');
      if (title == null || start == null) continue;
      starts.putIfAbsent(title, () => start);
      durations.putIfAbsent(title, () => (raw['duration'] as num?)?.toInt() ?? 14);
    }
  }
  return _buildCatalog(starts, durations, now);
}

/// Orders sprints oldest → newest and flags the one whose window contains [now].
List<BoardSprint> _buildCatalog(Map<String, DateTime> starts, Map<String, int> durations, DateTime now) {
  final titles = starts.keys.toList()..sort((a, b) => starts[a]!.compareTo(starts[b]!));
  return [
    for (final t in titles)
      BoardSprint(
        title: t,
        start: starts[t]!,
        durationDays: durations[t]!,
        isCurrent: !now.isBefore(starts[t]!) && now.isBefore(starts[t]!.add(Duration(days: durations[t]!))),
      ),
  ];
}

ColumnFacts _factsFor(List<BoardCard> cards) => ColumnFacts(
  p0Unowned: cards.where((c) => c.priority == IssuePriority.p0 && c.assignees.isEmpty).length,
  missingEstimate: cards.where((c) => c.points == null).length,
  stuckCount: cards.where((c) => c.isStale).length,
  ciRedNumbers: cards.where((c) => c.ciState == PrCiState.failing).map((c) => c.number).toList(),
);

BoardCard? _parseCard(Map<String, dynamic> node, DateTime now) {
  final content = node['content'];
  if (content is! Map<String, dynamic>) return null;
  final typename = content['__typename'];
  final isPr = typename == 'PullRequest';
  if (typename != 'Issue' && !isPr) return null;

  // Field values (Status / Priority / Complexity / Sprint).
  IssueStatus? status;
  IssuePriority? priority;
  num? complexity;
  String? sprint;
  for (final raw in (node['fieldValues']?['nodes'] as List<dynamic>?) ?? const []) {
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
        if (fieldName == 'sprint') sprint = raw['title'] as String?;
    }
  }
  if (status == IssueStatus.cancelled) return null;

  final repo = content['repository']?['name'] as String? ?? '';
  final owner = content['repository']?['owner']?['login'] as String?;
  final assignees = ((content['assignees']?['nodes'] as List<dynamic>?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((a) => a['login'] as String?)
      .whereType<String>()
      .toList();
  final sub = content['subIssuesSummary'];
  final subTotal = sub is Map<String, dynamic> ? (sub['total'] as num?)?.toInt() : null;
  final subDone = sub is Map<String, dynamic> ? (sub['completed'] as num?)?.toInt() : null;

  final updatedAt = DateTime.tryParse((node['updatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  final age = now.difference(updatedAt).inDays.clamp(0, 9999);

  return BoardCard(
    id: '$owner/$repo#${(content['number'] as num?)?.toInt() ?? 0}',
    type: isPr ? BoardItemType.pullRequest : BoardItemType.issue,
    repo: repo,
    number: (content['number'] as num?)?.toInt() ?? 0,
    title: (content['title'] as String?) ?? '',
    isDraft: isPr && (content['isDraft'] as bool? ?? false),
    status: status ?? IssueStatus.notStarted,
    priority: priority,
    points: complexity?.round(),
    subDone: subDone,
    subTotal: subTotal,
    staleDays: age >= stuckAfterDays ? age : null,
    assignees: assignees,
    ciState: isPr ? _ciFrom(content) : null,
    reviewState: isPr ? _reviewFrom(content['reviewDecision'] as String?) : null,
    owner: owner,
    sprint: sprint,
  );
}

PrCiState _ciFrom(Map<String, dynamic> content) {
  final nodes = content['commits']?['nodes'] as List<dynamic>?;
  final state = (nodes?.lastOrNull as Map<String, dynamic>?)?['commit']?['statusCheckRollup']?['state'] as String?;
  return switch (state) {
    'SUCCESS' => PrCiState.passing,
    'FAILURE' || 'ERROR' => PrCiState.failing,
    'PENDING' || 'EXPECTED' => PrCiState.pending,
    _ => PrCiState.none,
  };
}

PrReviewState _reviewFrom(String? decision) => switch (decision) {
  'APPROVED' => PrReviewState.approved,
  'CHANGES_REQUESTED' => PrReviewState.changesRequested,
  'REVIEW_REQUIRED' => PrReviewState.review,
  _ => PrReviewState.none,
};

IssueStatus? _statusFrom(String? name) {
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

IssuePriority? _priorityFrom(String? name) {
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
