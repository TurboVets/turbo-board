import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../issue_detail/data/models/issue_detail.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart' as cockpit;
import '../../../pr_detail/data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../../sprint_report/data/models/sprint_narrative_report.dart';
import '../../../sprint_report/data/models/sprint_report.dart';
import '../../data/models/triage_item.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/services/ai_provider_kind.dart';
import '../../data/services/anthropic_api_client.dart';
import '../../data/services/api_key_store.dart';
import '../../data/services/llm_client.dart';
import '../../data/services/openai_api_client.dart';
import '../helpers/ai_prompts.dart';

part 'ai_provider.freezed.dart';
part 'ai_provider.g.dart';

/// State of the active provider's BYOK key.
@freezed
sealed class AiKeyState with _$AiKeyState {
  const factory AiKeyState.loading() = AiKeyLoading;
  const factory AiKeyState.missing() = AiKeyMissing;
  const factory AiKeyState.validating() = AiKeyValidating;
  const factory AiKeyState.valid() = AiKeyValid;
  const factory AiKeyState.error(String message) = AiKeyError;
}

@Riverpod(keepAlive: true)
ApiKeyStore apiKeyStore(Ref ref) => const SecureApiKeyStore();

/// The currently selected provider. Defaults to anthropic, hydrates from the
/// store on build, and persists on [set].
@Riverpod(keepAlive: true)
class ActiveAiProvider extends _$ActiveAiProvider {
  @override
  AiProvider build() {
    _hydrate();
    return AiProvider.anthropic;
  }

  Future<void> _hydrate() async {
    final stored = await ref.read(apiKeyStoreProvider).readActiveProvider();
    if (stored != null) state = stored;
  }

  Future<void> set(AiProvider provider) async {
    if (provider == state) return;
    await ref.read(apiKeyStoreProvider).writeActiveProvider(provider);
    state = provider;
  }
}

/// The LLM client for the active provider, with that provider's stored key
/// injected. Rebuilt whenever the active provider changes.
@Riverpod(keepAlive: true)
LlmClient llmClient(Ref ref) {
  final provider = ref.watch(activeAiProviderProvider);
  return switch (provider) {
    AiProvider.anthropic => AnthropicApiClient(),
    AiProvider.openai => OpenAiApiClient(),
  };
}

@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) => LlmAiRepository(ref.watch(llmClientProvider), ref.watch(githubApiClientProvider));

@Riverpod(keepAlive: true)
class AiKeyNotifier extends _$AiKeyNotifier {
  @override
  AiKeyState build() {
    // Re-init whenever the active provider changes.
    ref.watch(activeAiProviderProvider);
    _init();
    return const AiKeyState.loading();
  }

  AiProvider get _provider => ref.read(activeAiProviderProvider);

  Future<void> _init() async {
    final key = await ref.read(apiKeyStoreProvider).read(_provider);
    if (key == null || key.isEmpty) {
      state = const AiKeyState.missing();
      return;
    }
    ref.read(llmClientProvider).setKey(key);
    state = const AiKeyState.valid(); // trust the stored key; re-validated on submit
  }

  /// Validity check without persisting (the Settings "Validate" button).
  /// Returns true (valid), false (rejected 401), or null (could not check).
  Future<bool?> validate(String key) async {
    ref.read(llmClientProvider).setKey(key);
    final result = await ref.read(aiRepositoryProvider).validateKey();
    return switch (result) {
      ResultSuccess(:final data) => data,
      ResultFailure() => null,
    };
  }

  /// Validates [key]; on success persists it under the active provider and marks valid.
  Future<void> submit(String key) async {
    state = const AiKeyState.validating();
    ref.read(llmClientProvider).setKey(key);
    final result = await ref.read(aiRepositoryProvider).validateKey();
    switch (result) {
      case ResultSuccess(:final data):
        if (data) {
          await ref.read(apiKeyStoreProvider).write(_provider, key);
          state = const AiKeyState.valid();
        } else {
          ref.read(llmClientProvider).setKey(null);
          state = const AiKeyState.error('That key was rejected by the provider (401).');
        }
      case ResultFailure(:final message):
        state = AiKeyState.error(message);
    }
  }

