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
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_core/core.dart';

import 'ai_repository_test.mocks.dart';

@GenerateMocks([Dio, AiRepository])
void main() {
  late MockDio anthropicDio;
  late MockDio githubDio;
  late LlmAiRepository repo;

  setUp(() {
    anthropicDio = MockDio();
    githubDio = MockDio();
    when(anthropicDio.options).thenReturn(BaseOptions());
    when(githubDio.options).thenReturn(BaseOptions());
    repo = LlmAiRepository(AnthropicApiClient(dio: anthropicDio), GithubApiClient(dio: githubDio));
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

  SprintReport report() => const SprintReport(
    sprintName: 'Sprint 24',
    dateRange: 'Jun 2 – Jun 16',
    daysRemaining: 6,
    totalTickets: 60,
    pointsCommitted: 168,
    repoCount: 4,
    forecastLabel: 'Trending ~2D behind',
    forecastDetail: '58 of 133 done',
    pointsDone: 84,
    estimatedTickets: 48,
    estimatedPoints: 168,
    unestimatedTickets: 12,
    burndown: Burndown(committedPoints: 168, totalDays: 14, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 14),
  );

  final emptyFlow = SprintFlow(start: DateTime(2026, 6, 15), end: DateTime(2026, 6, 26), days: const []);

  CockpitData cockpit() => CockpitData(
    sprint: SprintHealth(
      name: 'Sprint 24',
      daysRemaining: 6,
      endLabel: 'Jun 16',
      totalIssues: 60,
      repoCount: 4,
      done: 30,
      inProgress: 12,
      inReview: 8,
      notStarted: 7,
      atRisk: 3,
      unestimated: 12,
    ),
    team: [],
    stuck: [],
    flow: emptyFlow,
  );

  group('sprint narratives', () {
    test('summarizeSprint returns trimmed prose', () async {
      stubAnthropic(msg(textContent('  Sprint 24 is on track.  ')));
      final r = await repo.summarizeSprint(report());
      expect((r as ResultSuccess<String>).data, 'Sprint 24 is on track.');
    });

    test('summarizeSprint fails on empty model output', () async {
      stubAnthropic(msg(textContent('   ')));
      expect(await repo.summarizeSprint(report()), isA<ResultFailure<String>>());
    });

    test('digestSprint returns trimmed bullets', () async {
      stubAnthropic(msg(textContent('- Shipped 12\n- 3 at risk')));
      final r = await repo.digestSprint(report());
      expect((r as ResultSuccess<String>).data, contains('Shipped 12'));
    });

    test('weeklyDigest returns trimmed bullets', () async {
      stubAnthropic(msg(textContent('- Shipped 9 items this week')));
      final r = await repo.weeklyDigest(cockpit());
      expect((r as ResultSuccess<String>).data, contains('this week'));
    });

    test('weeklyDigest surfaces a failure on a 500', () async {
      stubAnthropic(msg(null, status: 500));
      expect(await repo.weeklyDigest(cockpit()), isA<ResultFailure<String>>());
    });

    test('dailyStandup returns trimmed bullets', () async {
      stubAnthropic(msg(textContent('IN REVIEW\n- #412 (alice, 2d)\nBLOCKED\n- none\nNEXT\n- nudge alice  ')));
      final r = await repo.dailyStandup(cockpit());
      expect((r as ResultSuccess<String>).data, contains('IN REVIEW'));
    });

    test('dailyStandup surfaces a failure on a 500', () async {
      stubAnthropic(msg(null, status: 500));
      expect(await repo.dailyStandup(cockpit()), isA<ResultFailure<String>>());
    });
  });
}
