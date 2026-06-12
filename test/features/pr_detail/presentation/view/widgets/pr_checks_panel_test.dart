// test/features/pr_detail/presentation/view/widgets/pr_checks_panel_test.dart
//
// Test summary:
// - renders a row per check; shows the empty message when there are none.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_check.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/pr_checks_panel.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('renders a row per check', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(
          body: PrChecksPanel(
            checks: [
              PrCheck(name: 'build', state: PrCheckState.success),
              PrCheck(name: 'test', state: PrCheckState.failure),
            ],
          ),
        ),
      ),
    );
    expect(find.text('build'), findsOneWidget);
    expect(find.text('test'), findsOneWidget);
    expect(find.text('Checks'), findsOneWidget);
  });

  testWidgets('shows empty message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(body: PrChecksPanel(checks: [])),
      ),
    );
    expect(find.textContaining('No checks'), findsOneWidget);
  });
}
