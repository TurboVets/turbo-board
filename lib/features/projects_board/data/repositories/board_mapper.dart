// Pure transform from raw ProjectV2 `items.nodes` into ProjectBoardData.
// IO-free so it unit-tests with fixture JSON. Handles both Issue and
// PullRequest content; cancelled items are dropped and unknown statuses fall
// into Not Started.
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/data/repositories/cockpit_mapper.dart' show stuckAfterDays;
import '../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../models/board_data.dart';

ProjectBoardData boardFromProjectItems(String title, List<Map<String, dynamic>> nodes, {required DateTime now}) {
  final cards = nodes.map((n) => _parseCard(n, now)).whereType<BoardCard>().toList();

  final columns = <BoardColumn>[];
  for (final status in boardColumnOrder) {
    final inCol = cards.where((c) => c.status == status).toList();
    columns.add(
      BoardColumn(status: status, label: CockpitPalette.statusLabel(status), cards: inCol, facts: _factsFor(inCol)),
    );
  }
  return ProjectBoardData(title: title, columns: columns);
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

  // Field values (Status / Priority / Complexity).
  IssueStatus? status;
  IssuePriority? priority;
  num? complexity;
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
