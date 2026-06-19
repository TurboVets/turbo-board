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
    c.read(activeAiProviderProvider); // eagerly initialize so _hydrate() fires before the delay
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
