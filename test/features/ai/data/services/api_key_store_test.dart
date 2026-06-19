// Test summary:
// - InMemoryApiKeyStore reads/writes/deletes per provider independently
// - active provider round-trips
// - seeded keys are returned per provider
// - SecureApiKeyStore migrates legacy anthropic_api_key to llm_key_anthropic on first read
// - SecureApiKeyStore skips migration if new key already present
// - SecureApiKeyStore never touches legacy key for other providers
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/api_key_store.dart';

import 'api_key_store_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
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

  group('SecureApiKeyStore migration', () {
    late MockFlutterSecureStorage storage;

    setUp(() {
      storage = MockFlutterSecureStorage();
    });

    test('migrates legacy key on first anthropic read', () async {
      // Stub: new key absent, legacy key present
      when(storage.read(key: 'llm_key_anthropic')).thenAnswer((_) async => null);
      when(storage.read(key: 'anthropic_api_key')).thenAnswer((_) async => 'old-key');
      when(storage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});
      when(storage.delete(key: anyNamed('key'))).thenAnswer((_) async {});

      final store = SecureApiKeyStore(storage);
      final result = await store.read(AiProvider.anthropic);

      expect(result, 'old-key');
      verify(storage.write(key: 'llm_key_anthropic', value: 'old-key')).called(1);
      verify(storage.delete(key: 'anthropic_api_key')).called(1);
    });

    test('no migration when new key already present', () async {
      // Stub: new key present
      when(storage.read(key: 'llm_key_anthropic')).thenAnswer((_) async => 'new-key');

      final store = SecureApiKeyStore(storage);
      final result = await store.read(AiProvider.anthropic);

      expect(result, 'new-key');
      verifyNever(storage.delete(key: anyNamed('key')));
      verifyNever(storage.write(key: anyNamed('key'), value: anyNamed('value')));
    });

    test('openai read never touches legacy key', () async {
      // Stub: openai key absent
      when(storage.read(key: 'llm_key_openai')).thenAnswer((_) async => null);

      final store = SecureApiKeyStore(storage);
      final result = await store.read(AiProvider.openai);

      expect(result, isNull);
      verifyNever(storage.read(key: 'anthropic_api_key'));
    });
  });
}
