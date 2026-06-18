// test/features/projects_board/presentation/board_palette_test.dart
//
// Test summary:
// - columnAccent matches the mockup's per-status accent colors.
// - ciDot / reviewDot map states to the design's signal colors.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/helpers/board_palette.dart';

void main() {
  test('column accents match the mockup', () {
    expect(BoardPalette.columnAccent(IssueStatus.inProgress), const Color(0xFF0073FF));
    expect(BoardPalette.columnAccent(IssueStatus.done), const Color(0xFF54AE39));
    expect(BoardPalette.columnAccent(IssueStatus.triage), const Color(0xFFBABBBF));
  });

  test('ci and review dots map to signal colors', () {
    expect(BoardPalette.ciDot(PrCiState.failing), const Color(0xFFE94A5F));
    expect(BoardPalette.ciDot(PrCiState.passing), const Color(0xFF54AE39));
    expect(BoardPalette.reviewDot(PrReviewState.changesRequested), const Color(0xFFE94A5F));
    expect(BoardPalette.reviewDot(PrReviewState.none), const Color(0xFF45454C));
  });
}
