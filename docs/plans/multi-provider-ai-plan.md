# Multi-Provider AI (BYOK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users pick their LLM provider (Anthropic / OpenAI / Google Gemini) and bring their own key for each, without changing any AI feature behavior (PR Summary, Reply Drafter, Sprint Brief). The existing Anthropic path stays the default.

**Why this is cheap:** The current design already isolated the provider well. `AiRepository` + `AnthropicAiRepository` only call `client.complete(prompt, maxTokens)` and `client.validateKey()` — they know nothing Anthropic-specific. Prompt builders (`ai_prompts.dart`), `Result` handling, and all UI controllers (`PrSummaryController`, `ReplyDraftController`, `AiKeyState`) are already provider-agnostic and reused as-is. **~80% of the code is untouched.** The work concentrates in the client, the key store, provider wiring, and Settings copy.

**Tech Stack:** Flutter, `dio` (existing), `flutter_secure_storage` (existing), Riverpod with codegen. No new dependencies — each provider is a REST call over the existing Dio pattern.

**Scope notes:**
- In scope: a `LlmClient` interface, three client impls (Anthropic existing + OpenAI + Gemini), per-provider key storage, a persisted provider-selection setting, and a provider picker in Settings.
- Out of scope: streaming, per-feature model overrides, tool use, provider-specific advanced params. Keep single-turn `complete()`.
- The existing single-provider behavior must remain the default (Anthropic, `claude-haiku-4-5`) so nothing regresses for current users.

---

## Provider differences (reference)

| Concern | Anthropic | OpenAI | Gemini |
|---|---|---|---|
| Base URL | `api.anthropic.com` | `api.openai.com` | `generativelanguage.googleapis.com` |
| Auth | `x-api-key: KEY` + `anthropic-version` | `Authorization: Bearer KEY` | `?key=KEY` query param |
| Endpoint | `/v1/messages` | `/v1/chat/completions` | `/v1beta/models/{model}:generateContent` |
| Token field | `max_tokens` (required) | `max_completion_tokens` | `generationConfig.maxOutputTokens` |
| Messages | `messages:[{role,content}]` | `messages:[{role,content}]` | `contents:[{role,parts:[{text}]}]` |
| Response text | `content[].text` (type==text) | `choices[].message.content` | `candidates[].content.parts[].text` |
| Default model | `claude-haiku-4-5` | `gpt-4o-mini` | `gemini-2.0-flash` |
| Key prefix (UI hint) | `sk-ant-` | `sk-` | (no fixed prefix) |
| Validate-key call | 1-token `/v1/messages` | 1-token `/v1/chat/completions` | minimal `:generateContent` |

---

## Tasks

### Task 1 — `LlmClient` interface + provider enum

- [ ] Create `lib/features/ai/data/services/llm_client.dart`:
  - `abstract interface class LlmClient { Future<String> complete({required String prompt, int maxTokens}); Future<bool> validateKey(); }`
  - `enum LlmProvider { anthropic, openai, gemini }` with extension getters: `label`, `keyStorageKey` (e.g. `${name}_api_key`), `defaultModel`, `keyHint` (UI prefix hint), `consoleUrl`, `consoleLabel`.
- [ ] No behavior change yet — interface only.

### Task 2 — Make the existing Anthropic client implement `LlmClient`

- [ ] In `anthropic_api_client.dart`, add `implements LlmClient`. Signatures already match (`complete`, `validateKey`) — zero body change expected.
- [ ] Confirm `dart analyze` passes.

### Task 3 — Add OpenAI + Gemini clients

- [ ] `lib/features/ai/data/services/openai_api_client.dart` — `implements LlmClient`. Mirror `AnthropicApiClient`'s structure (private `_build()` Dio, `setKey`, `validateStatus < 500`). Bearer auth, `/v1/chat/completions`, parse `choices[0].message.content`.
- [ ] `lib/features/ai/data/services/gemini_api_client.dart` — `implements LlmClient`. Key as `?key=` query param, `:generateContent`, parse `candidates[0].content.parts[].text`.
- [ ] Each takes `{Dio? dio, String? apiKey}` and exposes `setKey(String?)` like the Anthropic client.
- [ ] **Secrets:** never log keys; key only in the request header/query, never in error messages.

