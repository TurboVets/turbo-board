// test/features/ai/presentation/view/widgets/ai_narrative_card_test.dart
//
// Test summary:
// - idle (null state): shows the title + uppercased idle pill, no body; tap fires onGenerate.
// - loading: shows the skeleton, hides the pill.
// - data (prose): renders the narrative text + a HIDE pill + provenance caption.
// - data (bullets): renders each bullet line's text.
// - error: shows the message + a RETRY pill; tap fires onGenerate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/ai/presentation/view/widgets/ai_narrative_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
  theme: getAppTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('idle shows title + pill and fires onGenerate', (tester) async {
    var generated = false;
    await tester.pumpWidget(
      _host(
        AiNarrativeCard(
          title: 'AI Sprint Summary',
          idleLabel: 'Summarize sprint',
          state: null,
          onGenerate: () => generated = true,
          onHide: () {},
        ),
      ),
    );
    expect(find.text('AI SPRINT SUMMARY'), findsOneWidget);
    expect(find.text('SUMMARIZE SPRINT'), findsOneWidget);
    await tester.tap(find.text('SUMMARIZE SPRINT'));
    expect(generated, isTrue);
  });

  testWidgets('loading shows skeleton, hides pill', (tester) async {
    await tester.pumpWidget(
      _host(
        const AiNarrativeCard(
          title: 'AI Sprint Summary',
          idleLabel: 'Summarize sprint',
          state: AsyncValue.loading(),
          onGenerate: _noop,
          onHide: _noop,
        ),
      ),
    );
    expect(find.byKey(const Key('ai-narrative-skeleton')), findsOneWidget);
    expect(find.text('SUMMARIZE SPRINT'), findsNothing);
  });

  testWidgets('data (prose) renders text + HIDE + caption', (tester) async {
    await tester.pumpWidget(
      _host(
        const AiNarrativeCard(
          title: 'AI Sprint Summary',
          idleLabel: 'Summarize sprint',
          state: AsyncValue.data('Sprint 24 is trending behind.'),
          onGenerate: _noop,
          onHide: _noop,
        ),
      ),
    );
    expect(find.textContaining('trending behind'), findsOneWidget);
    expect(find.text('HIDE'), findsOneWidget);
    expect(find.textContaining('claude-haiku'), findsOneWidget);
  });

  testWidgets('data (bullets) renders each bullet', (tester) async {
    await tester.pumpWidget(
      _host(
        const AiNarrativeCard(
          title: 'AI Sprint Digest',
          idleLabel: 'Sprint digest',
          state: AsyncValue.data('- Shipped 30 tickets\n- 3 at risk'),
          onGenerate: _noop,
          onHide: _noop,
        ),
      ),
    );
    expect(find.textContaining('Shipped 30 tickets'), findsOneWidget);
    expect(find.textContaining('3 at risk'), findsOneWidget);
  });

  testWidgets('error shows message + RETRY and fires onGenerate', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        AiNarrativeCard(
          title: 'AI Sprint Summary',
          idleLabel: 'Summarize sprint',
          state: AsyncValue.error('boom', StackTrace.empty),
          onGenerate: () => retried = true,
          onHide: () {},
        ),
      ),
    );
    expect(find.textContaining('boom'), findsOneWidget);
    await tester.tap(find.text('RETRY'));
    expect(retried, isTrue);
  });
}

void _noop() {}
