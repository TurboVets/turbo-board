// lib/features/ai/presentation/view/widgets/issue_next_action_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../issue_detail/data/models/issue_detail.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

class IssueNextActionCard extends ConsumerWidget {
  const IssueNextActionCard({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final next = ref.watch(issueNextActionControllerProvider(issue.slug));
    final notifier = ref.read(issueNextActionControllerProvider(issue.slug).notifier);
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT ACTION', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 10),
          if (!ready)
            AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings'))
          else
            switch (next) {
              null => AiGhostButton(label: '✦ SUGGEST NEXT ACTION', onPressed: () => notifier.generate(issue)),
              AsyncLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              AsyncError(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
                  const SizedBox(height: 8),
                  AiGhostButton(label: 'TRY AGAIN', onPressed: () => notifier.generate(issue)),
                ],
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectionArea(child: Text(value, style: TbText.body(size: 13, height: 1.4))),
                  const SizedBox(height: 8),
                  AiGhostButton(label: 'CLEAR', onPressed: notifier.clear),
                ],
              ),
            },
        ],
      ),
    );
  }
}
