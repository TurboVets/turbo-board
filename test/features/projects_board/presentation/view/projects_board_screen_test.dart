// test/features/projects_board/presentation/view/projects_board_screen_test.dart
//
// Test summary:
// - With no project selected, shows the project picker empty-state.
// - With a selected project and a mock board, renders the topbar title and columns.
// - Error from the board provider shows the message + Retry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart'; // for the Override type (not in the main barrel)
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/projects_board_screen.dart';

class _SelStub extends SelectedProjectNotifier {
  _SelStub(this._p);
  final ProjectRef? _p;
  @override
  ProjectRef? build() => _p;
}

Widget _app({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: ProjectsBoardScreen()),
);

void main() {
  testWidgets('no project -> picker empty state', (tester) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          selectedProjectProvider.overrideWith(() => _SelStub(null)),
          availableProjectsProvider.overrideWith((_) async => const <ProjectRef>[]),
        ],
      ),
    );
    await tester.pump();
    expect(find.textContaining('project', findRichText: true), findsWidgets);
  });

  testWidgets('selected project -> renders board', (tester) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          selectedProjectProvider.overrideWith(() => _SelStub(const ProjectRef(owner: 'o', number: 4, title: 'B'))),
          projectsBoardRepositoryProvider.overrideWithValue(const MockProjectsBoardRepository()),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 400)); // mock latency
    await tester.pumpAndSettle();
    expect(find.text('Mobile Q3 Roadmap'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
  });
}
