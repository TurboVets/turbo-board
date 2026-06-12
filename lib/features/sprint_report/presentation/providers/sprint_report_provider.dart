import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/sprint_report.dart';
import '../../data/repositories/sprint_report_repository.dart';

part 'sprint_report_provider.g.dart';

@Riverpod(keepAlive: true)
SprintReportRepository sprintReportRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  // Same board the Lead Cockpit reads — chosen in the cockpit / Settings.
  final selected = ref.watch(selectedProjectProvider);
  return GithubSprintReportRepository(client, org: selected?.owner ?? '', projectNumber: selected?.number ?? 0);
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
  return result.when(
    success: (data) {
      if (ref.mounted) {
        ref.keepAlive();
      }
      return data;
    },
    failure: (message, st) => throw Exception(message),
  );
}
