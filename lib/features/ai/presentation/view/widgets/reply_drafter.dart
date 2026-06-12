// lib/features/ai/presentation/view/widgets/reply_drafter.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_detail/data/models/pr_detail.dart';
import '../../helpers/ai_prompts.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

/// AI Reply Drafter: pick a canned intent → editable draft → copy to clipboard.
class ReplyDrafter extends HookConsumerWidget {
  const ReplyDrafter({super.key, required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final draft = ref.watch(replyDraftControllerProvider(detail.slug));
    final controller = useTextEditingController();

    // Sync the editable field whenever a fresh draft arrives.
    final value = draft is AsyncData<String> ? draft.value : null;
    useEffect(() {
      if (value != null) controller.text = value;
      return null;
    }, [value]);

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
          Text('DRAFT A REPLY', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 12),
          if (!ready)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your Anthropic API key to draft replies.',
                  style: TbText.body(size: 13, color: TbColors.muted),
                ),
                const SizedBox(height: 10),
                AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings')),
              ],
            )
          else ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final intent in ReplyIntent.values)
                  AiGhostButton(
                    label: intent.label,
                    onPressed: () =>
                        ref.read(replyDraftControllerProvider(detail.slug).notifier).generate(detail, intent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            switch (draft) {
              null => const SizedBox.shrink(),
              AsyncLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              AsyncError(:final error) => Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
              AsyncData() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 3,
                    style: TbText.body(size: 13, color: TbColors.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: TbColors.canvas,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  ),
                  const SizedBox(height: 10),
                  AiPrimaryButton(
                    label: 'COPY TO CLIPBOARD',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: controller.text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft copied')));
                      }
                    },
                  ),
                ],
              ),
            },
          ],
        ],
      ),
    );
  }
}
