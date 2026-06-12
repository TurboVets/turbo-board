// lib/features/pr_detail/data/models/pr_detail.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../pr_inbox/data/models/pr_data.dart' show PrReviewState;
import 'pr_check.dart';
import 'pr_commit.dart';
import 'pr_reviewer.dart';
import 'pr_timeline_event.dart';

part 'pr_detail.freezed.dart';

enum PrState { open, closed, merged }

@freezed
sealed class PrDetail with _$PrDetail {
  const PrDetail._();

  const factory PrDetail({
    required String repo, // "owner/name"
    String? id, // GraphQL node id — needed to post comments / reviews
    required int number,
    required String title,
    String? url, // PR page on github.com

    required PrState state,
    @Default(false) bool isDraft,
    required String author,
    required String baseRefName,
    required String headRefName,
    @Default('') String bodyMarkdown,
    PrReviewState? reviewDecision,
    PrCommit? lastCommit,
    @Default([]) List<PrCheck> checks,
    @Default([]) List<PrReviewer> reviewers,
    @Default([]) List<PrTimelineEvent> timeline,
  }) = _PrDetail;

  String get slug => '$repo#$number';
}