  Future<void> clear() async {
    await ref.read(apiKeyStoreProvider).delete(_provider);
    ref.read(llmClientProvider).setKey(null);
    state = const AiKeyState.missing();
  }
}

/// True when a key is present (valid or trusted-from-storage).
@riverpod
bool aiKeyReady(Ref ref) => ref.watch(aiKeyProvider) is AiKeyValid;

/// Masked form of the active provider's stored key for display (Settings).
@riverpod
Future<String?> activeKeyMasked(Ref ref) async {
  ref.watch(aiKeyProvider); // refresh when the key is saved/removed
  final provider = ref.watch(activeAiProviderProvider);
  final key = await ref.watch(apiKeyStoreProvider).read(provider);
  return maskSecret(key);
}

/// Masks a secret to `prefix••••last4`, or null when absent.
String? maskSecret(String? secret) {
  if (secret == null || secret.isEmpty) return null;
  if (secret.length <= 12) return '••••••••';
  final prefix = secret.substring(0, 7);
  final last4 = secret.substring(secret.length - 4);
  return '$prefix••••••••$last4';
}

/// On-demand PR summary, keyed by PR slug so each detail screen has its own.
/// `null` state means "not requested yet".
@Riverpod(keepAlive: true)
class PrSummaryController extends _$PrSummaryController {
  @override
  AsyncValue<List<String>>? build(String slug) => null;

  Future<void> generate(PrDetail detail) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).summarize(detail);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }
}

/// On-demand reply draft, keyed by PR slug.
@Riverpod(keepAlive: true)
class ReplyDraftController extends _$ReplyDraftController {
  @override
  AsyncValue<String>? build(String slug) => null;

  Future<void> generate(PrDetail detail, ReplyIntent intent) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).draftReply(detail, intent);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// Board-level AI triage ranking. `null` = not run yet (idle); loading while
/// the model ranks; data holds the ranked rows. Single instance for the board.
@Riverpod(keepAlive: true)
class TriageController extends _$TriageController {
  @override
  AsyncValue<List<TriageItem>>? build() => null;

  Future<void> run(List<PrData> prs) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).triage(prs);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void dismiss() => state = null;
}

/// On-demand full sprint summary (Sprint Report). `null` = not requested yet.
@Riverpod(keepAlive: true)
class SprintSummaryController extends _$SprintSummaryController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).summarizeSprint(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand scannable sprint digest (Sprint Report). `null` = not requested.
@Riverpod(keepAlive: true)
class SprintDigestController extends _$SprintDigestController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).digestSprint(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand structured narrative Sprint Report. `null` = not requested yet.
@Riverpod(keepAlive: true)
class SprintNarrativeController extends _$SprintNarrativeController {
  @override
  AsyncValue<SprintNarrativeReport>? build() => null;

  Future<void> generate(SprintReport report) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).generateSprintReport(report);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(
        // Forecast status is deterministic — never trust the AI for it.
        data.copyWith(overallStatus: report.behind ? SprintHealth.behind : SprintHealth.onTrack),
      ),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand weekly digest (Lead Cockpit). `null` = not requested yet.
@Riverpod(keepAlive: true)
class WeeklyDigestController extends _$WeeklyDigestController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(cockpit.CockpitData cockpit) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).weeklyDigest(cockpit);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// On-demand issue TL;DR, keyed by issue slug. `null` = not requested yet.
@Riverpod(keepAlive: true)
class IssueSummaryController extends _$IssueSummaryController {
  @override
  AsyncValue<List<String>>? build(String slug) => null;

  Future<void> generate(IssueDetail issue) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).summarizeIssue(issue);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }
}

/// On-demand "suggest next action", keyed by issue slug. `null` = not requested.
@Riverpod(keepAlive: true)
class IssueNextActionController extends _$IssueNextActionController {
  @override
  AsyncValue<String>? build(String slug) => null;

  Future<void> generate(IssueDetail issue) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).suggestNextAction(issue);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
