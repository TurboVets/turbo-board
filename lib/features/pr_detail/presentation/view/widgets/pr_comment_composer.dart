// lib/features/pr_detail/presentation/view/widgets/pr_comment_composer.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../ai/presentation/helpers/ai_prompts.dart';
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../data/models/pr_detail.dart';
import '../../providers/pr_composer_provider.dart';

/// The PR conversation composer: leave a comment, draft one with AI, or submit a
/// review (Approve / Request changes). Mirrors the design's composer block.
class PrCommentComposer extends HookConsumerWidget {
  const PrCommentComposer({super.key, required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = detail.repo.split('/');
    final owner = parts.isNotEmpty ? parts.first : '';
    final name = parts.length > 1 ? parts[1] : '';

    final controller = useTextEditingController();
    final showAi = useState(false);
    final composer = ref.watch(prComposerProvider(owner: owner, name: name, number: detail.number));
    final submitting = composer is AsyncLoading;
    final prId = detail.id;
    final canWrite = prId != null;

    // AI draft plumbing (shared with the Draft-a-reply card).
    final aiReady = ref.watch(aiKeyReadyProvider);
    final draft = ref.watch(replyDraftControllerProvider(detail.slug));
    final draftValue = draft is AsyncData<String> ? draft.value : null;
    useEffect(() {
      if (draftValue != null && draftValue.isNotEmpty) controller.text = draftValue;
      return null;
    }, [draftValue]);

    // Surface success / failure of a submit.
    ref.listen(prComposerProvider(owner: owner, name: name, number: detail.number), (prev, next) {
      if (!context.mounted) return;
      if (next is AsyncData) {
        controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to GitHub')));
      } else if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${next.error}')));
      }
    });

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Comment text area
          TextField(
            controller: controller,
            enabled: canWrite && !submitting,
            minLines: 3,
            maxLines: 8,
            style: TbText.body(size: 13, color: TbColors.text),
            decoration: InputDecoration(
              hintText: canWrite ? 'Leave a comment…' : 'Reload the PR to comment.',
              hintStyle: TbText.body(size: 13, color: TbColors.dim),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
          // AI intent chips (toggled by "AI Draft reply")
          if (showAi.value && aiReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: _AiDraftRow(detail: detail, draft: draft),
            ),
          // Action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: TbColors.border)),
            ),
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final busy = submitting;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ComposerBtn(
                      label: 'AI DRAFT REPLY',
                      baseBorder: TbColors.cyan,
                      baseText: TbSignal.info.text,
                      hoverBorder: TbColors.cyan,
                      hoverText: TbSignal.info.text,
                      hoverBg: TbColors.navy,
                      onPressed: busy
                          ? null
                          : () {
                              if (!aiReady) {
                                context.go('/settings');
                              } else {
                                showAi.value = !showAi.value;
                              }
                            },
                    ),
                    _ComposerBtn(
                      label: 'REQUEST CHANGES',
                      hoverBorder: TbSignal.bad.border,
                      hoverText: TbSignal.bad.text,
                      onPressed: (canWrite && hasText && !busy)
                          ? () => ref
                                .read(prComposerProvider(owner: owner, name: name, number: detail.number).notifier)
                                .requestChanges(prId, controller.text.trim())
                          : null,
                    ),
                    _ComposerBtn(
                      label: 'APPROVE',
                      hoverBorder: TbSignal.ok.border,
                      hoverText: TbSignal.ok.text,
                      onPressed: (canWrite && !busy)
                          ? () => ref
                                .read(prComposerProvider(owner: owner, name: name, number: detail.number).notifier)
                                .approve(prId, controller.text.trim())
                          : null,
                    ),
                    _ComposerBtn(
                      label: 'COMMENT',
                      filled: true,
                      busy: busy,
                      onPressed: (canWrite && hasText && !busy)
                          ? () => ref
                                .read(prComposerProvider(owner: owner, name: name, number: detail.number).notifier)
                                .comment(prId, controller.text.trim())
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Intent chips + draft state shown when "AI Draft reply" is expanded. Selecting
/// an intent generates a draft, which is auto-inserted into the comment field.
class _AiDraftRow extends ConsumerWidget {
  const _AiDraftRow({required this.detail, required this.draft});

  final PrDetail detail;
  final AsyncValue<String>? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final intent in ReplyIntent.values)
              _ComposerBtn(
                label: intent.label.toUpperCase(),
                baseBorder: TbColors.border,
                baseText: TbColors.muted,
                hoverBorder: TbColors.cyan,
                hoverText: TbColors.cyan,
                onPressed: () => ref.read(replyDraftControllerProvider(detail.slug).notifier).generate(detail, intent),
              ),
          ],
        ),
        switch (draft) {
          AsyncLoading() => const Padding(
            padding: EdgeInsets.only(top: 10),
            child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          AsyncError(:final error) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('$error', style: TbText.body(size: 12, color: TbSignal.bad.border)),
          ),
          AsyncData() => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Draft inserted below — edit, then Comment.',
              style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.5),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _ComposerBtn extends StatefulWidget {
  const _ComposerBtn({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.busy = false,
    this.baseBorder = TbColors.borderStrong,
    this.baseText = TbColors.text,
    this.hoverBorder = TbColors.blue,
    this.hoverText = TbColors.blue,
    this.hoverBg,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;
  final Color baseBorder;
  final Color baseText;
  final Color hoverBorder;
  final Color hoverText;
  final Color? hoverBg;

  @override
  State<_ComposerBtn> createState() => _ComposerBtnState();
}

class _ComposerBtnState extends State<_ComposerBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final hovered = _hover && enabled;

    final Color bg;
    final Color border;
    final Color fg;
    if (widget.filled) {
      bg = hovered ? TbColors.cyan : TbColors.blue;
      border = bg;
      fg = const Color(0xFFFFFFFF);
    } else {
      bg = hovered ? (widget.hoverBg ?? const Color(0x00000000)) : const Color(0x00000000);
      border = hovered ? widget.hoverBorder : widget.baseBorder;
      fg = hovered ? widget.hoverText : widget.baseText;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: widget.filled ? 14 : 12, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.busy
                ? const SizedBox(height: 13, width: 13, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    widget.label,
                    style: TbText.label(size: 11, weight: FontWeight.w600, color: fg, tracking: 0.66),
                  ),
          ),
        ),
      ),
    );
  }
}