### Task 4 — Per-provider key storage

- [ ] Extend `ApiKeyStore` to be provider-aware: `read(LlmProvider)`, `write(LlmProvider, key)`, `delete(LlmProvider)` — store under `provider.keyStorageKey`.
- [ ] Keep `SecureApiKeyStore` + `InMemoryApiKeyStore`. In-memory uses a `Map<LlmProvider,String>`.
- [ ] **Migration:** on first read, if the legacy `anthropic_api_key` slot exists, treat it as the Anthropic key (the new key name is the same string `anthropic_api_key`, so this is automatic — verify).

### Task 5 — Provider-selection state (persisted)

- [ ] Add a persisted `selectedLlmProvider` setting. Store the enum name via `flutter_secure_storage` (or the existing settings store if one exists — check `lib/features/settings/`).
- [ ] `@Riverpod(keepAlive: true) class LlmProviderNotifier` — `build()` reads stored selection (default `anthropic`); `select(LlmProvider)` persists + updates state.

### Task 6 — Rewire providers in `ai_provider.dart`

- [ ] Replace `anthropicApiClientProvider` with `llmClientProvider` that watches `LlmProviderNotifier` and returns the matching client impl, seeded with that provider's stored key.
- [ ] Rename `AnthropicAiRepository` → `LlmAiRepository` (or keep the name, just depend on `LlmClient`). It already only uses `complete`/`validateKey` — change the field type from `AnthropicApiClient` to `LlmClient`.
- [ ] `AiKeyNotifier` `_init`/`submit`/`validate`/`clear` now read/write the key for the **selected** provider, and call `setKey` on the selected client.
- [ ] `anthropicKeyMasked` → `selectedProviderKeyMasked` (re-reads on provider switch too).
- [ ] Run `dart run build_runner build -d` after provider/notifier edits.

### Task 7 — Settings UI: provider picker + provider-aware key section

- [ ] In `settings_screen.dart`, rename `_AnthropicKeySection` → `_AiProviderSection` (or add a provider selector above it).
- [ ] Add a provider picker (`TetherSegmentedButtonGroup` or a dropdown) bound to `LlmProviderNotifier`.
- [ ] Make the key section copy provider-driven: console URL/label, key-prefix hint (`keyHint`), masked-key display — all from `LlmProvider` getters instead of hardcoded Anthropic strings.
- [ ] Saved/validating/error states already exist — keep them, just key them off the selected provider.

### Task 8 — Tests

- [ ] `test/features/ai/data/services/` — one test per client: mock Dio, assert request shape (URL, headers/query, body, token field) and response parsing (happy + 401 + 500). Cover `validateKey` true/false/throw.
- [ ] `test/features/ai/data/services/api_key_store_test.dart` — per-provider read/write/delete isolation.
- [ ] `test/features/ai/presentation/providers/ai_provider_test.dart` — switching provider swaps the client + key; submit persists under the right slot; existing summary/reply/brief controllers still pass with a fake `LlmClient`.
- [ ] Follow the repo's test conventions (mockito `@GenerateMocks`, `ProviderContainer`, AAA, test-summary header).

---

## Pre-completion checklist

- [ ] `dart run build_runner build -d`
- [ ] `dart format --line-length 120 --set-exit-if-changed .`
- [ ] `dart analyze`
- [ ] `flutter test`
- [ ] Manual: switch provider in Settings, paste a key for each you have, validate, run a PR Summary + Reply Draft against each.

## Risk / notes

- **CORS on web:** direct OpenAI/Gemini calls from a browser may hit CORS like the existing Anthropic path (see `web-firebase-hosting-plan.md`). Verify each provider on `flutter run -d chrome`; document any that need a proxy.
- **Cost:** defaults pick the cheapest small model per provider. Keep `maxTokens` bounds (400 summary / 300 reply / 320 brief) unchanged.
- **No regression:** default provider is Anthropic; a user who never opens the picker sees identical behavior.
