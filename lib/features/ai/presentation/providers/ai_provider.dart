import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../pr_detail/data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../../sprint_report/data/models/sprint_report.dart';
import '../../data/models/triage_item.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/services/anthropic_api_client.dart';
import '../../data/services/api_key_store.dart';
import '../helpers/ai_prompts.dart';

part 'ai_provider.freezed.dart';
part 'ai_provider.g.dart';

/// State of the BYOK Anthropic key.
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

@Riverpod(keepAlive: true)
AnthropicApiClient anthropicApiClient(Ref ref) => AnthropicApiClient();

@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) =>
    AnthropicAiRepository(ref.watch(anthropicApiClientProvider), ref.watch(githubApiClientProvider));

@Riverpod(keepAlive: true)
class AiKeyNotifier extends _$AiKeyNotifier {
  @override
  AiKeyState build() {
    _init();
    return const AiKeyState.loading();
  }

  Future<void> _init() async {
    final key = await ref.read(apiKeyStoreProvider).read();
    if (key == null || key.isEmpty) {
      state = const AiKeyState.missing();
      return;
    }
    ref.read(anthropicApiClientProvider).setKey(key);
    state = const AiKeyState.valid(); // trust the stored key; re-validated on submit
  }

  /// Validity check without persisting (the Settings "Validate" button).
  /// Returns true (valid), false (rejected 401), or null (could not check).
  Future<bool?> validate(String key) async {
    ref.read(anthropicApiClientProvider).setKey(key);
    final result = await ref.read(aiRepositoryProvider).validateKey();
    return switch (result) {
      ResultSuccess(:final data) => data,
      ResultFailure() => null,
    };
  }

  /// Validates [key]; on success persists it and marks valid.
  Future<void> submit(String key) async {
    state = const AiKeyState.validating();
    ref.read(anthropicApiClientProvider).setKey(key);
    final result = await ref.read(aiRepositoryProvider).validateKey();
    switch (result) {
      case ResultSuccess(:final data):
        if (data) {
          await ref.read(apiKeyStoreProvider).write(key);
          state = const AiKeyState.valid();
        } else {
          ref.read(anthropicApiClientProvider).setKey(null);
          state = const AiKeyState.error('That key was rejected by Anthropic (401).');
        }
      case ResultFailure(:final message):
        state = AiKeyState.error(message);
    }
  }

  Future<void> clear() async {
    await ref.read(apiKeyStoreProvider).delete();
    ref.read(anthropicApiClientProvider).setKey(null);
    state = const AiKeyState.missing();
  }
}

/// True when a key is present (valid or trusted-from-storage).
@riverpod
bool aiKeyReady(Ref ref) => ref.watch(aiKeyProvider) is AiKeyValid;

/// Masked form of the stored Anthropic key for display (Settings). Re-reads
/// when the key state changes (save/remove).
@riverpod
Future<String?> anthropicKeyMasked(Ref ref) async {
  ref.watch(aiKeyProvider); // refresh when the key is saved/removed
  final key = await ref.watch(apiKeyStoreProvider).read();
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
@riverpod
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
@riverpod
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
@riverpod
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
@riverpod
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
@riverpod
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

/// On-demand weekly digest (Lead Cockpit). `null` = not requested yet.
@riverpod
class WeeklyDigestController extends _$WeeklyDigestController {
  @override
  AsyncValue<String>? build() => null;

  Future<void> generate(CockpitData cockpit) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).weeklyDigest(cockpit);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
