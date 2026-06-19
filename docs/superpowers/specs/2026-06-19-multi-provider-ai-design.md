# Multi-provider AI (generic LLM layer + OpenAI support)

**Date:** 2026-06-19
**Branch:** `feat/multi-provider-ai`

## Problem

AI features are hardwired to Anthropic: `AnthropicApiClient` is the only client,
`AnthropicAiRepository` depends on it concretely, the key store holds a single
`anthropic_api_key`, and Settings shows an Anthropic-only key section. Adding
another provider today means duplicating all of that.

## Goal

Introduce a generic LLM client abstraction so providers are interchangeable, and
add OpenAI as the second supported provider. Behavior for existing Anthropic
users is unchanged.

## Decisions

- **Provider UX:** one active provider at a time. User picks Anthropic or OpenAI
  in Settings and enters that provider's key. Each provider's key is stored
  independently, so switching back does not require re-entry.
- **Model:** fixed default per provider, no model picker.
  - Anthropic: `claude-haiku-4-5` (unchanged)
  - OpenAI: `gpt-4o-mini`
- **BYOK unchanged:** keys live only in `flutter_secure_storage`, never logged,
  validated with a cheap 1-token call on entry.

## Architecture

### 1. Abstraction layer (`lib/features/ai/data/services/`)

`AiProvider` enum — one entry per provider, carrying its metadata:

```dart
enum AiProvider {
  anthropic(
    displayName: 'Anthropic',
    defaultModel: 'claude-haiku-4-5',
    storageKey: 'llm_key_anthropic',
    consoleUrl: 'https://console.anthropic.com',
    consoleLabel: 'console.anthropic.com',
    keyHint: 'sk-ant-…',
  ),
  openai(
    displayName: 'OpenAI',
    defaultModel: 'gpt-4o-mini',
    storageKey: 'llm_key_openai',
    consoleUrl: 'https://platform.openai.com/api-keys',
    consoleLabel: 'platform.openai.com',
    keyHint: 'sk-…',
  );
  // const constructor + final fields
}
```

`LlmClient` interface — identical surface to today's `AnthropicApiClient`, so the
repository's call sites do not change:

```dart
abstract interface class LlmClient {
  AiProvider get provider;
  void setKey(String? apiKey);
  Future<String> complete({required String prompt, int maxTokens = 512});
  Future<bool> validateKey();
}
```

- `AnthropicApiClient implements LlmClient` — add `provider => AiProvider.anthropic`;
  no other behavior change (model, version header, parsing all stay).
- `OpenAiApiClient implements LlmClient` — new:
  - baseUrl `https://api.openai.com`
  - auth header `Authorization: Bearer <key>` (set/cleared in `setKey`)
  - `complete`: POST `/v1/chat/completions` with
    `{model, max_tokens, messages:[{role:user, content:prompt}]}`
    (gpt-4o-mini chat-completions accepts `max_tokens`), parse
    `choices[0].message.content`.
  - `validateKey`: same call with `max_tokens: 1`; 200 → true, 401 → false,
    else throw. Same `validateStatus < 500` pattern as the Anthropic client.

### 2. Repository

Rename `AnthropicAiRepository` → `LlmAiRepository`. Constructor takes
`LlmClient` (was `AnthropicApiClient`) + the existing `GithubApiClient`. The
field `_anthropic` becomes `_llm`. All 11 methods are unchanged — they only call
`complete()` / `validateKey()`, which the interface provides. The `AiRepository`
abstract interface is unchanged.

### 3. Key store

`ApiKeyStore` becomes provider-aware:

```dart
abstract interface class ApiKeyStore {
  Future<String?> read(AiProvider provider);
  Future<void> write(AiProvider provider, String key);
  Future<void> delete(AiProvider provider);
  Future<AiProvider?> readActiveProvider();
  Future<void> writeActiveProvider(AiProvider provider);
}
```

- `SecureApiKeyStore`: stores each provider's key under `provider.storageKey`;
  active provider under `llm_active_provider` (stores `provider.name`).
- **Migration:** on first `read(anthropic)`, if `llm_key_anthropic` is absent but
  the legacy `anthropic_api_key` exists, copy it forward and delete the legacy
  entry. One-time, transparent.
- `InMemoryApiKeyStore`: map-backed equivalent for tests.

### 4. Riverpod providers (`ai_provider.dart`)

- `activeAiProviderProvider` (keepAlive, `Notifier<AiProvider>`): holds the
  selected provider, defaults to `anthropic`, hydrates from store on build,
  persists on change.
- `llmClientProvider` (keepAlive): builds the client for the active provider
  (`switch (provider)` → `AnthropicApiClient()` / `OpenAiApiClient()`).
- `aiRepositoryProvider`: `LlmAiRepository(ref.watch(llmClientProvider), …)`.
- `AiKeyNotifier`: tracks key state for the **active** provider; re-inits when
  the active provider changes (watch `activeAiProviderProvider`). `submit`,
  `validate`, `clear` operate on the active provider's storage key.
- `anthropicKeyMaskedProvider` → `activeKeyMaskedProvider`: masks the active
  provider's stored key.

### 5. Settings UI (`settings_screen.dart`)

`_AnthropicKeySection` → `_AiProviderSection`:

- A `TetherSegmentedButtonGroup` (Anthropic | OpenAI) bound to
  `activeAiProviderProvider`; switching it re-points the key UI.
- Key field, console link, and prefix hint read from the active
  `AiProvider`'s metadata.
- Section title generic: "AI provider". Cost/disclaimer copy generalized to
  "your provider" instead of "Anthropic".

## Testing

- `OpenAiApiClient`: `complete` parses `choices[0].message.content`;
  `validateKey` returns true/false/throws for 200/401/5xx (mock Dio).
- `SecureApiKeyStore`/`InMemoryApiKeyStore`: per-provider read/write/delete;
  legacy `anthropic_api_key` → `llm_key_anthropic` migration runs once.
- `AiKeyNotifier`: switching active provider re-inits key state; `submit`
  persists under the right provider key.

## Out of scope (YAGNI)

- Model picker UI.
- Using multiple providers simultaneously.
- Provider-specific feature gating (all features work on both via `complete()`).
- Streaming responses.

## Pre-completion

`dart run build_runner build -d`, `dart format --line-length 120 --set-exit-if-changed .`,
`dart analyze`, `flutter test`.
