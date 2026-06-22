import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:turbo_core/core.dart';

import '../../../issue_detail/data/models/issue_detail.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../pr_detail/data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../projects_board/data/models/board_data.dart';
import '../../../repo_setup/data/services/github_api_client.dart';
import '../../../sprint_report/data/models/sprint_report.dart';
import '../../presentation/helpers/ai_prompts.dart';
import '../models/triage_item.dart';
import '../services/llm_client.dart';

/// AI features over the active LLM provider (BYOK). Errors are caught here
/// and surfaced as [Result] failures; nothing above the repo layer throws.
abstract class AiRepository {
  /// True if the stored key is valid, false if rejected (401).
  Future<Result<bool>> validateKey();

  /// 3-bullet TL;DR of the PR (title + description + diff).
  Future<Result<List<String>>> summarize(PrDetail detail);

  /// An editable reply draft in the given [intent].
  Future<Result<String>> draftReply(PrDetail detail, ReplyIntent intent);

  /// A short sprint-risk narrative for the Lead Cockpit, from the board state.
  Future<Result<String>> sprintBrief(CockpitData cockpit);

  /// Full prose summary of the current sprint (Sprint Report screen).
  Future<Result<String>> summarizeSprint(SprintReport report);

  /// Scannable bullet digest of the current sprint (Sprint Report screen).
  Future<Result<String>> digestSprint(SprintReport report);

  /// Weekly team pulse for the Lead Cockpit, from the current board snapshot.
  Future<Result<String>> weeklyDigest(CockpitData cockpit);

  /// Ranks the most action-worthy open PRs (review first / unblock / merge /
  /// nudge) from the current board.
  Future<Result<List<TriageItem>>> triage(List<PrData> prs);

  /// 3-bullet TL;DR of an issue (title + body + fields).
  Future<Result<List<String>>> summarizeIssue(IssueDetail issue);

  /// One short recommended next action for an issue.
  Future<Result<String>> suggestNextAction(IssueDetail issue);

  /// Per-column one-line board insights, keyed by status. Empty map if nothing notable.
  Future<Result<Map<IssueStatus, String>>> boardInsights(ProjectBoardData board);
}

class LlmAiRepository implements AiRepository {
  LlmAiRepository(this._llm, this._github);

  final LlmClient _llm;
  final GithubApiClient _github;

  /// Surfaces the provider's own error text (e.g. an OpenAI quota message) when
  /// the failure is an [LlmException]; otherwise the generic [fallback].
  static String _message(Object e, String fallback) => e is LlmException ? e.message : fallback;

  @override
  Future<Result<bool>> validateKey() async {
    try {
      return Result.success(await _llm.validateKey());
    } catch (e, stackTrace) {
      log('Failed to validate AI provider key', error: e, stackTrace: stackTrace);
      return Result.failure(
        _message(e, 'Could not reach the AI provider. Check your connection and try again.'),
        stackTrace,
      );
    }
  }

