import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../pr_detail/data/models/pr_detail.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
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
