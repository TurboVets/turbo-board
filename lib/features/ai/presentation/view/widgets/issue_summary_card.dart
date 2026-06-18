// lib/features/ai/presentation/view/widgets/issue_summary_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../issue_detail/data/models/issue_detail.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

/// AI Issue TL;DR: 3 bullets generated on demand. Gradient top rule per design.
class IssueSummaryCard extends ConsumerWidget {
  const IssueSummaryCard({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final summary = ref.watch(issueSummaryControllerProvider(issue.slug));
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0A3161), Color(0xFF13ACFF), Color(0xFF0A3161)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TbBadge('AI', TbSignal.info, small: true),
                    const SizedBox(width: 8),
                    Text('TL;DR', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!ready)
                  _needsKey(context)
                else
                  switch (summary) {
                    null => AiPrimaryButton(
                      label: 'SUMMARIZE WITH AI',
                      onPressed: () => ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                    ),
                    AsyncLoading() => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    AsyncError(:final error) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
                        const SizedBox(height: 8),
                        AiGhostButton(
                          label: 'TRY AGAIN',
                          onPressed: () =>
                              ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                        ),
                      ],
                    ),
                    AsyncData(:final value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final bullet in value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, right: 8),
                                  child: TbSignalDot(color: TbColors.cyan, size: 6),
                                ),
                                Expanded(child: Text(bullet, style: TbText.body(size: 13, height: 1.4))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        AiGhostButton(
                          label: 'REGENERATE',
                          onPressed: () =>
                              ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                        ),
                      ],
                    ),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _needsKey(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Add your Anthropic API key to enable AI summaries.', style: TbText.body(size: 13, color: TbColors.muted)),
      const SizedBox(height: 10),
      AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings')),
    ],
  );
}
