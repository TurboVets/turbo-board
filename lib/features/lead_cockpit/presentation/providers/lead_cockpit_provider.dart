import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/cockpit_data.dart';
import '../../data/repositories/lead_cockpit_repository.dart';

part 'lead_cockpit_provider.g.dart';

// The board this cockpit reads. TODO: make configurable in Settings (org +
// project number) once multi-board support is needed.
const String _boardOrg = 'TurboVets';
const int _boardNumber = 8; // "Mobile Space"

@Riverpod(keepAlive: true)
LeadCockpitRepository leadCockpitRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  return GithubLeadCockpitRepository(client, org: _boardOrg, projectNumber: _boardNumber);
}

@riverpod
Future<CockpitData> leadCockpit(Ref ref) async {
  final repo = ref.watch(leadCockpitRepositoryProvider);
  final result = await repo.fetchCockpit();
  return result.when(
    success: (data) {
      // Guard: the autodispose provider may already be torn down after the
      // await if nothing is listening (e.g. a one-shot `.future` read in tests).
      if (ref.mounted) ref.keepAlive();
      return data;
    },
    failure: (message, stackTrace) => throw Exception(message),
  );
}
