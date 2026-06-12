// lib/features/filters/presentation/view/widgets/filter_bar.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_inbox/data/models/pr_data.dart';
import '../../../../repo_setup/presentation/providers/watched_repos_provider.dart';
import '../../../data/models/pr_filters.dart';
import '../../providers/filters_provider.dart';

String _statusLabel(PrStatus s) => switch (s) {
  PrStatus.open => 'Open',
  PrStatus.draft => 'Draft',
  PrStatus.merged => 'Merged',
  PrStatus.closed => 'Closed',
};

String _reviewLabel(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'Needs my review',
  PrReviewState.changesRequested => 'Changes requested',
  PrReviewState.approved => 'Approved',
  PrReviewState.waitingOnAuthor => 'Waiting on author',
};

String _ciLabel(PrCiState s) => switch (s) {
  PrCiState.failing => 'Failing',
  PrCiState.pending => 'Pending',
  PrCiState.passing => 'Passing',
};

String _repoName(String slug) => slug.contains('/') ? slug.split('/').last : slug;

/// Inline filter bar shown beneath the board topbar (no dedicated screen).
/// Edits the shared [activeFiltersProvider]; the board reacts immediately.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(activeFiltersProvider);
    final notifier = ref.read(activeFiltersProvider.notifier);
    final watched = ref.watch(watchedReposProvider);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: TbColors.railBg,
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (watched.isNotEmpty)
            _Group(
              label: 'REPOSITORIES',
              chips: [
                for (final slug in watched)
                  _Chip(
                    label: _repoName(slug),
                    selected: filters.repos.contains(slug),
                    onTap: () => notifier.toggleRepo(slug),
                  ),
              ],
            ),
          _Group(
            label: 'STATUS',
            chips: [
              for (final s in PrStatus.values)
                _Chip(
                  label: _statusLabel(s),
                  selected: filters.statuses.contains(s),
                  onTap: () => notifier.toggleStatus(s),
                ),
            ],
          ),
          _Group(
            label: 'REVIEW',
            chips: [
              for (final s in PrReviewState.values)
                _Chip(
                  label: _reviewLabel(s),
                  selected: filters.reviewStates.contains(s),
                  onTap: () => notifier.toggleReviewState(s),
                ),
            ],
          ),
          _Group(
            label: 'CI',
            chips: [
              for (final s in PrCiState.values)
                _Chip(
                  label: _ciLabel(s),
                  selected: filters.ciStates.contains(s),
                  onTap: () => notifier.toggleCiState(s),
                ),
            ],
          ),
          if (!filters.isEmpty) ...[const SizedBox(height: 10), _ClearButton(onTap: notifier.clear)],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.chips});

  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.1)),
            ),
          ),
          Expanded(child: Wrap(spacing: 7, runSpacing: 7, children: chips)),
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? TbColors.navy : (_hovered ? TbColors.surface : Colors.transparent),
            border: Border.all(color: selected ? TbColors.cyan : TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TbText.label(
              size: 11,
              weight: FontWeight.w500,
              color: selected ? TbColors.cyan : TbColors.muted,
              tracking: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text('CLEAR ALL FILTERS', style: TbText.label(size: 11, color: TbColors.cyan, tracking: 0.8)),
      ),
    );
  }
}
