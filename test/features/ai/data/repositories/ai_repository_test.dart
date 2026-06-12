// Test summary:
// - validateKey returns true on 200, false on 401, failure on 500
// - summarize fetches the diff, calls Anthropic, and returns parsed bullets
// - summarize still succeeds (no diff) when the diff fetch fails
// - draftReply returns the trimmed model text
// - summarize surfaces a failure when the model returns no bullets
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/data/services/anthropic_api_client.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_core/core.dart';

import 'ai_repository_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio anthropicDio;
  late MockDio githubDio;
  late AnthropicAiRepository repo;

  setUp(() {
    anthropicDio = MockDio();
    githubDio = MockDio();
    when(anthropicDio.options).thenReturn(BaseOptions());
    when(githubDio.options).thenReturn(BaseOptions());
    repo = AnthropicAiRepository(AnthropicApiClient(dio: anthropicDio), GithubApiClient(dio: githubDio));
  });

  Response<Map<String, dynamic>> msg(Map<String, dynamic>? data, {int status = 200}) => Response(
    requestOptions: RequestOptions(path: '/v1/messages'),
    statusCode: status,
    data: data,
  );

  Map<String, dynamic> textContent(String t) => {
    'content': [
      {'type': 'text', 'text': t},
    ],
  };

  void stubAnthropic(Response<Map<String, dynamic>> response) {
    when(
      anthropicDio.post<Map<String, dynamic>>('/v1/messages', data: anyNamed('data')),
    ).thenAnswer((_) async => response);
  }

  PrDetail detail() => const PrDetail(
    repo: 'org/app',
    number: 7,
    title: 'Fix bug',
    state: PrState.open,
    author: 'sam',
    baseRefName: 'main',
    headRefName: 'fix',
    bodyMarkdown: 'desc',
  );

  group('validateKey', () {
    test('true on 200', () async {
      stubAnthropic(msg({}, status: 200));
      final r = await repo.validateKey();
      expect((r as ResultSuccess<bool>).data, isTrue);
    });

    test('false on 401', () async {
      stubAnthropic(msg(null, status: 401));
      final r = await repo.validateKey();
      expect((r as ResultSuccess<bool>).data, isFalse);
    });

    test('failure on 500', () async {
      stubAnthropic(msg(null, status: 500));
      expect(await repo.validateKey(), isA<ResultFailure<bool>>());
    });
  });

  group('summarize', () {
    test('fetches diff, returns parsed bullets', () async {
      when(githubDio.get<String>('/repos/org/app/pulls/7', options: anyNamed('options'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: 'diff --git a b',
        ),
      );
      stubAnthropic(msg(textContent('- one\n- two\n- three')));

      final r = await repo.summarize(detail());
      expect((r as ResultSuccess<List<String>>).data, ['one', 'two', 'three']);
    });

    test('succeeds without diff when diff fetch throws', () async {
      when(
        githubDio.get<String>('/repos/org/app/pulls/7', options: anyNamed('options')),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));
      stubAnthropic(msg(textContent('- only point')));

      final r = await repo.summarize(detail());
      expect((r as ResultSuccess<List<String>>).data, ['only point']);
    });

    test('failure when no bullets returned', () async {
      when(githubDio.get<String>('/repos/org/app/pulls/7', options: anyNamed('options'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: '',
        ),
      );
      stubAnthropic(msg(textContent('   ')));

      expect(await repo.summarize(detail()), isA<ResultFailure<List<String>>>());
    });
  });

  group('draftReply', () {
    test('returns trimmed text', () async {
      stubAnthropic(msg(textContent('  Please take a look when you can.  ')));
      final r = await repo.draftReply(detail(), ReplyIntent.nudgeReviewer);
      expect((r as ResultSuccess<String>).data, 'Please take a look when you can.');
    });
  });
}
