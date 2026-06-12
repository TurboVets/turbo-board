import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../data/models/sprint_report.dart';
import '../../data/repositories/sprint_report_repository.dart';

part 'sprint_report_provider.g.dart';

@Riverpod(keepAlive: true)
SprintReportRepository sprintReportRepository(Ref ref) => const MockSprintReportRepository();

@riverpod
Future<SprintReport> sprintReport(Ref ref) async {
  final result = await ref.watch(sprintReportRepositoryProvider).fetchReport();
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
