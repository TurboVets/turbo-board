// lib/features/needs_attention/presentation/view/needs_attention_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../pr_inbox/presentation/view/widgets/pr_card.dart';
import '../helpers/triage.dart';
import '../providers/needs_attention_provider.dart';

/// Triage view: open PRs grouped into actionable categories. A PR can appear in
/// several sections. Reached via /needs-attention inside the shell.
class NeedsAttentionScreen extends ConsumerWidget {
  const NeedsAttentionScreen({super.key});

  static const String routeName = 'needsAttention';

  static TbSignal _signalFor(NeedsAttentionCategory c) => switch (c) {
    NeedsAttentionCategory.needsMyReview => TbSignal.info,
    NeedsAttentionCategory.changesRequested => TbSignal.bad,
    NeedsAttentionCategory.failingChecks => TbSignal.bad,
    NeedsAttentionCategory.draft => TbSignal.gray,
    NeedsAttentionCategory.stale => TbSignal.orange,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(needsAttentionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Topbar(onRefresh: () => ref.invalidate(prInboxProvider)),
        Expanded(
          child: grouped.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TbBadge('ERROR', TbSignal.bad),
                  const SizedBox(height: 12),
                  Text('Could not load PRs.\n$err', textAlign: TextAlign.center, style: TbText.body(size: 14)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.invalidate(prInboxProvider),
                    child: Text('Retry', style: TbText.body(size: 14, color: TbColors.cyan)),
                  ),
                ],
              ),
            ),
            data: (groups) {
              final nonEmpty = groups.entries.where((e) => e.value.isNotEmpty).toList();
              if (nonEmpty.isEmpty) {
                return Center(
                  child: Text(
                    'Nothing needs attention. Inbox zero.',
                    style: TbText.body(size: 14, color: TbColors.muted),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in nonEmpty)
                          _CategorySection(category: entry.key, prs: entry.value, signal: _signalFor(entry.key)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Topbar extends ConsumerWidget {
  const _Topbar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(staleThresholdProvider);
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0x99141418),
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Text('Needs attention', style: TbText.display(size: 14, tracking: 2.0)),
          const Spacer(),
          Text('STALE AFTER', style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.1)),
          const SizedBox(width: 8),
          for (final days in staleThresholdOptions)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _ThresholdChip(
                days: days,
                selected: days == threshold,
                onTap: () => ref.read(staleThresholdProvider.notifier).set(days),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({required this.days, required this.selected, required this.onTap});

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? TbColors.surface : Colors.transparent,
            border: Border.all(color: selected ? TbColors.borderStrong : TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${days}d',
            style: TbText.label(
              size: 11,
              weight: FontWeight.w600,
              color: selected ? TbColors.text : TbColors.muted,
              tracking: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.prs, required this.signal});

  final NeedsAttentionCategory category;
  final List<PrData> prs;
  final TbSignal signal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TbBadge('${category.label} · ${prs.length}', signal, small: true),
          ),
          for (final pr in prs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrCard(pr: pr, onTap: () => _openDetail(context, pr)),
            ),
        ],
      ),
    );
  }

  static void _openDetail(BuildContext context, PrData pr) {
    final parts = pr.repo.split('/');
    if (parts.length != 2) return;
    // push (not go) so the board stays below the overlay drawer
    context.pushNamed('prDetail', pathParameters: {'owner': parts[0], 'repo': parts[1], 'number': '${pr.number}'});
  }
}
