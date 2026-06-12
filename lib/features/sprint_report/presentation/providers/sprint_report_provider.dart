import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/sprint_report.dart';
import '../../data/repositories/sprint_report_repository.dart';

part 'sprint_report_provider.g.dart';

// The board this report reads — same as the Lead Cockpit. TODO: make
// configurable in Settings once multi-board support is needed.
const String _boardOrg = 'TurboVets';
const int _boardNumber = 8; // "Mobile Space"

@Riverpod(keepAlive: true)
SprintReportRepository sprintReportRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  return GithubSprintReportRepository(client, org: _boardOrg, projectNumber: _boardNumber);
}

/// The sprint iteration the report is showing, by title. Null = the current
/// sprint (the iteration whose window contains today). Driven by the header's
/// prev/next controls.
@Riverpod(keepAlive: true)
class SelectedSprint extends _$SelectedSprint {
  @override
  String? build() => null;

  void select(String? title) => state = title;
}

@riverpod
Future<SprintReport> sprintReport(Ref ref) async {
  final selected = ref.watch(selectedSprintProvider);
  final result = await ref.watch(sprintReportRepositoryProvider).fetchReport(sprintTitle: selected);
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
