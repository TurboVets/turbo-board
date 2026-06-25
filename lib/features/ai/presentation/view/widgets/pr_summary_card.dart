// lib/features/ai/presentation/view/widgets/pr_summary_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../pr_detail/data/models/pr_detail.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

/// AI PR Summary: a 3-bullet TL;DR generated on demand from the PR.
class PrSummaryCard extends ConsumerWidget {
  const PrSummaryCard({super.key, required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final summary = ref.watch(prSummaryControllerProvider(detail.slug));

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI SUMMARY', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 12),
          if (!ready)
            const _NeedsKey(message: 'Add your Anthropic API key to enable AI summaries.')
          else
            switch (summary) {
              null => AiPrimaryButton(
                label: 'SUMMARIZE WITH AI',
                onPressed: () => ref.read(prSummaryControllerProvider(detail.slug).notifier).generate(detail),
              ),
              AsyncLoading() => const _Spinner(),
              AsyncError(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
                  const SizedBox(height: 8),
                  AiGhostButton(
                    label: 'TRY AGAIN',
                    onPressed: () => ref.read(prSummaryControllerProvider(detail.slug).notifier).generate(detail),
                  ),
                ],
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectionArea(
                    child: Column(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  AiGhostButton(
                    label: 'REGENERATE',
                    onPressed: () => ref.read(prSummaryControllerProvider(detail.slug).notifier).generate(detail),
                  ),
                ],
              ),
            },
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

class _NeedsKey extends StatelessWidget {
  const _NeedsKey({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: TbText.body(size: 13, color: TbColors.muted)),
        const SizedBox(height: 10),
        AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings')),
      ],
    );
  }
}
