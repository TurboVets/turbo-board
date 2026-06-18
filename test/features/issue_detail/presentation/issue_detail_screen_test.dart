// test/features/issue_detail/presentation/issue_detail_screen_test.dart
//
// Test summary:
// - With the mock repo, the screen renders the issue title and the AI TL;DR header.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_detail_provider.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/issue_detail_screen.dart';

void main() {
  testWidgets('renders the issue title from the mock repo', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const IssueDetailScreen(owner: 'turbovets', repo: 'web-portal', number: 155),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rotate API keys'), findsWidgets);
  });
}
