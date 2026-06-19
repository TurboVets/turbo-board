# Multi-provider AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make TurboBoard's AI layer provider-agnostic and add OpenAI as a second BYOK provider, with one active provider selectable in Settings.

**Architecture:** Introduce an `LlmClient` interface (same surface as today's `AnthropicApiClient`) and an `AiProvider` enum carrying per-provider metadata. The repository depends on the interface, not a concrete client. The key store and Riverpod providers become provider-aware; Settings gets a provider selector. Existing Anthropic behavior is unchanged.

**Tech Stack:** Flutter, Dart, Riverpod (codegen), Freezed, Dio, mockito, flutter_secure_storage, turbo_core (`Result<T>`), turbo_ui (Tether).

## Global Constraints

- Format: `dart format --line-length 120 --set-exit-if-changed .` must pass (CI rejects unformatted code).
- `dart analyze` must pass; `flutter test` must pass.
- Depend on `turbo_core` + `turbo_ui` only — never `turbo_sdk`.
- Cross-platform (macos/windows/linux/web/android/ios). No new packages.
- Secrets (API keys) live only in `flutter_secure_storage`; never logged, never committed, validated with a cheap 1-token call.
- Errors caught in the repo layer only; above it use `Result<T>`.
- Run `dart run build_runner build -d` after any Riverpod/Freezed change.
- Never edit generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) by hand.

---

### Task 1: `AiProvider` enum + `LlmClient` interface; Anthropic client implements it

**Files:**
- Create: `lib/features/ai/data/services/ai_provider_kind.dart`
- Create: `lib/features/ai/data/services/llm_client.dart`
- Modify: `lib/features/ai/data/services/anthropic_api_client.dart`
- Test: `test/features/ai/data/services/ai_provider_kind_test.dart`

**Interfaces:**
- Produces:
  - `enum AiProvider { anthropic, openai }` with fields `String displayName, defaultModel, storageKey, consoleUrl, consoleLabel, keyHint, keyPlaceholder`.
  - `abstract interface class LlmClient` with `AiProvider get provider; void setKey(String? apiKey); Future<String> complete({required String prompt, int maxTokens}); Future<bool> validateKey();`
  - `AnthropicApiClient implements LlmClient` (adds `provider => AiProvider.anthropic`).

- [ ] **Step 1: Write the failing test**

`test/features/ai/data/services/ai_provider_kind_test.dart`:

```dart
// Test summary:
// - AiProvider exposes the expected per-provider metadata
// - AnthropicApiClient reports provider == anthropic and is an LlmClient
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/anthropic_api_client.dart';
import 'package:turbo_board/features/ai/data/services/llm_client.dart';

void main() {
  test('anthropic metadata', () {
    const p = AiProvider.anthropic;
    expect(p.displayName, 'Anthropic');
    expect(p.defaultModel, 'claude-haiku-4-5');
    expect(p.storageKey, 'llm_key_anthropic');
    expect(p.keyHint, startsWith('sk-ant-'));
  });

  test('openai metadata', () {
    const p = AiProvider.openai;
    expect(p.displayName, 'OpenAI');
    expect(p.defaultModel, 'gpt-4o-mini');
    expect(p.storageKey, 'llm_key_openai');
  });

  test('AnthropicApiClient is an LlmClient reporting its provider', () {
    final client = AnthropicApiClient();
    expect(client, isA<LlmClient>());
    expect(client.provider, AiProvider.anthropic);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/data/services/ai_provider_kind_test.dart`
Expected: FAIL — `ai_provider_kind.dart`/`llm_client.dart` don't exist.

- [ ] **Step 3: Create the enum**

`lib/features/ai/data/services/ai_provider_kind.dart`:

