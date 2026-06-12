// lib/features/pr_detail/presentation/view/pr_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../data/models/pr_detail.dart';
import '../providers/pr_detail_provider.dart';
import 'widgets/markdown_body.dart';
import 'widgets/pr_checks_panel.dart';
import 'widgets/pr_commit_card.dart';
import 'widgets/pr_reviewers_card.dart';
import 'widgets/pr_timeline.dart';

/// Read-only PR Detail. Reached via /pr/:owner/:repo/:number inside the shell.
class PrDetailScreen extends ConsumerWidget {
  const PrDetailScreen({super.key, required this.owner, required this.repo, required this.number});

  static const String routeName = 'prDetail';

  final String owner;
  final String repo;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(prDetailProvider(owner: owner, name: repo, number: number));

    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load PR.\n$err', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TetherActionButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(prDetailProvider(owner: owner, name: repo, number: number)),
            ),
          ],
        ),
      ),
      data: (d) => _DetailBody(detail: d),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('← Back to board', style: text.bodySmall?.copyWith(color: colors.foreground.link)),
          ),
        ),
        const SizedBox(height: 8),
        Text(detail.repo, style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
        const SizedBox(height: 4),
        Text('${detail.title}  #${detail.number}', style: text.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TetherBadge(label: _stateLabel(detail), color: _stateColor(detail), size: TetherBadgeSize.small),
            Text(
              '${detail.author} → ${detail.baseRefName}',
              style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (detail.bodyMarkdown.trim().isNotEmpty) MarkdownBody(detail.bodyMarkdown),
      ],
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        PrChecksPanel(checks: detail.checks),
        const SizedBox(height: 16),
        Text('Conversation', style: text.titleSmall),
        const SizedBox(height: 8),
        PrTimeline(events: detail.timeline),
      ],
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrReviewersCard(reviewers: detail.reviewers),
        const SizedBox(height: 12),
        if (detail.lastCommit != null) PrCommitCard(commit: detail.lastCommit!),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(children: [main, const SizedBox(height: 16), aside]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 24),
                  SizedBox(width: 280, child: aside),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _stateLabel(PrDetail d) => d.isDraft
    ? 'Draft'
    : switch (d.state) {
        PrState.open => 'Open',
        PrState.merged => 'Merged',
        PrState.closed => 'Closed',
      };

TetherBadgeColor _stateColor(PrDetail d) => d.isDraft
    ? TetherBadgeColor.gray
    : switch (d.state) {
        PrState.open => TetherBadgeColor.green,
        PrState.merged => TetherBadgeColor.purple,
        PrState.closed => TetherBadgeColor.red,
      };
