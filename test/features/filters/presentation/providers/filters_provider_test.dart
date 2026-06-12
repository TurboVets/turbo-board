// Test summary:
// - default ActiveFilters is empty
// - toggle adds then removes a facet value
// - activeFacetCount counts non-empty facets
// - clear resets to empty
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/filters/data/models/pr_filters.dart';
import 'package:turbo_board/features/filters/presentation/providers/filters_provider.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  ActiveFilters notifier() => container.read(activeFiltersProvider.notifier);
  PrFilters state() => container.read(activeFiltersProvider);

  test('default is empty', () {
    expect(state().isEmpty, isTrue);
    expect(state().activeFacetCount, 0);
  });

  test('toggle adds then removes a facet value', () {
    notifier().toggleStatus(PrStatus.draft);
    expect(state().statuses, {PrStatus.draft});
    notifier().toggleStatus(PrStatus.draft);
    expect(state().statuses, isEmpty);
  });

  test('activeFacetCount counts non-empty facets', () {
    notifier().toggleRepo('org/a');
    notifier().toggleCiState(PrCiState.failing);
    expect(state().activeFacetCount, 2);
  });

  test('clear resets to empty', () {
    notifier().toggleRepo('org/a');
    notifier().toggleReviewState(PrReviewState.approved);
    notifier().clear();
    expect(state().isEmpty, isTrue);
  });
}