```dart
/// The set of supported BYOK LLM providers and their per-provider metadata.
///
/// One active provider is used at a time (see ai_provider.dart). Each provider's
/// key is stored independently under [storageKey] in flutter_secure_storage.
enum AiProvider {
  anthropic(
    displayName: 'Anthropic',
    defaultModel: 'claude-haiku-4-5',
    storageKey: 'llm_key_anthropic',
    consoleUrl: 'https://console.anthropic.com',
    consoleLabel: 'console.anthropic.com',
    keyHint: 'sk-ant-',
    keyPlaceholder: 'sk-ant-api03-…',
  ),
  openai(
    displayName: 'OpenAI',
    defaultModel: 'gpt-4o-mini',
    storageKey: 'llm_key_openai',
    consoleUrl: 'https://platform.openai.com/api-keys',
    consoleLabel: 'platform.openai.com',
    keyHint: 'sk-',
    keyPlaceholder: 'sk-…',
  );

  const AiProvider({
    required this.displayName,
    required this.defaultModel,
    required this.storageKey,
    required this.consoleUrl,
    required this.consoleLabel,
    required this.keyHint,
    required this.keyPlaceholder,
  });

  final String displayName;
  final String defaultModel;
  final String storageKey;
  final String consoleUrl;
  final String consoleLabel;
  final String keyHint;
  final String keyPlaceholder;
}
```

- [ ] **Step 4: Create the interface**

`lib/features/ai/data/services/llm_client.dart`:

```dart
import 'ai_provider_kind.dart';

/// A provider-agnostic single-turn chat client (BYOK).
///
/// Implementations talk directly to their provider's API from Dart; the key
/// lives only in flutter_secure_storage and is injected via [setKey]. The
/// surface matches what [AiRepository] needs — nothing more.
abstract interface class LlmClient {
  /// Which provider this client targets.
  AiProvider get provider;

  /// Sets (or clears, when null) the auth credential used for every request.
  void setKey(String? apiKey);

  /// Sends a single user message and returns the concatenated text response.
  /// Throws on a non-success status.
  Future<String> complete({required String prompt, int maxTokens = 512});

  /// Cheap validity check: a 1-token request. true → valid, false → rejected
  /// (401). Throws when validity could not be determined.
  Future<bool> validateKey();
}
```

- [ ] **Step 5: Make AnthropicApiClient implement LlmClient**

In `lib/features/ai/data/services/anthropic_api_client.dart`, add the import and `implements`, and add the `provider` getter. Change the class declaration:

```dart
import 'package:dio/dio.dart';

import 'ai_provider_kind.dart';
import 'llm_client.dart';
```

```dart
class AnthropicApiClient implements LlmClient {
  AnthropicApiClient({Dio? dio, String? apiKey}) : dio = dio ?? _build() {
    if (apiKey != null) setKey(apiKey);
  }

  final Dio dio;

  @override
  AiProvider get provider => AiProvider.anthropic;

  static const String model = 'claude-haiku-4-5';
```

Add `@override` to `setKey`, `complete`, and `validateKey` (no body changes).

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/ai/data/services/ai_provider_kind_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/ai/data/services/ai_provider_kind.dart lib/features/ai/data/services/llm_client.dart lib/features/ai/data/services/anthropic_api_client.dart test/features/ai/data/services/ai_provider_kind_test.dart
git commit -m "feat(ai): add AiProvider enum + LlmClient interface; Anthropic implements it"
```

---

### Task 2: `OpenAiApiClient`

**Files:**
- Create: `lib/features/ai/data/services/openai_api_client.dart`
- Test: `test/features/ai/data/services/openai_api_client_test.dart`

**Interfaces:**
- Consumes: `LlmClient`, `AiProvider` (Task 1).
- Produces: `class OpenAiApiClient implements LlmClient` with ctor `OpenAiApiClient({Dio? dio, String? apiKey})`, `provider => AiProvider.openai`, `static const String model = 'gpt-4o-mini'`.

- [ ] **Step 1: Write the failing test**

`test/features/ai/data/services/openai_api_client_test.dart`:

```dart
// Test summary:
// - complete posts to /v1/chat/completions and returns choices[0].message.content
// - complete throws on a non-200 status
// - validateKey returns true on 200, false on 401, throws on 500
// - setKey sets/clears the Authorization: Bearer header
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/openai_api_client.dart';