  @override
  Future<Result<List<String>>> summarize(PrDetail detail) async {
    try {
      final parts = detail.repo.split('/');
      final diff = parts.length == 2 ? await _fetchDiff(parts[0], parts[1], detail.number) : '';
      final text = await _llm.complete(prompt: buildSummaryPrompt(detail, diff), maxTokens: 400);
      final bullets = parseBullets(text);
      if (bullets.isEmpty) return Result.failure('The model returned an empty summary.', StackTrace.current);
      return Result.success(bullets);
    } catch (e, stackTrace) {
      log('Failed to summarize PR', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not generate a summary.'), stackTrace);
    }
  }

  @override
  Future<Result<String>> draftReply(PrDetail detail, ReplyIntent intent) async {
    try {
      final text = await _llm.complete(prompt: buildReplyPrompt(detail, intent), maxTokens: 300);
      return Result.success(text.trim());
    } catch (e, stackTrace) {
      log('Failed to draft reply', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not draft a reply.'), stackTrace);
    }
  }

  @override
  Future<Result<String>> sprintBrief(CockpitData cockpit) async {
    try {
      final text = await _llm.complete(prompt: buildSprintBriefPrompt(cockpit), maxTokens: 320);
      final trimmed = text.trim();
      if (trimmed.isEmpty) return Result.failure('The model returned an empty brief.', StackTrace.current);
      return Result.success(trimmed);
    } catch (e, stackTrace) {
      log('Failed to generate sprint brief', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not generate the sprint brief.'), stackTrace);
    }
  }

  /// Runs a single prompt and returns its trimmed text, or a [failure] message
  /// on an empty response / any error. Shared by the sprint narratives.
  Future<Result<String>> _narrative(String prompt, {int maxTokens = 400, required String failure}) async {
    try {
      final text = (await _llm.complete(prompt: prompt, maxTokens: maxTokens)).trim();
      if (text.isEmpty) return Result.failure('The model returned an empty response.', StackTrace.current);
      return Result.success(text);
    } catch (e, stackTrace) {
      log(failure, error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, failure), stackTrace);
    }
  }

  @override
  Future<Result<String>> summarizeSprint(SprintReport report) =>
      _narrative(buildSprintSummaryPrompt(report), maxTokens: 500, failure: 'Could not summarize the sprint.');

  @override
  Future<Result<String>> digestSprint(SprintReport report) =>
      _narrative(buildSprintDigestPrompt(report), maxTokens: 450, failure: 'Could not generate the sprint digest.');

  @override
  Future<Result<String>> weeklyDigest(CockpitData cockpit) =>
      _narrative(buildWeeklyDigestPrompt(cockpit), maxTokens: 450, failure: 'Could not generate the weekly digest.');

  @override
  Future<Result<List<TriageItem>>> triage(List<PrData> prs) async {
    try {
      if (prs.isEmpty) return Result.success(const []);
      final text = await _llm.complete(prompt: buildTriagePrompt(prs), maxTokens: 700);
      final items = parseTriage(text, prs);
      if (items.isEmpty) return Result.failure('The model returned no triage results.', StackTrace.current);
      return Result.success(items);
    } catch (e, stackTrace) {
      log('Failed to triage PRs', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not triage the board.'), stackTrace);
    }
  }

  @override
  Future<Result<List<String>>> summarizeIssue(IssueDetail issue) async {
    try {
      final text = await _llm.complete(prompt: buildIssueSummaryPrompt(issue), maxTokens: 350);
      final bullets = parseBullets(text);
      if (bullets.isEmpty) return Result.failure('The model returned an empty summary.', StackTrace.current);
      return Result.success(bullets);
    } catch (e, stackTrace) {
      log('Failed to summarize issue', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not generate a summary.'), stackTrace);
    }
  }

  @override
  Future<Result<String>> suggestNextAction(IssueDetail issue) async {
    try {
      final text = (await _llm.complete(prompt: buildNextActionPrompt(issue), maxTokens: 120)).trim();
      if (text.isEmpty) return Result.failure('The model returned no suggestion.', StackTrace.current);
      return Result.success(text);
    } catch (e, stackTrace) {
      log('Failed to suggest next action', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not suggest a next action.'), stackTrace);
    }
  }

  @override
  Future<Result<Map<IssueStatus, String>>> boardInsights(ProjectBoardData board) async {
    try {
      final text = await _llm.complete(prompt: buildBoardInsightsPrompt(board), maxTokens: 400);
      return Result.success(parseBoardInsights(text));
    } catch (e, stackTrace) {
      log('Failed to generate board insights', error: e, stackTrace: stackTrace);
      return Result.failure(_message(e, 'Could not generate board insights.'), stackTrace);
    }
  }

  /// Fetches the unified diff via GitHub REST. Returns '' on any failure so a
  /// summary can still be produced from title + description alone.
  Future<String> _fetchDiff(String owner, String repo, int number) async {
    try {
      final res = await _github.dio.get<String>(
        '/repos/$owner/$repo/pulls/$number',
        options: Options(headers: {'Accept': 'application/vnd.github.diff'}, responseType: ResponseType.plain),
      );
      return res.statusCode == 200 ? (res.data ?? '') : '';
    } catch (e) {
      log('Diff fetch failed; summarizing without diff', error: e);
      return '';
    }
  }
}
