// test/features/pr_detail/presentation/view/widgets/markdown_body_test.dart
//
// Test summary:
// - renders plain text content from markdown.
// - empty markdown renders nothing (SizedBox.shrink).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/markdown_body.dart';

void main() {
  testWidgets('renders text from markdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarkdownBody('Hello world'))));
    expect(find.textContaining('Hello world'), findsOneWidget);
  });

  testWidgets('empty markdown renders nothing visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarkdownBody('   '))));
    expect(find.byType(SizedBox), findsWidgets);
  });
}
