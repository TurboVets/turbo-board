// lib/features/pr_inbox/presentation/view/pr_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/board/board_columns.dart';
import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/turbo_mark.dart';
import '../../../ai/presentation/view/widgets/ai_triage_pane.dart';
import '../../../filters/presentation/helpers/pr_filtering.dart';
import '../../../filters/presentation/providers/filters_provider.dart';
import '../../../filters/presentation/view/widgets/filter_bar.dart';
import '../../data/models/pr_data.dart';
import '../providers/pr_inbox_provider.dart';
import 'widgets/pr_column.dart';

/// The PR Board — open PRs across watched repos, in columns by review state.
class PrInboxScreen extends HookConsumerWidget {
  const PrInboxScreen({super.key});

  static const String routeName = 'prInbox';

  // Column order, left to right: (reviewState, label, accentColor)
  static const _columns = <(PrReviewState, String, Color)>[
    (PrReviewState.needsReview, 'NEEDS REVIEW', TbBoard.needsReview),
    (PrReviewState.changesRequested, 'CHANGES REQUESTED', TbBoard.changesRequested),
    (PrReviewState.approved, 'APPROVED', TbBoard.approved),
    (PrReviewState.waitingOnAuthor, 'WAITING ON AUTHOR', TbBoard.waiting),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final showFilters = useState(false);
    // Watch prInboxProvider directly so error/loading states propagate correctly.
    // Active filters + client-side search are applied in the data branch.
    final prs = ref.watch(prInboxProvider);
    final filters = ref.watch(activeFiltersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Topbar(
          query: query.value,
          onQueryChanged: (v) => query.value = v,
          onRefresh: () => ref.invalidate(prInboxProvider),
          // Reloading on top of existing data (skipLoadingOnReload keeps the board up).
          isRefreshing: prs.isLoading && prs.hasValue,
          filtersOpen: showFilters.value,
          filterCount: filters.activeFacetCount,
          onToggleFilters: () => showFilters.value = !showFilters.value,
        ),
        if (showFilters.value) const FilterBar(),
        Expanded(
          child: prs.when(
            // skipLoadingOnReload: show error state instead of loading when
            // the provider reloads after a previous error (auto-dispose cycle).
            skipLoadingOnReload: true,
            loading: () => const _LoadingState(),
            error: (err, _) => _ErrorState(message: '$err', onRetry: () => ref.invalidate(prInboxProvider)),
            data: (items) {
              // Apply active filters, then client-side search.
              final afterFilters = applyFilters(items, filters);
              final q = query.value.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? afterFilters
                  : afterFilters.where((p) {
                      return p.title.toLowerCase().contains(q) ||
                          p.repo.toLowerCase().contains(q) ||
                          '#${p.number}'.contains(q) ||
                          '${p.number}'.contains(q);
                    }).toList();
              if (filtered.isEmpty) {
                final canReset = q.isNotEmpty || !filters.isEmpty;
                return _EmptyState(
                  onReset: canReset
                      ? () {
                          query.value = '';
                          ref.read(activeFiltersProvider.notifier).clear();
                        }
                      : null,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI Board Triage — ranks the currently-shown PRs.
                  AiTriagePane(prs: filtered),
                  Expanded(child: _Board(items: filtered)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Topbar ──────────────────────────────────────────────────────────────────

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.query,
    required this.onQueryChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.filtersOpen,
    required this.filterCount,
    required this.onToggleFilters,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool filtersOpen;
  final int filterCount;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0x99141418), // rgba(20,20,24,.6)
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          // Screen title
          Text('PR Board', style: TbText.display(size: 14, tracking: 2.0)),
          const SizedBox(width: 14),
          // Search field
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _SearchField(value: query, onChanged: onQueryChanged),
            ),
          ),
          const Spacer(),
          const BoardFitToggle(boardId: 'pr-inbox'),
          const SizedBox(width: 8),
          // REFRESH button
          _OutlineButton(label: isRefreshing ? 'REFRESHING' : 'REFRESH', onPressed: onRefresh, busy: isRefreshing),
          const SizedBox(width: 8),
          // FILTERS toggle — opens the inline filter bar; shows active count.
          _OutlineButton(
            label: filterCount > 0 ? 'FILTERS · $filterCount' : 'FILTERS',
            onPressed: onToggleFilters,
            active: filtersOpen || filterCount > 0,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: TbText.body(size: 13, color: TbColors.text),
      decoration: InputDecoration(
        hintText: 'Search PRs — title, repo, #number',
        hintStyle: TbText.body(size: 13, color: TbColors.dim),
        filled: true,
        fillColor: TbColors.canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: TbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: TbColors.blue),
        ),
        isDense: true,
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed, this.active = false, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool active;

  /// When true, shows a spinner and ignores taps (e.g. a refresh in flight).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final fg = !enabled
        ? TbColors.dim
        : active
        ? TbColors.cyan
        : TbColors.text;
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: !enabled ? TbColors.border : (active ? TbColors.cyan : TbColors.borderStrong)),
        backgroundColor: active ? TbColors.navy : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: TbText.label(size: 12, tracking: 0.8),
      ),
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: TbColors.dim)),
                const SizedBox(width: 8),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}

// ─── Board grid ───────────────────────────────────────────────────────────────

/// The board column a PR belongs to. Drafts are never shown under NEEDS REVIEW —
/// a draft isn't ready for review yet, so it sits in WAITING ON AUTHOR until the
/// author marks it ready, regardless of its GitHub review decision.
PrReviewState _columnState(PrData pr) => pr.isDraft ? PrReviewState.waitingOnAuthor : pr.reviewState;

/// Opens the PR detail overlay for [pr]; shared by the desktop and mobile boards.
void _openPr(BuildContext context, PrData pr) {
  final parts = pr.repo.split('/');
  if (parts.length != 2) return;
  // push (not go) so the board stays below the overlay drawer
  context.pushNamed('prDetail', pathParameters: {'owner': parts[0], 'repo': parts[1], 'number': '${pr.number}'});
}

/// Chooses between the desktop 4-column board and the phone single-column board
/// with a horizontal column selector.
class _Board extends StatelessWidget {
  const _Board({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    return context.isMobile ? _MobileBoard(items: items) : _DesktopBoard(items: items);
  }
}

/// Desktop/tablet: all four columns side by side, horizontally scrollable.
class _DesktopBoard extends StatelessWidget {
  const _DesktopBoard({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    return BoardColumnsRow(
      boardId: 'pr-inbox',
      padding: const EdgeInsets.all(8),
      columnVerticalInset: 16,
      columns: [
        for (final (state, label, accent) in PrInboxScreen._columns)
          BoardColumnSpec(
            weight: 280,
            scrollWidth: 280,
            child: PrColumn(
              title: label,
              accent: accent,
              prs: items.where((p) => _columnState(p) == state).toList(),
              onCardTap: (pr) => _openPr(context, pr),
            ),
          ),
      ],
    );
  }
}

/// Phone: a horizontal pill selector (one chip per column, with its count) above
/// a single full-width column showing only the selected review state.
class _MobileBoard extends HookWidget {
  const _MobileBoard({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    final selected = useState(PrInboxScreen._columns.first.$1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column selector pills.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (final (state, label, accent) in PrInboxScreen._columns) ...[
                _ColumnPill(
                  label: label.split(' ').first,
                  count: items.where((p) => _columnState(p) == state).length,
                  accent: accent,
                  selected: selected.value == state,
                  onTap: () => selected.value = state,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        // Selected column, full width.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Builder(
              builder: (context) {
                final (state, label, accent) = PrInboxScreen._columns.firstWhere((c) => c.$1 == selected.value);
                return PrColumn(
                  title: label,
                  accent: accent,
                  prs: items.where((p) => _columnState(p) == state).toList(),
                  onCardTap: (pr) => _openPr(context, pr),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnPill extends StatelessWidget {
  const _ColumnPill({
    required this.label,
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          border: Border.all(color: selected ? accent : TbColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$label · $count',
          style: TbText.label(
            size: 12,
            weight: FontWeight.w600,
            color: selected ? Colors.white : TbColors.muted,
            tracking: 0.72,
          ),
        ),
      ),
    );
  }
}

// ─── States ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 280,
              child: Container(
                decoration: BoxDecoration(
                  color: TbColors.surface,
                  border: Border.all(color: TbColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: TbColors.borderStrong,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Container(
                        height: 13,
                        width: 120,
                        decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int j = 0; j < 2; j++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Container(
                          height: 96,
                          decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Opacity(opacity: 0.45, child: TurboMark(size: 44, muted: true)),
          const SizedBox(height: 18),
          Text('NO OPEN PRS MATCH', style: TbText.display(size: 14, color: TbColors.muted, tracking: 2.0)),
          const SizedBox(height: 8),
          Text(
            'Nothing across your watched repos matches the current filters and search.',
            style: TbText.body(size: 13, color: TbColors.dim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _OutlineButton(label: 'RESET FILTERS', onPressed: onReset),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: TbSignal.bad.bg,
              border: Border.all(color: TbSignal.bad.border),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('✕ SYNC FAILED', style: TbText.label(size: 12, color: TbSignal.bad.text, tracking: 1.0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Could not load PRs. $message', style: TbText.body(size: 13, color: TbSignal.bad.text)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TbSignal.bad.text,
                    side: BorderSide(color: TbSignal.bad.border),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    textStyle: TbText.label(size: 11, tracking: 0.8),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
