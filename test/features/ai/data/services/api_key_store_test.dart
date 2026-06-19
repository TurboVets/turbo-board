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
    final store = InMemoryApiKeyStore(keys: {AiProvider.anthropic: 'seed'}, active: AiProvider.anthropic);
    expect(await store.read(AiProvider.anthropic), 'seed');
    expect(await store.readActiveProvider(), AiProvider.anthropic);
  });
}
