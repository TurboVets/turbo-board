// Test summary:
// - Renders the section header, legend and a tile per sprint day.
// - Each day tile shows its done (✓) and opened (+) counts.
// - Tapping a past day opens the detail popup listing that day's tickets.
// - Each ticket row in the popup shows the assignee's avatar (when assigned).
// - An all-zero flow shows the empty-state message instead of the chart/strip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/view/widgets/sprint_flow_section.dart';
import 'package:turbo_board/shared/ui/widgets/tb_badge.dart';

final _today = DateTime(2026, 6, 23);

SprintFlow _flow() => SprintFlow(
  start: DateTime(2026, 6, 22),
  end: DateTime(2026, 6, 25),
  days: [
    FlowDay(
      date: DateTime(2026, 6, 22),
      done: 2,
      opened: 1,
      doneTickets: const [
        FlowTicket(number: '#412', title: 'Fix deeplink cold-start routes', repo: 'mobile', assignee: 'snguyen-tv'),
        FlowTicket(
          number: '#418',
          title: 'Token refresh race',
          repo: 'mobile-shared-components',
          assignee: 'apatel-tv',
        ),
      ],
    ),
    FlowDay(date: DateTime(2026, 6, 23), done: 1, opened: 0),
    FlowDay(date: DateTime(2026, 6, 24)),
  ],
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('renders header, legend and per-day counts', (tester) async {
    await tester.pumpWidget(_host(SprintFlowSection(flow: _flow(), today: _today)));

    expect(find.text('SPRINT FLOW · DAILY ACTIVITY'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('OPENED'), findsOneWidget);
    // Mon 22: done 2 / opened 1.
    expect(find.text('2'), findsWidgets);
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('tapping a day opens the detail popup with its tickets', (tester) async {
    await tester.pumpWidget(_host(SprintFlowSection(flow: _flow(), today: _today)));

    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();

    expect(find.text('2 DONE · 1 OPENED'), findsOneWidget);
    expect(find.text('#412'), findsOneWidget);
    expect(find.text('Fix deeplink cold-start routes'), findsOneWidget);
    // Each done ticket row shows its assignee avatar.
    expect(find.byType(TbAvatarTile), findsNWidgets(2));
  });

  testWidgets('shows empty state when there is no activity', (tester) async {
    final empty = SprintFlow(
      start: DateTime(2026, 6, 22),
      end: DateTime(2026, 6, 24),
      days: [
        FlowDay(date: DateTime(2026, 6, 22)),
        FlowDay(date: DateTime(2026, 6, 23)),
      ],
    );
    await tester.pumpWidget(_host(SprintFlowSection(flow: empty, today: _today)));

    expect(find.text('No activity recorded this sprint yet.'), findsOneWidget);
    expect(find.text('DAILY ACTIVITY'), findsNothing);
  });
}
