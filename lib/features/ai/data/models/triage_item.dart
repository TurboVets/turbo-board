import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../shared/ui/theme/tb_tokens.dart';

part 'triage_item.freezed.dart';

/// The action class the model assigns to a triaged PR. Drives the chip's
/// label and signal color (mirrors the design's REVIEW FIRST / UNBLOCK /
/// MERGE / NUDGE / WATCH chips).
enum TriageCategory {
  reviewFirst,
  unblock,
  merge,
  nudge,
  watch;

  /// Parses the model's snake_case category, defaulting to [watch].
  static TriageCategory fromWire(String? value) => switch (value?.trim().toLowerCase()) {
    'review_first' || 'review first' || 'reviewfirst' => TriageCategory.reviewFirst,
    'unblock' => TriageCategory.unblock,
    'merge' => TriageCategory.merge,
    'nudge' => TriageCategory.nudge,
    _ => TriageCategory.watch,
  };

  String get chipLabel => switch (this) {
    TriageCategory.reviewFirst => 'REVIEW FIRST',
    TriageCategory.unblock => 'UNBLOCK',
    TriageCategory.merge => 'MERGE',
    TriageCategory.nudge => 'NUDGE',
    TriageCategory.watch => 'WATCH',
  };

  TbSignal get signal => switch (this) {
    TriageCategory.reviewFirst => TbSignal.info,
    TriageCategory.unblock => TbSignal.bad,
    TriageCategory.merge => TbSignal.ok,
    TriageCategory.nudge => TbSignal.orange,
    TriageCategory.watch => TbSignal.gray,
  };
}

/// One ranked row in the AI Board Triage pane. Carries enough to render the
/// row and to open the matching PR detail (repo + number).
@freezed
sealed class TriageItem with _$TriageItem {
  const factory TriageItem({
    required int rank,

    /// "owner/name"
    required String repo,
    required int number,
    required String title,
    required String reason,
    required TriageCategory category,

    /// Relative "updated" label (e.g. "3d", "5h") for the trailing column.
    required String updatedLabel,
  }) = _TriageItem;
}
