// lib/features/ai/presentation/view/widgets/ai_triage_pane.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../pr_inbox/data/models/pr_data.dart';
import '../../../data/models/triage_item.dart';
import '../../providers/ai_provider.dart';

/// AI Board Triage — a strip above the board columns. Hit "Triage board" and
/// the model ranks the most action-worthy open PRs with a reason + action chip.
/// Wires to [TriageController]; rows open the matching PR detail.
class AiTriagePane extends ConsumerWidget {
  const AiTriagePane({super.key, required this.prs});

  /// The PRs currently shown on the board (after filters + search). Triage runs
  /// against this set so it re-ranks what the user is actually looking at.
  final List<PrData> prs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final triage = ref.watch(triageControllerProvider);
    final controller = ref.read(triageControllerProvider.notifier);

    final isReady = triage is AsyncData<List<TriageItem>>;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2px top accent gradient
          const SizedBox(
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [TbColors.navy, TbColors.cyan, TbColors.navy]),
              ),
            ),
          ),
          _Header(
            ready: ready,
            busy: triage is AsyncLoading,
            showDismiss: isReady,
            onRun: ready && prs.isNotEmpty ? () => controller.run(prs) : null,
            onDismiss: controller.dismiss,
            reRun: isReady,
          ),
          if (ready)
            switch (triage) {
              null => const SizedBox.shrink(),
              AsyncLoading() => const _Skeleton(),
              AsyncError(:final error) => _ErrorRow(
                message: '$error',
                onRetry: prs.isNotEmpty ? () => controller.run(prs) : null,
              ),
              AsyncData(:final value) => _Results(items: value, sourceCount: prs.length),
            },
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.ready,
    required this.busy,
    required this.showDismiss,
    required this.onRun,
    required this.onDismiss,
    required this.reRun,
  });

  final bool ready;
  final bool busy;
  final bool showDismiss;
  final VoidCallback? onRun;
  final VoidCallback onDismiss;
  final bool reRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TbColors.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // AI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: TbColors.navy,
              border: Border.all(color: TbColors.cyan),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('AI', style: TbText.label(size: 10, color: TbSignal.info.text, tracking: 0.8)),
          ),
          const SizedBox(width: 9),
          Text('BOARD TRIAGE', style: TbText.label(size: 11, tracking: 1.1)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ranks open PRs — review first · blocking · stale',
              style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 9),

          _TriageButton(
            label: busy
                ? 'RANKING…'
                : reRun
                ? '↻ RE-RUN'
                : 'TRIAGE BOARD',
            onPressed: busy ? null : onRun,
          ),
          if (showDismiss) ...[const SizedBox(width: 6), _DismissButton(onPressed: onDismiss)],
        ],
      ),
    );
  }
}

/// Cyan-outlined triage action button (design's primary triage CTA).
class _TriageButton extends StatefulWidget {
  const _TriageButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_TriageButton> createState() => _TriageButtonState();
}

class _TriageButtonState extends State<_TriageButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered && enabled ? TbColors.navy : Colors.transparent,
            border: Border.all(color: enabled ? TbColors.cyan : TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TbText.label(size: 10, color: enabled ? TbSignal.info.text : TbColors.dim, tracking: 0.8),
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatefulWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_DismissButton> createState() => _DismissButtonState();
}

class _DismissButtonState extends State<_DismissButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: _hovered ? TbColors.borderStrong : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('✕', style: TbText.body(size: 13, color: _hovered ? TbColors.text : TbColors.muted, height: 1.0)),
        ),
      ),
    );
  }
}

// ─── States ─────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in const [0.88, 0.72, 0.80])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FractionallySizedBox(
                widthFactor: w,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TbText.body(size: 13, color: TbSignal.bad.border)),
          ),
          if (onRetry != null) ...[const SizedBox(width: 12), _TriageButton(label: 'TRY AGAIN', onPressed: onRetry)],
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.items, required this.sourceCount});

  final List<TriageItem> items;
  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) _TriageRow(item: item),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Text(
            'Generated from $sourceCount open PRs · claude-haiku · BYOK — billed to your Anthropic account',
            style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.8),
          ),
        ),
      ],
    );
  }
}

class _TriageRow extends StatefulWidget {
  const _TriageRow({required this.item});

  final TriageItem item;

  @override
  State<_TriageRow> createState() => _TriageRowState();
}

class _TriageRowState extends State<_TriageRow> {
  bool _hovered = false;

  void _open() {
    final item = widget.item;
    final parts = item.repo.split('/');
    if (parts.length != 2) return;
    context.pushNamed('prDetail', pathParameters: {'owner': parts[0], 'repo': parts[1], 'number': '${item.number}'});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final signal = item.category.signal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _open,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered ? TbColors.surface2 : Colors.transparent,
            border: const Border(top: BorderSide(color: TbColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 22,
                child: Text(
                  item.rank.toString().padLeft(2, '0'),
                  style: TbText.display(size: 13, weight: FontWeight.w700, color: TbColors.cyan, tracking: 0.5),
                ),
              ),
              // Repo + dot
              SizedBox(
                width: 118,
                child: Row(
                  children: [
                    TbSignalDot(color: TbRepoColor.forSlug(item.repo), size: 8),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.repo,
                        style: TbText.label(size: 10, weight: FontWeight.w500, color: TbColors.muted, tracking: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Title + #num
              Expanded(
                flex: 10,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: item.title),
                      TextSpan(
                        text: ' #${item.number}',
                        style: TbText.body(size: 13, weight: FontWeight.w400, color: TbColors.muted),
                      ),
                    ],
                    style: TbText.body(size: 13, weight: FontWeight.w600, color: TbColors.text),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Reason
              Expanded(
                flex: 11,
                child: Text(
                  item.reason,
                  style: TbText.body(size: 12, color: TbColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Action chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: signal.bg,
                  border: Border.all(color: signal.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.category.chipLabel,
                  style: TbText.label(size: 10, weight: FontWeight.w600, color: signal.text, tracking: 0.5),
                ),
              ),
              const SizedBox(width: 12),
              // Updated
              SizedBox(
                width: 36,
                child: Text(
                  item.updatedLabel,
                  textAlign: TextAlign.right,
                  style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
