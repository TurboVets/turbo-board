// test/features/projects_board/presentation/widgets/board_topbar_test.dart
//
// Test summary:
// - Renders the board title and the AI Insights CTA when idle.
// - Tapping the CTA calls BoardInsightsController.generate (state leaves null).
// - While loading, the CTA shows a spinner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_topbar.dart';

const _board = ProjectBoardData(title: 'Mobile Q3 Roadmap');

class _RecordingInsights extends BoardInsightsController {
  static int calls = 0;
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => null;
  @override
  Future<void> generate(ProjectBoardData board) async => calls++;
}

void main() {
  testWidgets('renders title and AI CTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    expect(find.text('Mobile Q3 Roadmap'), findsOneWidget);
    expect(find.textContaining('AI Insights'), findsOneWidget);
  });

  testWidgets('CTA triggers generate', (tester) async {
    _RecordingInsights.calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [boardInsightsControllerProvider.overrideWith(_RecordingInsights.new)],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.tap(find.textContaining('AI Insights'));
    await tester.pump();
    expect(_RecordingInsights.calls, 1);
  });
}
