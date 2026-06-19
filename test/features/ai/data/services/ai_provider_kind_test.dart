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
