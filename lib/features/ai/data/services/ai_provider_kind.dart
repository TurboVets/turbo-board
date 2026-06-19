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
