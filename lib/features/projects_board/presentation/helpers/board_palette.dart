import 'package:flutter/widgets.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../data/models/board_data.dart';

/// Board-specific colors: column top accents and PR CI/review dots.
/// Verbatim from `Projects Board.dc.html`.
abstract final class BoardPalette {
  static Color columnAccent(IssueStatus status) => switch (status) {
    IssueStatus.triage => const Color(0xFFBABBBF),
    IssueStatus.notStarted => const Color(0xFF6E6E76),
    IssueStatus.inProgress => const Color(0xFF0073FF),
    IssueStatus.inReview => const Color(0xFFFFB000),
    IssueStatus.done => const Color(0xFF54AE39),
    IssueStatus.cancelled => const Color(0xFF45454C),
  };

  static Color ciDot(PrCiState state) => switch (state) {
    PrCiState.passing => const Color(0xFF54AE39),
    PrCiState.failing => const Color(0xFFE94A5F),
    PrCiState.pending => const Color(0xFFFFB000),
    PrCiState.none => const Color(0xFF45454C),
  };

  static Color reviewDot(PrReviewState state) => switch (state) {
    PrReviewState.approved => const Color(0xFF54AE39),
    PrReviewState.changesRequested => const Color(0xFFE94A5F),
    PrReviewState.review => const Color(0xFFBABBBF),
    PrReviewState.none => const Color(0xFF45454C),
  };
}
