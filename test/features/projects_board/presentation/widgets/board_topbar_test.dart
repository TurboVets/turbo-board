// test/features/projects_board/presentation/widgets/board_topbar_test.dart
//
// Test summary:
// - Renders the board title and the AI Insights CTA when idle (insights == null).
// - Tapping the CTA calls BoardInsightsController.generate (state leaves null).
// - While loading, the CTA shows a CircularProgressIndicator and onPressed is null (disabled).
// - When data is present, the CTA shows "Regenerate".
// - When an error is present, the CTA shows "Retry".
//
// NOTE: Picker side-effect and refresh tests are skipped — the picker opens a
// dialog hosting ProjectPickerList which hits availableProjectsProvider, requiring
// heavy network/provider scaffolding beyond the scope of this unit test file.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_topbar.dart';

const _board = ProjectBoardData(title: 'Mobile Q3 Roadmap');

// The topbar watches projectsBoardProvider to drive the refresh-button spinner.
// Supply settled board data so isRefreshing is false; these tests target the AI CTA.
final _boardOverride = projectsBoardProvider.overrideWith((ref) => _board);

class _RecordingInsights extends BoardInsightsController {
  static int calls = 0;
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => null;
  @override
  Future<void> generate(ProjectBoardData board) async => calls++;
}

class _LoadingInsights extends BoardInsightsController {
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => const AsyncValue.loading();
}

class _DataInsights extends BoardInsightsController {
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => AsyncValue.data({IssueStatus.inProgress: 'x'});
}

class _ErrorInsights extends BoardInsightsController {
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => AsyncValue.error('nope', StackTrace.empty);
}

void main() {
  testWidgets('renders title and AI CTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_boardOverride],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mobile Q3 Roadmap'), findsOneWidget);
    expect(find.textContaining('AI Insights'), findsOneWidget);
  });

  testWidgets('CTA triggers generate', (tester) async {
    _RecordingInsights.calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_boardOverride, boardInsightsControllerProvider.overrideWith(_RecordingInsights.new)],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.tap(find.textContaining('AI Insights'));
    await tester.pump();
    expect(_RecordingInsights.calls, 1);
  });

  testWidgets('loading state: shows CircularProgressIndicator and CTA is disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_boardOverride, boardInsightsControllerProvider.overrideWith(_LoadingInsights.new)],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The AI CTA OutlinedButton should have onPressed == null when loading.
    final ctaButtons = tester.widgetList<OutlinedButton>(find.byType(OutlinedButton));
    final ctaButton = ctaButtons.firstWhere((b) => b.child is SizedBox, orElse: () => ctaButtons.first);
    expect(ctaButton.onPressed, isNull);
  });

  testWidgets('data state: CTA shows Regenerate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_boardOverride, boardInsightsControllerProvider.overrideWith(_DataInsights.new)],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Regenerate'), findsOneWidget);
  });

  testWidgets('error state: CTA shows Retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_boardOverride, boardInsightsControllerProvider.overrideWith(_ErrorInsights.new)],
        child: MaterialApp(
          home: Scaffold(body: BoardTopbar(board: _board)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Retry'), findsOneWidget);
  });
}
