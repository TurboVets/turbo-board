// Test summary:
// - buildBoardInsightsPrompt embeds each non-empty column's facts and asks for JSON.
// - parseBoardInsights decodes a JSON object keyed by status label into IssueStatus.
// - parseBoardInsights tolerates surrounding prose and drops empty/unknown keys.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';

void main() {
  test('prompt includes facts and requests JSON', () {
    final board = ProjectBoardData(
      title: 'B',
      columns: [
        const BoardColumn(
          status: IssueStatus.inProgress,
          label: 'In Progress',
          facts: ColumnFacts(p0Unowned: 1, stuckCount: 2, ciRedNumbers: [155]),
        ),
      ],
    );
    final prompt = buildBoardInsightsPrompt(board);
    expect(prompt, contains('In Progress'));
    expect(prompt, contains('JSON'));
    expect(prompt, contains('155'));
  });

  test('parses JSON object embedded in prose', () {
    const text = 'Here you go:\n{"In Progress":"2 stuck >4d · CI red on #155","Done":""}\nThanks';
    final map = parseBoardInsights(text);
    expect(map[IssueStatus.inProgress], '2 stuck >4d · CI red on #155');
    expect(map.containsKey(IssueStatus.done), isFalse); // empty dropped
  });
}
