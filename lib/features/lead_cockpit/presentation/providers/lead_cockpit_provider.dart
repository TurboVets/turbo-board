import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_core/core.dart';

import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/cockpit_data.dart';
import '../../data/repositories/lead_cockpit_repository.dart';

part 'lead_cockpit_provider.g.dart';

const _selectedProjectKey = 'lead_cockpit_project';
const _reportPrefix = 'cockpit_ai_report|';

/// Persisted cache of generated cockpit AI reports, keyed by
/// `cockpit_ai_report|<projectKey>|<reportName>`. Hydrated once from
/// shared_preferences; a generated report is stored here so reopening the
/// dialog shows the last result instead of regenerating. Survives restarts.
@Riverpod(keepAlive: true)
class CockpitReports extends _$CockpitReports {
  @override
  Future<Map<String, String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith(_reportPrefix) && prefs.getString(key) != null) key: prefs.getString(key)!,
    };
  }

  String _key(String projectKey, String report) => '$_reportPrefix$projectKey|$report';

  /// The cached report text for the project + report, or null if none stored.
  String? cached(String projectKey, String report) => state.asData?.value[_key(projectKey, report)];

  /// Stores [text] for the project + report, updating the in-memory map and
  /// shared_preferences. Prefs failures are swallowed (the in-memory cache still
  /// updates) so a storage hiccup never breaks report display.
  Future<void> write(String projectKey, String report, String text) async {
    final key = _key(projectKey, report);
    state = AsyncData({...?state.asData?.value, key: text});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, text);
    } catch (_) {
      // In-memory cache is updated; persistence is best-effort.
    }
  }
}

/// The GitHub Projects v2 board the cockpit reads, persisted to
/// shared_preferences. `null` means "not picked yet" — the cockpit shows a
/// picker, and Settings lets the user change it.
@Riverpod(keepAlive: true)
class SelectedProjectNotifier extends _$SelectedProjectNotifier {
  @override
  ProjectRef? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_selectedProjectKey);
    if (raw == null) return;
    try {
      state = ProjectRef.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt value — ignore and stay unselected.
    }
  }

  Future<void> select(ProjectRef project) async {
    state = project;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProjectKey, jsonEncode(project.toJson()));
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedProjectKey);
  }
}

@Riverpod(keepAlive: true)
LeadCockpitRepository leadCockpitRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final selected = ref.watch(selectedProjectProvider);
  return GithubLeadCockpitRepository(client, org: selected?.owner ?? '', projectNumber: selected?.number ?? 0);
}

/// The Projects v2 boards the user can pick from (own + org boards).
@riverpod
Future<List<ProjectRef>> availableProjects(Ref ref) async {
  final result = await ref.watch(leadCockpitRepositoryProvider).listProjects();
  return result.when(success: (data) => data, failure: (message, _) => throw Exception(message));
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

/// On-demand AI sprint brief for the Lead Cockpit. `null` means "not requested
/// yet"; reuses the BYOK Anthropic client behind [aiRepositoryProvider].
@riverpod
class CockpitBriefController extends _$CockpitBriefController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(CockpitData cockpit) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).sprintBrief(cockpit);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand AI daily standup for the Lead Cockpit. `null` means "not requested
/// yet"; reuses the BYOK Anthropic client behind [aiRepositoryProvider].
@riverpod
class DailyStandupController extends _$DailyStandupController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(CockpitData cockpit) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).dailyStandup(cockpit);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