import 'openai_api_client_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late OpenAiApiClient client;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    client = OpenAiApiClient(dio: dio);
  });

  Response<Map<String, dynamic>> chat(Map<String, dynamic>? data, {int status = 200}) => Response(
    requestOptions: RequestOptions(path: '/v1/chat/completions'),
    statusCode: status,
    data: data,
  );

  void stub(Response<Map<String, dynamic>> response) {
    when(
      dio.post<Map<String, dynamic>>('/v1/chat/completions', data: anyNamed('data')),
    ).thenAnswer((_) async => response);
  }

  test('provider is openai', () {
    expect(client.provider, AiProvider.openai);
  });

  test('complete returns message content', () async {
    stub(chat({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': 'hello world'},
        },
      ],
    }));
    expect(await client.complete(prompt: 'hi'), 'hello world');
  });

  test('complete throws on non-200', () async {
    stub(chat(null, status: 429));
    expect(() => client.complete(prompt: 'hi'), throwsException);
  });

  test('validateKey true/false/throw', () async {
    stub(chat({'choices': []}, status: 200));
    expect(await client.validateKey(), isTrue);
    stub(chat(null, status: 401));
    expect(await client.validateKey(), isFalse);
    stub(chat(null, status: 500));
    expect(() => client.validateKey(), throwsException);
  });

  test('setKey sets and clears the bearer header', () {
    client.setKey('sk-test');
    expect(dio.options.headers['Authorization'], 'Bearer sk-test');
    client.setKey(null);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });
}
```

- [ ] **Step 2: Generate mocks and run the test to verify it fails**

Run: `dart run build_runner build -d` (generates `openai_api_client_test.mocks.dart`).
Then: `flutter test test/features/ai/data/services/openai_api_client_test.dart`
Expected: FAIL — `openai_api_client.dart` doesn't exist (build_runner may also error on the missing import; that's the expected failing state).

- [ ] **Step 3: Implement the client**

`lib/features/ai/data/services/openai_api_client.dart`:

```dart
import 'package:dio/dio.dart';

import 'ai_provider_kind.dart';
import 'llm_client.dart';

/// An OpenAI-scoped Dio instance for the Chat Completions API (BYOK).
///
/// Like [AnthropicApiClient], it does NOT reuse turbo_core's `DioClient.I`
/// (that is bound to the TurboVets backend). The model is fixed to
/// `gpt-4o-mini` — cheap enough for BYOK. The key lives only in
/// flutter_secure_storage and is sent as `Authorization: Bearer`; never logged.
class OpenAiApiClient implements LlmClient {
  OpenAiApiClient({Dio? dio, String? apiKey}) : dio = dio ?? _build() {
    if (apiKey != null) setKey(apiKey);
  }

  final Dio dio;

  @override
  AiProvider get provider => AiProvider.openai;

  static const String model = 'gpt-4o-mini';

