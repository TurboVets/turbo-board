import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';

void main() {
  test('mock repo returns the ordered columns', () async {
    final result = await const MockProjectsBoardRepository().fetchBoard();
    final data = switch (result) {
      ResultSuccess(:final data) => data,
      ResultFailure(:final message) => fail(message),
    };
    expect(data.columns.map((c) => c.status).toList(), boardColumnOrder);
    expect(data.hasAnyCards, isTrue);
  });
}
