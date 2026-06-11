# AI Features v1 (BYOK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bring-your-own-key Anthropic AI features to Mobile TurboBoard: an API-key settings screen, a shared Messages API client, PR Summary, and Reply Drafter.

**Architecture:** A self-contained `lib/ai/` module (key storage, API client, prompt builders, service) with no dependency on the rest of the app except a small `PrData` model. UI layer is one settings screen plus two reusable widgets (`PrSummaryCard`, `ReplyDrafterSheet`) that the future PR Detail screen will embed. All network/storage classes take injected dependencies so everything is unit-testable with `MockClient` and an in-memory key store.

**Tech Stack:** Flutter (desktop/web per design README), `http` (+ `http/testing` for mocks), `flutter_secure_storage`. AI model: `claude-haiku-4-5` (cheap, fast — right fit for summaries/drafts).

**Scope notes:**
- The repo currently contains only `design/` (mockup). This plan scaffolds the Flutter project (Task 0) and builds the AI module against a minimal `PrData` model. GitHub integration (auth, PR inbox, real diffs) is a **separate plan**; this plan ends with a manual-test harness using sample data.
- Out of scope: Inbox Triage (#2), Review Assistant (#3), chatbot UI, posting to GitHub. See `docs/AI-FEATURES.md`.

**File structure:**

| File | Responsibility |
|---|---|
| `lib/models/pr_data.dart` | Minimal PR data passed to prompts |
| `lib/ai/api_key_store.dart` | `ApiKeyStore` interface + secure + in-memory impls |
| `lib/ai/anthropic_client.dart` | Messages API HTTP client + key validation + errors |
| `lib/ai/prompts.dart` | Prompt builders (summary, reply) + diff truncation |
| `lib/ai/ai_service.dart` | Facade: `summarizePr`, `draftReply` |
| `lib/screens/ai_settings_screen.dart` | Paste / validate / save / clear API key |
| `lib/widgets/pr_summary_card.dart` | "Summarize" button + result display |
| `lib/widgets/reply_drafter_sheet.dart` | Intent picker + editable draft |
| `lib/main.dart` | Temporary demo harness with sample PR |

---

### Task 0: Scaffold Flutter project

**Files:**
- Create: Flutter project at repo root (keeps existing `design/` and `docs/`)
- Modify: `pubspec.yaml`

- [ ] **Step 1: Scaffold**

```bash
cd "<repo root>"
flutter create . --project-name mobile_turboboard --platforms=macos,windows,linux,web
```

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add http flutter_secure_storage
```

- [ ] **Step 3: Verify baseline**

Run: `flutter test`
Expected: the generated `widget_test.dart` passes (or delete it now; it will break once we replace `main.dart` — deleting is fine).

- [ ] **Step 4: Commit**

```bash
git init 2>/dev/null; git add -A && git commit -m "chore: scaffold Flutter project with http + flutter_secure_storage"
```

---

### Task 1: PrData model

**Files:**
- Create: `lib/models/pr_data.dart`
- Test: `test/models/pr_data_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/models/pr_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/models/pr_data.dart';

void main() {
  test('slug combines repo and number', () {
    final pr = PrData(
      repo: 'turbovets/api',
      number: 42,
      title: 'Add rate limiting',
      body: 'Limits requests per token',
      author: 'sang',
      reviewState: 'review_required',
      ciState: 'passing',
      updatedAt: DateTime.utc(2026, 6, 10),
    );
    expect(pr.slug, 'turbovets/api#42');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/pr_data_test.dart`
Expected: FAIL — `pr_data.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/models/pr_data.dart
class PrData {
  final String repo;       // "owner/name"
  final int number;
  final String title;
  final String? body;
  final String author;
  final String reviewState; // e.g. review_required | changes_requested | approved
  final String ciState;     // passing | pending | failing
  final DateTime updatedAt;

  const PrData({
    required this.repo,
    required this.number,
    required this.title,
    this.body,
    required this.author,
    required this.reviewState,
    required this.ciState,
    required this.updatedAt,
  });

  String get slug => '$repo#$number';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/pr_data_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/pr_data.dart test/models/pr_data_test.dart
git commit -m "feat: add PrData model"
```

---

### Task 2: ApiKeyStore

**Files:**
- Create: `lib/ai/api_key_store.dart`
- Test: `test/ai/api_key_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/ai/api_key_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/ai/api_key_store.dart';

void main() {
  test('in-memory store round-trips and clears a key', () async {
    final store = InMemoryApiKeyStore();
    expect(await store.read(), isNull);
    await store.write('sk-ant-test123');
    expect(await store.read(), 'sk-ant-test123');
    await store.clear();
    expect(await store.read(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai/api_key_store_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ai/api_key_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's Anthropic API key. Never log the key.
abstract class ApiKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> clear();
}

/// Production impl backed by Keychain / Keystore / libsecret.
class SecureApiKeyStore implements ApiKeyStore {
  static const _k = 'anthropic_api_key';
  final FlutterSecureStorage _storage;
  const SecureApiKeyStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() => _storage.read(key: _k);
  @override
  Future<void> write(String key) => _storage.write(key: _k, value: key);
  @override
  Future<void> clear() => _storage.delete(key: _k);
}

/// Test / demo impl.
class InMemoryApiKeyStore implements ApiKeyStore {
  String? _key;
  @override
  Future<String?> read() async => _key;
  @override
  Future<void> write(String key) async => _key = key;
  @override
  Future<void> clear() async => _key = null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai/api_key_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ai/api_key_store.dart test/ai/api_key_store_test.dart
git commit -m "feat: add ApiKeyStore with secure and in-memory implementations"
```

---

### Task 3: AnthropicClient

**Files:**
- Create: `lib/ai/anthropic_client.dart`
- Test: `test/ai/anthropic_client_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/ai/anthropic_client_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_turboboard/ai/anthropic_client.dart';

void main() {
  test('complete sends correct request and joins text blocks', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'Hello '},
            {'type': 'text', 'text': 'world'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = AnthropicClient(apiKey: 'sk-ant-x', httpClient: mock);

    final out = await client.complete(system: 'be brief', user: 'hi');

    expect(out, 'Hello world');
    expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(captured.headers['x-api-key'], 'sk-ant-x');
    expect(captured.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-haiku-4-5');
    expect(body['system'], 'be brief');
    expect(body['messages'], [
      {'role': 'user', 'content': 'hi'}
    ]);
  });

  test('non-200 throws AnthropicException with API error message', () async {
    final mock = MockClient((_) async => http.Response(
        jsonEncode({
          'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}
        }),
        401));
    final client = AnthropicClient(apiKey: 'bad', httpClient: mock);

    expect(
      () => client.complete(user: 'hi'),
      throwsA(isA<AnthropicException>()
          .having((e) => e.statusCode, 'status', 401)
          .having((e) => e.isInvalidKey, 'isInvalidKey', true)
          .having((e) => e.message, 'message', 'invalid x-api-key')),
    );
  });

  test('validateKey returns true on 200, false on 401, rethrows others',
      () async {
    Future<bool> run(int status) {
      final mock = MockClient((_) async => http.Response(
          status == 200
              ? jsonEncode({'content': [{'type': 'text', 'text': 'ok'}]})
              : jsonEncode({'error': {'message': 'x'}}),
          status));
      return AnthropicClient(apiKey: 'k', httpClient: mock).validateKey();
    }

    expect(await run(200), isTrue);
    expect(await run(401), isFalse);
    expect(() => run(429), throwsA(isA<AnthropicException>()));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai/anthropic_client_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ai/anthropic_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AnthropicException implements Exception {
  final int statusCode;
  final String message;
  const AnthropicException(this.statusCode, this.message);

  bool get isInvalidKey => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'AnthropicException($statusCode): $message';
}

/// Thin client for the Anthropic Messages API (BYOK — key supplied by user).
class AnthropicClient {
  static const defaultModel = 'claude-haiku-4-5';
  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const _apiVersion = '2023-06-01';

  final String apiKey;
  final http.Client _http;

  AnthropicClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Single-turn completion. Returns concatenated text blocks.
  Future<String> complete({
    String? system,
    required String user,
    String model = defaultModel,
    int maxTokens = 1024,
  }) async {
    final res = await _http.post(
      _endpoint,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        if (system != null && system.isNotEmpty) 'system': system,
        'messages': [
          {'role': 'user', 'content': user}
        ],
      }),
    );

    if (res.statusCode != 200) {
      String msg = res.body;
      try {
        msg = (jsonDecode(res.body)['error']?['message'] as String?) ?? msg;
      } catch (_) {/* keep raw body */}
      throw AnthropicException(res.statusCode, msg);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final blocks = (json['content'] as List<dynamic>? ?? const []);
    return blocks
        .map((b) => (b as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
  }

  /// Cheapest possible call to check the key works.
  Future<bool> validateKey() async {
    try {
      await complete(user: 'ping', maxTokens: 1);
      return true;
    } on AnthropicException catch (e) {
      if (e.isInvalidKey) return false;
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai/anthropic_client_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ai/anthropic_client.dart test/ai/anthropic_client_test.dart
git commit -m "feat: add AnthropicClient with key validation and error handling"
```

---

### Task 4: Prompt builders

**Files:**
- Create: `lib/ai/prompts.dart`
- Test: `test/ai/prompts_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/ai/prompts_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/ai/prompts.dart';
import 'package:mobile_turboboard/models/pr_data.dart';

PrData _pr() => PrData(
      repo: 'turbovets/api',
      number: 42,
      title: 'Add rate limiting',
      body: 'Limits requests per token',
      author: 'sang',
      reviewState: 'review_required',
      ciState: 'failing',
      updatedAt: DateTime.utc(2026, 6, 10),
    );

void main() {
  test('summary prompt includes PR fields and diff', () {
    final p = buildSummaryPrompt(pr: _pr(), diff: '+ added line');
    expect(p, contains('turbovets/api#42'));
    expect(p, contains('Add rate limiting'));
    expect(p, contains('Limits requests per token'));
    expect(p, contains('+ added line'));
  });

  test('summary prompt truncates huge diffs', () {
    final huge = 'x' * (kMaxDiffChars + 1000);
    final p = buildSummaryPrompt(pr: _pr(), diff: huge);
    expect(p.length, lessThan(kMaxDiffChars + 2000));
    expect(p, contains('[diff truncated]'));
  });

  test('reply prompt reflects intent and context', () {
    final p = buildReplyPrompt(
        pr: _pr(), intent: ReplyIntent.nudgeReviewer, extraContext: 'due Friday');
    expect(p, contains('turbovets/api#42'));
    expect(p, contains(ReplyIntent.nudgeReviewer.instruction));
    expect(p, contains('due Friday'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai/prompts_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ai/prompts.dart
import '../models/pr_data.dart';

const int kMaxDiffChars = 50000;

const String kSummarySystem =
    'You are a code-review assistant inside a GitHub PR dashboard. '
    'Summarize pull requests for a busy maintainer. Reply with exactly three '
    'bullet points: (1) what changed, (2) why / intent, (3) risk or review '
    'focus. Be concrete. No preamble.';

const String kReplySystem =
    'You draft short, friendly, professional GitHub PR comments on behalf of '
    'the user. Reply with the comment text only — no preamble, no quotes, '
    'no signature.';

enum ReplyIntent {
  nudgeReviewer('Politely nudge the requested reviewers for a review.'),
  requestChanges('Summarize concerns and ask the author for changes.'),
  approve('Approve with a short, appreciative comment.'),
  askForUpdate('Ask the author for a status update on this PR.');

  const ReplyIntent(this.instruction);
  final String instruction;
}

String _prHeader(PrData pr) => '''
PR: ${pr.slug} — ${pr.title}
Author: ${pr.author}
Review state: ${pr.reviewState} | CI: ${pr.ciState} | Updated: ${pr.updatedAt.toIso8601String()}
Description:
${pr.body ?? '(no description)'}''';

String buildSummaryPrompt({required PrData pr, required String diff}) {
  var d = diff;
  if (d.length > kMaxDiffChars) {
    d = '${d.substring(0, kMaxDiffChars)}\n[diff truncated]';
  }
  return '''
${_prHeader(pr)}

Diff:
$d''';
}

String buildReplyPrompt({
  required PrData pr,
  required ReplyIntent intent,
  String? extraContext,
}) =>
    '''
${_prHeader(pr)}

Task: ${intent.instruction}
${extraContext == null || extraContext.isEmpty ? '' : 'Additional context from the user: $extraContext'}''';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai/prompts_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ai/prompts.dart test/ai/prompts_test.dart
git commit -m "feat: add prompt builders for PR summary and reply drafting"
```

---

### Task 5: AiService facade

**Files:**
- Create: `lib/ai/ai_service.dart`
- Test: `test/ai/ai_service_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/ai/ai_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_turboboard/ai/ai_service.dart';
import 'package:mobile_turboboard/ai/anthropic_client.dart';
import 'package:mobile_turboboard/ai/prompts.dart';
import 'package:mobile_turboboard/models/pr_data.dart';

PrData _pr() => PrData(
      repo: 'turbovets/api',
      number: 42,
      title: 'Add rate limiting',
      author: 'sang',
      reviewState: 'approved',
      ciState: 'passing',
      updatedAt: DateTime.utc(2026, 6, 10),
    );

AiService _service(void Function(Map<String, dynamic> body) onBody) =>
    AiService(AnthropicClient(
      apiKey: 'k',
      httpClient: MockClient((req) async {
        onBody(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({'content': [{'type': 'text', 'text': 'RESULT'}]}), 200);
      }),
    ));

void main() {
  test('summarizePr uses summary system prompt and returns text', () async {
    late Map<String, dynamic> body;
    final out = await _service((b) => body = b).summarizePr(_pr(), '+ diff');
    expect(out, 'RESULT');
    expect(body['system'], kSummarySystem);
    expect(body['messages'][0]['content'], contains('+ diff'));
  });

  test('draftReply uses reply system prompt and intent', () async {
    late Map<String, dynamic> body;
    final out = await _service((b) => body = b)
        .draftReply(_pr(), ReplyIntent.approve);
    expect(out, 'RESULT');
    expect(body['system'], kReplySystem);
    expect(body['messages'][0]['content'],
        contains(ReplyIntent.approve.instruction));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai/ai_service_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ai/ai_service.dart
import '../models/pr_data.dart';
import 'anthropic_client.dart';
import 'prompts.dart';

/// High-level AI operations used by the UI.
class AiService {
  final AnthropicClient client;
  const AiService(this.client);

  Future<String> summarizePr(PrData pr, String diff) => client.complete(
        system: kSummarySystem,
        user: buildSummaryPrompt(pr: pr, diff: diff),
        maxTokens: 512,
      );

  Future<String> draftReply(PrData pr, ReplyIntent intent,
          {String? extraContext}) =>
      client.complete(
        system: kReplySystem,
        user: buildReplyPrompt(pr: pr, intent: intent, extraContext: extraContext),
        maxTokens: 512,
      );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai/ai_service_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ai/ai_service.dart test/ai/ai_service_test.dart
git commit -m "feat: add AiService facade for summarize and reply drafting"
```

---

### Task 6: AI Settings screen

**Files:**
- Create: `lib/screens/ai_settings_screen.dart`
- Test: `test/screens/ai_settings_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/ai_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/ai/api_key_store.dart';
import 'package:mobile_turboboard/screens/ai_settings_screen.dart';

Widget _app(ApiKeyStore store, {Future<bool> Function(String)? validate}) =>
    MaterialApp(
      home: AiSettingsScreen(
        keyStore: store,
        validateKey: validate ?? (_) async => true,
      ),
    );

void main() {
  testWidgets('valid key is saved and confirmed', (tester) async {
    final store = InMemoryApiKeyStore();
    await tester.pumpWidget(_app(store));

    await tester.enterText(find.byType(TextField), 'sk-ant-good');
    await tester.tap(find.text('Validate & Save'));
    await tester.pumpAndSettle();

    expect(await store.read(), 'sk-ant-good');
    expect(find.text('Key saved — AI features enabled.'), findsOneWidget);
  });

  testWidgets('invalid key is not saved', (tester) async {
    final store = InMemoryApiKeyStore();
    await tester.pumpWidget(_app(store, validate: (_) async => false));

    await tester.enterText(find.byType(TextField), 'sk-ant-bad');
    await tester.tap(find.text('Validate & Save'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
    expect(find.text('Invalid API key.'), findsOneWidget);
  });

  testWidgets('remove clears the stored key', (tester) async {
    final store = InMemoryApiKeyStore()..write('sk-ant-old');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove key'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/ai_settings_screen_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/screens/ai_settings_screen.dart
import 'package:flutter/material.dart';
import '../ai/api_key_store.dart';

/// Settings screen for the user's Anthropic API key (BYOK).
/// [validateKey] is injected so tests don't hit the network; production
/// callers pass `(k) => AnthropicClient(apiKey: k).validateKey()`.
class AiSettingsScreen extends StatefulWidget {
  final ApiKeyStore keyStore;
  final Future<bool> Function(String key) validateKey;

  const AiSettingsScreen(
      {super.key, required this.keyStore, required this.validateKey});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _hasKey = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    widget.keyStore.read().then((k) {
      if (mounted) setState(() => _hasKey = k != null);
    });
  }

  Future<void> _validateAndSave() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    setState(() { _busy = true; _status = null; });
    try {
      final ok = await widget.validateKey(key);
      if (ok) {
        await widget.keyStore.write(key);
        setState(() {
          _hasKey = true;
          _status = 'Key saved — AI features enabled.';
        });
        _controller.clear();
      } else {
        setState(() => _status = 'Invalid API key.');
      }
    } catch (e) {
      setState(() => _status = 'Could not validate key: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    await widget.keyStore.clear();
    setState(() { _hasKey = false; _status = 'Key removed.'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI features use your own Anthropic API key. Create one at '
              'console.anthropic.com (Settings → API keys). Usage is billed '
              'to your account. The key is stored only on this device.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Anthropic API key',
                hintText: 'sk-ant-...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton(
                onPressed: _busy ? null : _validateAndSave,
                child: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Validate & Save'),
              ),
              const SizedBox(width: 12),
              if (_hasKey)
                OutlinedButton(
                    onPressed: _busy ? null : _remove,
                    child: const Text('Remove key')),
            ]),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_status!),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/ai_settings_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/ai_settings_screen.dart test/screens/ai_settings_screen_test.dart
git commit -m "feat: add AI settings screen with key validation and secure save"
```

---

### Task 7: PrSummaryCard widget

**Files:**
- Create: `lib/widgets/pr_summary_card.dart`
- Test: `test/widgets/pr_summary_card_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/widgets/pr_summary_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/widgets/pr_summary_card.dart';

void main() {
  testWidgets('shows summary after tapping Summarize', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrSummaryCard(summarize: () async => '• did a thing'),
      ),
    ));

    await tester.tap(find.text('Summarize with AI'));
    await tester.pumpAndSettle();

    expect(find.text('• did a thing'), findsOneWidget);
  });

  testWidgets('shows error message on failure', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrSummaryCard(summarize: () async => throw Exception('boom')),
      ),
    ));

    await tester.tap(find.text('Summarize with AI'));
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/pr_summary_card_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/pr_summary_card.dart
import 'package:flutter/material.dart';

/// Card for the PR Detail screen. [summarize] is injected by the caller,
/// typically `() => aiService.summarizePr(pr, diff)`.
class PrSummaryCard extends StatefulWidget {
  final Future<String> Function() summarize;
  const PrSummaryCard({super.key, required this.summarize});

  @override
  State<PrSummaryCard> createState() => _PrSummaryCardState();
}

class _PrSummaryCardState extends State<PrSummaryCard> {
  bool _busy = false;
  String? _summary;
  String? _error;

  Future<void> _run() async {
    setState(() { _busy = true; _error = null; });
    try {
      final s = await widget.summarize();
      setState(() => _summary = s);
    } catch (e) {
      setState(() => _error = 'Summary failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 8),
              const Text('AI Summary',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _run,
                child: Text(_summary == null
                    ? 'Summarize with AI'
                    : 'Regenerate'),
              ),
            ]),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_summary != null) SelectableText(_summary!),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/pr_summary_card_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/pr_summary_card.dart test/widgets/pr_summary_card_test.dart
git commit -m "feat: add PrSummaryCard widget"
```

---

### Task 8: ReplyDrafterSheet widget

**Files:**
- Create: `lib/widgets/reply_drafter_sheet.dart`
- Test: `test/widgets/reply_drafter_sheet_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/widgets/reply_drafter_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_turboboard/ai/prompts.dart';
import 'package:mobile_turboboard/widgets/reply_drafter_sheet.dart';

void main() {
  testWidgets('generates an editable draft for the chosen intent',
      (tester) async {
    ReplyIntent? used;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReplyDrafterSheet(draft: (intent) async {
          used = intent;
          return 'Hey, friendly nudge!';
        }),
      ),
    ));

    await tester.tap(find.text('Nudge reviewer'));
    await tester.pumpAndSettle();

    expect(used, ReplyIntent.nudgeReviewer);
    final field = tester.widget<TextField>(find.byKey(const Key('draftField')));
    expect(field.controller!.text, 'Hey, friendly nudge!');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/reply_drafter_sheet_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/reply_drafter_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/prompts.dart';

const _intentLabels = {
  ReplyIntent.nudgeReviewer: 'Nudge reviewer',
  ReplyIntent.requestChanges: 'Request changes',
  ReplyIntent.approve: 'Approve + thanks',
  ReplyIntent.askForUpdate: 'Ask for update',
};

/// Bottom sheet / panel for drafting PR comments. [draft] is injected,
/// typically `(intent) => aiService.draftReply(pr, intent)`.
class ReplyDrafterSheet extends StatefulWidget {
  final Future<String> Function(ReplyIntent intent) draft;
  const ReplyDrafterSheet({super.key, required this.draft});

  @override
  State<ReplyDrafterSheet> createState() => _ReplyDrafterSheetState();
}

class _ReplyDrafterSheetState extends State<ReplyDrafterSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _run(ReplyIntent intent) async {
    setState(() { _busy = true; _error = null; });
    try {
      _controller.text = await widget.draft(intent);
    } catch (e) {
      setState(() => _error = 'Draft failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final intent in ReplyIntent.values)
                ActionChip(
                  label: Text(_intentLabels[intent]!),
                  onPressed: _busy ? null : () => _run(intent),
                ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextField(
            key: const Key('draftField'),
            controller: _controller,
            maxLines: 6,
            decoration:
                const InputDecoration(hintText: 'Draft appears here — edit freely'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _controller.text)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/reply_drafter_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/reply_drafter_sheet.dart test/widgets/reply_drafter_sheet_test.dart
git commit -m "feat: add ReplyDrafterSheet widget with intent chips"
```

---

### Task 9: Demo harness + manual verification

**Files:**
- Modify: `lib/main.dart` (replace generated content)
- Delete: `test/widget_test.dart` (generated counter test, if still present)

- [ ] **Step 1: Replace main.dart with demo harness**

```dart
// lib/main.dart
// Temporary harness to exercise AI v1 features with sample data.
// Replaced by the real PR Inbox/Detail screens in the GitHub-integration plan.
import 'package:flutter/material.dart';
import 'ai/ai_service.dart';
import 'ai/anthropic_client.dart';
import 'ai/api_key_store.dart';
import 'models/pr_data.dart';
import 'screens/ai_settings_screen.dart';
import 'widgets/pr_summary_card.dart';
import 'widgets/reply_drafter_sheet.dart';

void main() => runApp(const TurboBoardApp());

final _samplePr = PrData(
  repo: 'turbovets/api',
  number: 42,
  title: 'Add rate limiting middleware',
  body: 'Adds a token-bucket rate limiter to all public endpoints.',
  author: 'sang',
  reviewState: 'review_required',
  ciState: 'passing',
  updatedAt: DateTime.now(),
);

const _sampleDiff = '''
diff --git a/lib/middleware/rate_limit.dart b/lib/middleware/rate_limit.dart
+class RateLimiter {
+  final int maxPerMinute;
+  RateLimiter(this.maxPerMinute);
+}
''';

class TurboBoardApp extends StatelessWidget {
  const TurboBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile TurboBoard — AI demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  static const _keyStore = SecureApiKeyStore();

  Future<AiService> _service() async {
    final key = await _keyStore.read();
    if (key == null) throw Exception('No API key — set one in AI Settings.');
    return AiService(AnthropicClient(apiKey: key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_samplePr.slug),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AiSettingsScreen(
                keyStore: _keyStore,
                validateKey: (k) =>
                    AnthropicClient(apiKey: k).validateKey(),
              ),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PrSummaryCard(
            summarize: () async =>
                (await _service()).summarizePr(_samplePr, _sampleDiff),
          ),
          const SizedBox(height: 16),
          Card(
            child: ReplyDrafterSheet(
              draft: (intent) async =>
                  (await _service()).draftReply(_samplePr, intent),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Remove stale generated test**

```bash
rm -f test/widget_test.dart
```

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: ALL PASS (≈14 tests across 7 files)

- [ ] **Step 4: Manual verification (requires a real API key)**

Run: `flutter run -d macos` (or `-d chrome`)
Checklist:
1. Open Settings → paste a bad key (`sk-ant-nope`) → "Invalid API key."
2. Paste a real key → "Key saved — AI features enabled."
3. Restart the app → key persists (Settings shows "Remove key").
4. Tap "Summarize with AI" → 3-bullet summary appears.
5. Tap "Nudge reviewer" → editable draft appears; Copy works.
6. Remove key → Summarize now shows the "No API key" error.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: demo harness wiring AI settings, summary, and reply drafter"
```

---

## Future work (not this plan)

- GitHub integration plan supplies real `PrData` + diffs and embeds `PrSummaryCard` / `ReplyDrafterSheet` in the PR Detail screen.
- Inbox Triage (#2): reuse `AnthropicClient` with a new prompt over the full inbox list.
- Review Assistant (#3) and posting drafts via the GitHub API.
- Streaming responses (`stream: true`) for nicer UX on long summaries.
