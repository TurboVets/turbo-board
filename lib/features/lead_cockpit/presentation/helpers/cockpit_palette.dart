import 'package:flutter/widgets.dart';

import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../data/models/cockpit_data.dart';

/// Maps cockpit issue statuses and priorities to the design's exact colors and
/// labels. Color/label choices are a presentation concern, so they live here
/// rather than on the data models.
abstract final class CockpitPalette {
  /// Status signal-dot color (verbatim from `TurboBoard.dc.html` `DOT` map).
  static Color statusDot(IssueStatus status) => switch (status) {
    IssueStatus.done => const Color(0xFF54AE39), // green
    IssueStatus.inProgress => const Color(0xFF13ACFF), // cyan/blue
    IssueStatus.inReview => const Color(0xFFFFB000), // amber
    IssueStatus.triage => const Color(0xFFFF5A1F), // orange
    IssueStatus.notStarted => const Color(0xFFBABBBF), // gray
    IssueStatus.cancelled => TbColors.dim,
  };

  /// Human label for a status, matching the board's single-select option names.
  static String statusLabel(IssueStatus status) => switch (status) {
    IssueStatus.notStarted => 'Not Started',
    IssueStatus.inProgress => 'In Progress',
    IssueStatus.inReview => 'In Review',
    IssueStatus.triage => 'Triage',
    IssueStatus.done => 'Done',
    IssueStatus.cancelled => 'Cancelled',
  };

  /// Priority chip recipe (`PRI` map: P0→bad, P1→orange, P2→warn, P3→gray).
  static TbSignal prioritySignal(IssuePriority priority) => switch (priority) {
    IssuePriority.p0 => TbSignal.bad,
    IssuePriority.p1 => TbSignal.orange,
    IssuePriority.p2 => TbSignal.warn,
    IssuePriority.p3 => TbSignal.gray,
  };

  static String priorityLabel(IssuePriority priority) => switch (priority) {
    IssuePriority.p0 => 'P0',
    IssuePriority.p1 => 'P1',
    IssuePriority.p2 => 'P2',
    IssuePriority.p3 => 'P3',
  };

  /// Hover explanation for a priority chip.
  static String priorityTooltip(IssuePriority priority) => switch (priority) {
    IssuePriority.p0 => 'P0 — critical, drop everything',
    IssuePriority.p1 => 'P1 — high priority',
    IssuePriority.p2 => 'P2 — normal priority',
    IssuePriority.p3 => 'P3 — low priority',
  };

  /// Load-gauge fill color by fill percent: green (healthy) / amber (busy) /
  /// red (overloaded). Thresholds verbatim from `TurboBoard.dc.html`.
  static Color gaugeColor(int gaugePercent) {
    if (gaugePercent >= 85) return const Color(0xFFE94A5F);
    if (gaugePercent >= 60) return const Color(0xFFFFB000);
    return const Color(0xFF54AE39);
  }

  /// Story-point capacity assumed per person per sprint (the `40PT CAP` scale).
  static const int pointsCapacity = 40;
}
