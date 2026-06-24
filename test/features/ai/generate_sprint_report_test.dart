// Test summary:
// - valid JSON from the LLM yields a populated Result.success report
// - malformed JSON yields a Result.success EMPTY report (parser is lenient) -> we treat empty exec summary as failure
// - LLM throwing yields Result.failure
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/data/services/llm_client.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

import 'generate_sprint_report_test.mocks.dart';

@GenerateMocks([LlmClient, GithubApiClient])
SprintReport _report() => const SprintReport(
  sprintName: 'Sprint 24',
  dateRange: 'Jun 10 - Jun 24',
  daysRemaining: 2,
  totalTickets: 47,
  pointsCommitted: 120,
  repoCount: 3,
  forecastLabel: 'behind',
  forecastDetail: 'd',
  behind: true,
  pointsDone: 82,
  estimatedTickets: 41,
  estimatedPoints: 110,
  unestimatedTickets: 6,
  burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
);

void main() {
  late MockLlmClient llm;
  late MockGithubApiClient gh;
  late AiRepository repo;

  setUp(() {
    llm = MockLlmClient();
    gh = MockGithubApiClient();
    repo = LlmAiRepository(llm, gh);
  });

  test('valid JSON yields a populated report', () async {
    when(
      llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens')),
    ).thenAnswer((_) async => '{"executiveSummary":"Closed 82/120.","outcome":"Good."}');
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultSuccess>());
    expect((result as ResultSuccess).data.executiveSummary, 'Closed 82/120.');
  });

  test('empty/garbage response yields failure', () async {
    when(
      llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens')),
    ).thenAnswer((_) async => 'sorry no json');
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultFailure>());
  });

  test('LLM throwing yields failure', () async {
    when(llm.complete(prompt: anyNamed('prompt'), maxTokens: anyNamed('maxTokens'))).thenThrow(Exception('boom'));
    final result = await repo.generateSprintReport(_report());
    expect(result, isA<ResultFailure>());
  });
}
