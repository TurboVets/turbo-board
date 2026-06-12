// Test summary:
// - default ActiveFilters is empty
// - toggle adds then removes a facet value
// - activeFacetCount counts non-empty facets
// - clear resets to empty
// - toggleRepoVisibility hides one repo (seeds from all watched) then restores it
// - toggleRepoVisibility collapses to "all" (empty) once every repo is visible
// - hiding the last visible repo collapses back to "all"
// - isRepoVisible reflects the allowlist
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

  group('toggleRepoVisibility (nav rail)', () {
    const watched = ['org/a', 'org/b', 'org/c'];

    test('hides one repo by seeding from all watched, then restores it', () {
      notifier().toggleRepoVisibility('org/b', watched);
      expect(state().repos, {'org/a', 'org/c'});
      expect(notifier().isRepoVisible('org/b'), isFalse);

      notifier().toggleRepoVisibility('org/b', watched);
      // back to all visible → collapses to the empty ("all") set
      expect(state().repos, isEmpty);
    });

    test('collapses to "all" once every repo is re-included', () {
      // narrow to only org/a via the filter bar, then show the other two
      notifier().toggleRepo('org/a');
      expect(state().repos, {'org/a'});
      notifier().toggleRepoVisibility('org/b', watched);
      notifier().toggleRepoVisibility('org/c', watched);
      expect(state().repos, isEmpty);
    });

    test('hiding the last visible repo collapses back to all', () {
      notifier().toggleRepoVisibility('org/a', watched);
      notifier().toggleRepoVisibility('org/b', watched);
      expect(state().repos, {'org/c'});
      notifier().toggleRepoVisibility('org/c', watched); // hide the last one
      expect(state().repos, isEmpty);
    });
  });

  group('isRepoVisible', () {
    test('all visible when no repo facet set', () {
      expect(notifier().isRepoVisible('org/a'), isTrue);
    });

    test('only allowlisted repos visible once set', () {
      notifier().toggleRepo('org/a');
      expect(notifier().isRepoVisible('org/a'), isTrue);
      expect(notifier().isRepoVisible('org/b'), isFalse);
    });
  });
}