  static Dio _build() => Dio(
    BaseOptions(
      baseUrl: 'https://api.openai.com',
      headers: {'content-type': 'application/json'},
      // Inspect 400/401/429 rather than throw on them.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  @override
  void setKey(String? apiKey) {
    if (apiKey == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  @override
  Future<String> complete({required String prompt, int maxTokens = 512}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/chat/completions',
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('OpenAI request failed (HTTP ${res.statusCode}).');
    }
    final choices = (res.data!['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) return '';
    final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    return message?['content']?.toString() ?? '';
  }

  @override
  Future<bool> validateKey() async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/chat/completions',
      data: {
        'model': model,
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
      },
    );
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401) return false;
    throw Exception('Could not validate key (HTTP ${res.statusCode}).');
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ai/data/services/openai_api_client_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/data/services/openai_api_client.dart test/features/ai/data/services/openai_api_client_test.dart
git commit -m "feat(ai): add OpenAiApiClient (chat completions, gpt-4o-mini)"
```

---

### Task 3: Provider-aware `ApiKeyStore` + legacy migration

**Files:**
- Modify: `lib/features/ai/data/services/api_key_store.dart`
- Test: `test/features/ai/data/services/api_key_store_test.dart`

**Interfaces:**
- Consumes: `AiProvider` (Task 1).
- Produces: `ApiKeyStore` with `Future<String?> read(AiProvider); Future<void> write(AiProvider, String); Future<void> delete(AiProvider); Future<AiProvider?> readActiveProvider(); Future<void> writeActiveProvider(AiProvider);`. Implementations: `SecureApiKeyStore` (migrates legacy `anthropic_api_key`), `InMemoryApiKeyStore({Map<AiProvider,String>? keys, AiProvider? active})`.

- [ ] **Step 1: Write the failing test**

`test/features/ai/data/services/api_key_store_test.dart`:

```dart
// Test summary:
// - InMemoryApiKeyStore reads/writes/deletes per provider independently
// - active provider round-trips
// - seeded keys are returned per provider
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/api_key_store.dart';

void main() {
  test('per-provider keys are independent', () async {
    final store = InMemoryApiKeyStore();
    await store.write(AiProvider.anthropic, 'sk-ant-1');
    await store.write(AiProvider.openai, 'sk-oa-1');
    expect(await store.read(AiProvider.anthropic), 'sk-ant-1');
    expect(await store.read(AiProvider.openai), 'sk-oa-1');
    await store.delete(AiProvider.anthropic);
    expect(await store.read(AiProvider.anthropic), isNull);
    expect(await store.read(AiProvider.openai), 'sk-oa-1');
  });

  test('active provider round-trips, defaults null', () async {
    final store = InMemoryApiKeyStore();
    expect(await store.readActiveProvider(), isNull);
    await store.writeActiveProvider(AiProvider.openai);
    expect(await store.readActiveProvider(), AiProvider.openai);
  });

  test('seeded constructor exposes keys and active', () async {
    final store = InMemoryApiKeyStore(
      keys: {AiProvider.anthropic: 'seed'},
      active: AiProvider.anthropic,
    );
    expect(await store.read(AiProvider.anthropic), 'seed');
    expect(await store.readActiveProvider(), AiProvider.anthropic);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/data/services/api_key_store_test.dart`
Expected: FAIL — `read`/`write` signatures don't take an `AiProvider`; `readActiveProvider` missing.

- [ ] **Step 3: Rewrite the store**

Replace the whole body of `lib/features/ai/data/services/api_key_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_provider_kind.dart';

/// Persists each provider's BYOK key and which provider is active. Never logged.
abstract interface class ApiKeyStore {
  Future<String?> read(AiProvider provider);
  Future<void> write(AiProvider provider, String key);
  Future<void> delete(AiProvider provider);
  Future<AiProvider?> readActiveProvider();
  Future<void> writeActiveProvider(AiProvider provider);
}

/// Backed by flutter_secure_storage (Keychain / Keystore / WebCrypto).
///
/// Web caveat: on web the key is protected by WebCrypto and does NOT survive a
/// browser-data clear — the user re-enters it after such a clear.
class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore([this._storage = const FlutterSecureStorage()]);

  /// Pre-multi-provider key location; migrated to [AiProvider.anthropic.storageKey].
  static const _legacyAnthropicKey = 'anthropic_api_key';
  static const _activeKey = 'llm_active_provider';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(AiProvider provider) async {
    final value = await _storage.read(key: provider.storageKey);
    if (value != null) return value;
    // One-time migration of the legacy single-key storage.
    if (provider == AiProvider.anthropic) {
      final legacy = await _storage.read(key: _legacyAnthropicKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: provider.storageKey, value: legacy);
        await _storage.delete(key: _legacyAnthropicKey);
        return legacy;
      }
    }
    return null;
  }

  @override
  Future<void> write(AiProvider provider, String key) => _storage.write(key: provider.storageKey, value: key);

  @override
  Future<void> delete(AiProvider provider) => _storage.delete(key: provider.storageKey);

  @override
  Future<AiProvider?> readActiveProvider() async {
    final name = await _storage.read(key: _activeKey);
    if (name == null) return null;
    for (final p in AiProvider.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  Future<void> writeActiveProvider(AiProvider provider) => _storage.write(key: _activeKey, value: provider.name);
}

/// In-memory fake for tests and offline development.
class InMemoryApiKeyStore implements ApiKeyStore {
  InMemoryApiKeyStore({Map<AiProvider, String>? keys, AiProvider? active})
    : _keys = {...?keys},
      _active = active;

  final Map<AiProvider, String> _keys;
  AiProvider? _active;

  @override
  Future<String?> read(AiProvider provider) async => _keys[provider];

  @override
  Future<void> write(AiProvider provider, String key) async => _keys[provider] = key;

  @override
  Future<void> delete(AiProvider provider) async => _keys.remove(provider);

  @override
  Future<AiProvider?> readActiveProvider() async => _active;

  @override
  Future<void> writeActiveProvider(AiProvider provider) async => _active = provider;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ai/data/services/api_key_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/data/services/api_key_store.dart test/features/ai/data/services/api_key_store_test.dart
git commit -m "feat(ai): make ApiKeyStore provider-aware with legacy migration"
```

---

### Task 4: Rename repository to `LlmAiRepository` taking `LlmClient`

**Files:**
- Modify: `lib/features/ai/data/repositories/ai_repository.dart`
- Modify: `test/features/ai/data/repositories/ai_repository_test.dart`
- Test (regenerate): `test/features/ai/data/repositories/ai_repository_test.mocks.dart`

**Interfaces:**
- Consumes: `LlmClient` (Task 1), `GithubApiClient` (unchanged).
- Produces: `class LlmAiRepository implements AiRepository` with ctor `LlmAiRepository(LlmClient llm, GithubApiClient github)`. `AiRepository` interface unchanged.

- [ ] **Step 1: Update the repository class**

In `lib/features/ai/data/repositories/ai_repository.dart`:

Replace the import of the concrete client with the interface:

```dart
import '../services/llm_client.dart';
```

(remove `import '../services/anthropic_api_client.dart';`)

Rename the class and field — change the declaration block:

```dart
class LlmAiRepository implements AiRepository {
  LlmAiRepository(this._llm, this._github);

  final LlmClient _llm;
  final GithubApiClient _github;
```

Then replace every `_anthropic.` with `_llm.` in this file (there are calls in `validateKey`, `summarize`, `draftReply`, `sprintBrief`, `_narrative`, `triage`, `summarizeIssue`, `suggestNextAction`, `boardInsights`). The log/failure strings that mention "Anthropic" inside `validateKey` should be generalized:

```dart
  @override
  Future<Result<bool>> validateKey() async {
    try {
      return Result.success(await _llm.validateKey());
    } catch (e, stackTrace) {
      log('Failed to validate AI provider key', error: e, stackTrace: stackTrace);
      return Result.failure('Could not reach the AI provider. Check your connection and try again.', stackTrace);
    }
  }
```

- [ ] **Step 2: Update the repository test**

In `test/features/ai/data/repositories/ai_repository_test.dart`:
- Change import `anthropic_api_client.dart` → keep it (still constructs `AnthropicApiClient` as a concrete `LlmClient`); no new import needed.
- Change the field type and constructor:

```dart
  late LlmAiRepository repo;
```

```dart
    repo = LlmAiRepository(AnthropicApiClient(dio: anthropicDio), GithubApiClient(dio: githubDio));
```

(The `@GenerateMocks([Dio, AiRepository])` annotation and `stubAnthropic` helper stay as-is — they mock `Dio`, not the renamed class.)

- [ ] **Step 3: Regenerate and run the repo tests**

Run: `dart run build_runner build -d`
Then: `flutter test test/features/ai/data/repositories/ai_repository_test.dart`
Expected: PASS (all existing repo tests green under the new name).

- [ ] **Step 4: Commit**

```bash
git add lib/features/ai/data/repositories/ai_repository.dart test/features/ai/data/repositories/ai_repository_test.dart
git commit -m "refactor(ai): rename AnthropicAiRepository to LlmAiRepository over LlmClient"
```

---

### Task 5: Riverpod providers — active provider, client factory, reworked key notifier

**Files:**
- Modify: `lib/features/ai/presentation/providers/ai_provider.dart`
- Test: `test/features/ai/presentation/providers/ai_key_notifier_test.dart`
- Regenerate: `lib/features/ai/presentation/providers/ai_provider.g.dart`

**Interfaces:**
- Consumes: `AiProvider`, `LlmClient`, `AnthropicApiClient`, `OpenAiApiClient`, `ApiKeyStore` (Tasks 1–3), `LlmAiRepository` (Task 4).
- Produces:
  - `activeAiProviderProvider` — `AiProvider` (keepAlive Notifier, default `anthropic`, `set(AiProvider)` persists).
  - `llmClientProvider` — `LlmClient` (keepAlive), rebuilt per active provider.
  - `aiRepositoryProvider` — unchanged name, now `LlmAiRepository`.
  - `AiKeyNotifier` — key state for the active provider; `submit`/`validate`/`clear` operate on it.
  - `activeKeyMaskedProvider` — `Future<String?>` (replaces `anthropicKeyMaskedProvider`).

- [ ] **Step 1: Write the failing test**

`test/features/ai/presentation/providers/ai_key_notifier_test.dart`:

```dart
// Test summary:
// - active provider defaults to anthropic, hydrates from store, and persists on set
// - llmClient matches the active provider and switches when it changes
// - submit persists the key under the active provider and marks valid
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/api_key_store.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';

void main() {
  ProviderContainer makeContainer(ApiKeyStore store) {
    final c = ProviderContainer(overrides: [apiKeyStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    return c;
  }

  test('active provider hydrates from store', () async {
    final store = InMemoryApiKeyStore(active: AiProvider.openai);
    final c = makeContainer(store);
    // allow the async hydrate in build() to settle
    await Future<void>.delayed(Duration.zero);
    expect(c.read(activeAiProviderProvider), AiProvider.openai);
  });

  test('setting active provider persists and swaps the client', () async {
    final store = InMemoryApiKeyStore();
    final c = makeContainer(store);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(activeAiProviderProvider), AiProvider.anthropic);
    expect(c.read(llmClientProvider).provider, AiProvider.anthropic);

    await c.read(activeAiProviderProvider.notifier).set(AiProvider.openai);
    expect(c.read(activeAiProviderProvider), AiProvider.openai);
    expect(c.read(llmClientProvider).provider, AiProvider.openai);
    expect(await store.readActiveProvider(), AiProvider.openai);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/presentation/providers/ai_key_notifier_test.dart`
Expected: FAIL — `activeAiProviderProvider` / `llmClientProvider` don't exist.

- [ ] **Step 3: Rework the providers**

In `lib/features/ai/presentation/providers/ai_provider.dart`:

Update imports — replace the concrete-client import with all three service imports:

```dart
import '../../data/services/ai_provider_kind.dart';
import '../../data/services/anthropic_api_client.dart';
import '../../data/services/api_key_store.dart';
import '../../data/services/llm_client.dart';
import '../../data/services/openai_api_client.dart';
```

Replace the `apiKeyStore` / `anthropicApiClient` / `aiRepository` block (current lines 30–38) with:

```dart
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
AiRepository aiRepository(Ref ref) =>
    LlmAiRepository(ref.watch(llmClientProvider), ref.watch(githubApiClientProvider));
```

(Keep the `import '../../data/repositories/ai_repository.dart';` — it already exists.)

Now rework `AiKeyNotifier` so it tracks the active provider. Replace its body:

```dart
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
```

Replace `anthropicKeyMasked` with the active-provider version:

```dart
/// Masked form of the active provider's stored key for display (Settings).
@riverpod
Future<String?> activeKeyMasked(Ref ref) async {
  ref.watch(aiKeyProvider); // refresh when the key is saved/removed
  final provider = ref.watch(activeAiProviderProvider);
  final key = await ref.watch(apiKeyStoreProvider).read(provider);
  return maskSecret(key);
}
```

(Leave `aiKeyReady`, `maskSecret`, and all the on-demand controllers untouched.)

- [ ] **Step 4: Regenerate providers**

Run: `dart run build_runner build -d`
Expected: regenerates `ai_provider.g.dart` with `activeAiProviderProvider`, `llmClientProvider`, `activeKeyMaskedProvider`.

- [ ] **Step 5: Run the notifier test**

Run: `flutter test test/features/ai/presentation/providers/ai_key_notifier_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai/presentation/providers/ai_provider.dart test/features/ai/presentation/providers/ai_key_notifier_test.dart
git commit -m "feat(ai): active-provider + llmClient providers; key notifier per active provider"
```

---

### Task 6: Settings UI — provider selector + generic key section

**Files:**
- Modify: `lib/features/settings/presentation/view/settings_screen.dart`

**Interfaces:**
- Consumes: `activeAiProviderProvider`, `activeKeyMaskedProvider`, `aiKeyProvider` (Task 5), `AiProvider` (Task 1), `TetherSegmentedButtonGroup` (turbo_ui: `segments: List<String>`, `selectedIndex: int`, `onChanged: ValueChanged<int>`).
- Produces: no new public API; renames the private `_AnthropicKeySection` widget to `_AiProviderSection`.

- [ ] **Step 1: Add the AiProvider import**

At the top of `settings_screen.dart`, add (in local-import order):

```dart
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
```

- [ ] **Step 2: Rename the section usage**

At `settings_screen.dart:55`, change `_AnthropicKeySection()` to `_AiProviderSection()`.

- [ ] **Step 3: Rewrite the section widget**

Replace the whole `_AnthropicKeySection` class (lines ~580–704) with:

```dart
class _AiProviderSection extends HookConsumerWidget {
  const _AiProviderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(activeAiProviderProvider);
    final state = ref.watch(aiKeyProvider);
    final saved = state is AiKeyValid;
    final controller = useTextEditingController();
    final validateState = useState(_ValidateResult.none);
    final maskedAsync = ref.watch(activeKeyMaskedProvider);

    // Reset the input affordances when the active provider changes.
    useEffect(() {
      controller.clear();
      validateState.value = _ValidateResult.none;
      return null;
    }, [provider]);

    Widget? badge;
    if (saved) {
      badge = const TbBadge('Active', TbSignal.ok, small: true);
    } else if (state is AiKeyValidating) {
      badge = const TbBadge('Validating', TbSignal.info, small: true);
    } else if (state is AiKeyError) {
      badge = const TbBadge('Error', TbSignal.bad, small: true);
    }

    Future<void> validate() async {
      final value = controller.text.trim();
      if (value.isEmpty) return;
      validateState.value = _ValidateResult.checking;
      final result = await ref.read(aiKeyProvider.notifier).validate(value);
      validateState.value = switch (result) {
        true => _ValidateResult.valid,
        false => _ValidateResult.invalid,
        null => _ValidateResult.error,
      };
    }

    final validateLabel = switch (validateState.value) {
      _ValidateResult.checking => 'Checking…',
      _ValidateResult.valid => '✓ Valid',
      _ValidateResult.invalid => '✗ Invalid',
      _ValidateResult.error => 'Retry',
      _ValidateResult.none => 'Validate',
    };

    final selector = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TetherSegmentedButtonGroup(
        segments: [for (final p in AiProvider.values) p.displayName],
        selectedIndex: AiProvider.values.indexOf(provider),
        onChanged: (i) => ref.read(activeAiProviderProvider.notifier).set(AiProvider.values[i]),
        fillWidth: true,
      ),
    );

    return _Card(
      title: 'AI provider',
      headerTrailing: badge,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          Padding(
            padding: const EdgeInsets.all(16),
            child: saved
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _maskedCode(maskedAsync.asData?.value ?? '••••••••')),
                          const SizedBox(width: 12),
                          _Btn(
                            'Remove key',
                            kind: _BtnKind.danger,
                            onTap: () => ref.read(aiKeyProvider.notifier).clear(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AI Summary, Draft reply and Inbox triage are enabled via ${provider.displayName}. '
                        'The key lives in your device Keychain / Keystore — never logged, never sent to GitHub.',
                        style: TbText.body(size: 12, color: TbColors.muted, height: 1.5),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: TbText.body(size: 13, color: TbColors.muted, height: 1.55),
                          children: [
                            const TextSpan(text: 'Create a key at '),
                            TextSpan(
                              text: provider.consoleLabel,
                              style: TbText.body(size: 13, weight: FontWeight.w600),
                            ),
                            TextSpan(
                              text:
                                  ' and paste it here — keys start with ${provider.keyHint}. '
                                  'The API is billed separately by ${provider.displayName}, pay-per-use.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              obscureText: true,
                              style: TbText.body(size: 13),
                              decoration: _fieldDecoration(provider.keyPlaceholder),
                              onChanged: (_) => validateState.value = _ValidateResult.none,
                              onSubmitted: (_) => validate(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Btn(
                            validateLabel,
                            kind: _BtnKind.outline,
                            onTap: validateState.value == _ValidateResult.checking ? null : validate,
                          ),
                          const SizedBox(width: 10),
                          _Btn(
                            state is AiKeyValidating ? 'Saving…' : 'Save',
                            kind: _BtnKind.primary,
                            onTap: state is AiKeyValidating
                                ? null
                                : () => ref.read(aiKeyProvider.notifier).submit(controller.text.trim()),
                          ),
                        ],
                      ),
                      if (state is AiKeyError) ...[
                        const SizedBox(height: 8),
                        Text(state.message, style: TbText.body(size: 12, color: TbSignal.bad.border)),
                      ],
                      _hint('Validated with a 1-token test call · stored in Keychain / Keystore — never logged'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Generalize the billing card copy**

In `_BillingCard` (around line 725), replace the Anthropic-specific paragraph with provider-neutral copy. Change `_BillingCard` to a `ConsumerWidget` so it can name the active provider:

```dart
class _BillingCard extends ConsumerWidget {
  const _BillingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(activeAiProviderProvider);
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILLING', style: TbText.label(size: 11, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 10),
          Text(
            'AI features call ${provider.displayName} directly from the app with your key — there is no '
            'TurboBoard backend in the loop. Summaries, triage and reply drafts are pay-per-use, billed to your '
            '${provider.displayName} account. No PR content is stored by TurboBoard.',
            style: TbText.body(size: 13, color: TbColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}
```

(Confirm `TetherSegmentedButtonGroup` and `TbBadge`/`TbSignal` come in via the existing turbo_ui import in this file; if `TetherSegmentedButtonGroup` is not exported by the current import, add `import 'package:turbo_ui/turbo_ui.dart';` — grep the file's existing imports first to avoid a duplicate.)

- [ ] **Step 5: Verify analysis + format + full settings build**

Run:
```bash
dart format --line-length 120 .
dart analyze
```
Expected: no analyzer errors; formatter reports the files it rewrote (re-run `--set-exit-if-changed` to confirm clean).

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/view/settings_screen.dart
git commit -m "feat(settings): provider selector + generic AI key section"
```

---

### Task 7: Full verification sweep

**Files:** none (verification only).

- [ ] **Step 1: Regenerate everything clean**

```bash
dart run build_runner build -d
```

- [ ] **Step 2: Format check (CI gate)**

```bash
dart format --line-length 120 --set-exit-if-changed .
```
Expected: "0 changed".

- [ ] **Step 3: Static analysis**

```bash
dart analyze
```
Expected: "No issues found!"

- [ ] **Step 4: Full test suite**

```bash
flutter test
```
Expected: all tests pass (existing + the new service/store/notifier tests).

- [ ] **Step 5: Confirm no stray references to the old names**

```bash
grep -rn "AnthropicAiRepository\|anthropicKeyMasked\|anthropicApiClientProvider\|_AnthropicKeySection" lib test
```
Expected: no matches (all renamed).

- [ ] **Step 6: Final commit if anything was regenerated/touched**

```bash
git add -A
git commit -m "chore(ai): verification sweep for multi-provider AI" || echo "nothing to commit"
```

---

## Notes for the implementer

- The `AiRepository` abstract interface and all on-demand controllers (`PrSummaryController`, `TriageController`, etc.) are intentionally untouched — they depend on `aiRepositoryProvider`, which keeps its name.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) are gitignored; the `git add` steps that name them will silently no-op, which is fine.
- Do not change the Anthropic model, version header, or request shape — Anthropic users must see identical behavior.
