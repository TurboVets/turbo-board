// lib/features/needs_attention/presentation/view/needs_attention_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../helpers/triage.dart';
import '../providers/needs_attention_provider.dart';

/// Triage view: open PRs grouped into actionable categories, shown as a grid of
/// tiles. Each tile previews its top PRs; tapping a tile expands it in place to
/// a scrollable full list. A PR can appear in several tiles. Reached via
/// /needs-attention inside the shell.
class NeedsAttentionScreen extends HookConsumerWidget {
  const NeedsAttentionScreen({super.key});

  static const String routeName = 'needsAttention';

  // Fixed tile order, left to right / top to bottom.
  static const _order = <NeedsAttentionCategory>[
    NeedsAttentionCategory.needsMyReview,
    NeedsAttentionCategory.changesRequested,
    NeedsAttentionCategory.failingChecks,
    NeedsAttentionCategory.draft,
    NeedsAttentionCategory.stale,
  ];

  static const double _minTileWidth = 268;
  static const double _gap = 14;

  static TbSignal _signalFor(NeedsAttentionCategory c) => switch (c) {
    NeedsAttentionCategory.needsMyReview => TbSignal.info,
    NeedsAttentionCategory.changesRequested => TbSignal.bad,
    NeedsAttentionCategory.failingChecks => TbSignal.bad,
    NeedsAttentionCategory.draft => TbSignal.gray,
    NeedsAttentionCategory.stale => TbSignal.orange,
  };

  static String _subFor(NeedsAttentionCategory c, int staleDays) => switch (c) {
    NeedsAttentionCategory.needsMyReview => 'WAITING ON YOUR REVIEW',
    NeedsAttentionCategory.changesRequested => 'AUTHOR MUST ADDRESS',
    NeedsAttentionCategory.failingChecks => 'CI IS RED',
    NeedsAttentionCategory.draft => 'NOT READY YET',
    NeedsAttentionCategory.stale => 'NO UPDATE IN ${staleDays}D+',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(needsAttentionProvider);
    final threshold = ref.watch(staleThresholdProvider);
    // Single tile expanded at a time (null = all collapsed).
    final expanded = useState<NeedsAttentionCategory?>(null);

    return ColoredBox(
      color: context.colorScheme.surface,
      child: Column(
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
                final total = groups.values.expand((l) => l).map((p) => p.slug).toSet().length;
                if (total == 0) {
                  return Center(
                    child: Text(
                      'Nothing needs attention. Inbox zero.',
                      style: TbText.body(size: 14, color: TbColors.muted),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ContentToolbar(total: total, threshold: threshold),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cols = ((w + _gap) / (_minTileWidth + _gap)).floor().clamp(1, _order.length);
                          final tileW = (w - _gap * (cols - 1)) / cols;
                          return Wrap(
                            spacing: _gap,
                            runSpacing: _gap,
                            children: [
                              for (final c in _order)
                                SizedBox(
                                  width: tileW,
                                  child: _AttentionTile(
                                    category: c,
                                    prs: groups[c] ?? const [],
                                    signal: _signalFor(c),
                                    sub: _subFor(c, threshold),
                                    expanded: expanded.value == c,
                                    onToggle: () => expanded.value = expanded.value == c ? null : c,
                                    onOpenPr: (pr) => _openDetail(context, pr),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
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

// ─── Top bar (shell-style) ──────────────────────────────────────────────────

class _Topbar extends StatelessWidget {
  const _Topbar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
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
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: TbColors.text,
              side: const BorderSide(color: TbColors.borderStrong),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: TbText.label(size: 12, tracking: 0.8),
            ),
            child: const Text('REFRESH'),
          ),
        ],
      ),
    );
  }
}

// ─── Content toolbar (big total + stale control) ────────────────────────────

class _ContentToolbar extends ConsumerWidget {
  const _ContentToolbar({required this.total, required this.threshold});

  final int total;
  final int threshold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$total', style: TbText.display(size: 26, tracking: 0)),
            const SizedBox(height: 3),
            Text('PRS NEED ATTENTION', style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.0)),
          ],
        ),
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

// ─── Attention tile ─────────────────────────────────────────────────────────

class _AttentionTile extends StatefulWidget {
  const _AttentionTile({
    required this.category,
    required this.prs,
    required this.signal,
    required this.sub,
    required this.expanded,
    required this.onToggle,
    required this.onOpenPr,
  });

  final NeedsAttentionCategory category;
  final List<PrData> prs;
  final TbSignal signal;
  final String sub;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PrData> onOpenPr;

  @override
  State<_AttentionTile> createState() => _AttentionTileState();
}

class _AttentionTileState extends State<_AttentionTile> {
  bool _hovered = false;

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    // Most-stale first so the preview surfaces the rows that have waited longest.
    final prs = [...widget.prs]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final empty = prs.isEmpty;
    final count = prs.length;
    final accent = empty ? TbColors.borderStrong : widget.signal.border;
    final borderColor = empty ? TbColors.border : ((widget.expanded || _hovered) ? accent : TbColors.border);
    final maxExpandedHeight = MediaQuery.of(context).size.height * 0.52;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: empty ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: empty ? null : widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 220),
          decoration: BoxDecoration(
            color: TbColors.surface,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top accent strip (uniform border + radius can't carry a 2px side).
              Container(height: 2, color: accent),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.category.label.toUpperCase(),
                            style: TbText.label(
                              size: 11,
                              weight: FontWeight.w700,
                              color: TbColors.text,
                              tracking: 1.32,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(widget.sub, style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.72)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: TbText.display(size: 28, color: empty ? TbColors.dim : accent, tracking: 0)),
                  ],
                ),
              ),
              // Body
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: TbColors.border)),
                ),
                child: empty
                    ? const _AllClear()
                    : widget.expanded
                    ? ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxExpandedHeight),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: prs.length,
                          itemBuilder: (_, i) => _FullRow(pr: prs[i], onTap: () => widget.onOpenPr(prs[i])),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [for (final pr in prs.take(_previewCount)) _PreviewRow(pr: pr)],
                      ),
              ),
              // Footer CTA (only when there's something to drill into)
              if (!empty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: TbColors.border)),
                  ),
                  child: Text(
                    widget.expanded ? 'COLLAPSE ▴' : 'VIEW ALL $count ${count == 1 ? 'PR' : 'PRS'} →',
                    style: TbText.label(size: 10, weight: FontWeight.w600, color: accent, tracking: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Text('ALL CLEAR ✓', style: TbText.label(size: 11, color: TbColors.dim, tracking: 0.88)),
    );
  }
}

// ─── Rows ────────────────────────────────────────────────────────────────────

/// Compact preview row (collapsed tile): repo dot, title, CI chip, age.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.pr});

  final PrData pr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        children: [
          _RepoSquare(slug: pr.repo),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              pr.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TbText.body(size: 12, weight: FontWeight.w600, color: TbColors.text),
            ),
          ),
          const SizedBox(width: 8),
          TbBadge(_ciLabel(pr.ciState), _ciSignal(pr.ciState), small: true),
          const SizedBox(width: 8),
          Text(_ago(pr.updatedAt), style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.3)),
        ],
      ),
    );
  }
}

/// Full row (expanded tile): repo dot, title + repo#num, CI chip, avatar, age.
class _FullRow extends StatefulWidget {
  const _FullRow({required this.pr, required this.onTap});

  final PrData pr;
  final VoidCallback onTap;

  @override
  State<_FullRow> createState() => _FullRowState();
}

class _FullRowState extends State<_FullRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final pr = widget.pr;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? TbColors.surface2 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _RepoSquare(slug: pr.repo),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (pr.isDraft)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: TbColors.surface2,
                                  border: Border.all(color: const Color(0x73BABBBF)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'DRAFT',
                                  style: TbText.label(size: 9, weight: FontWeight.w500, color: TbColors.muted),
                                ),
                              ),
                            ),
                          TextSpan(text: pr.title),
                        ],
                        style: TbText.body(size: 12, weight: FontWeight.w600, color: TbColors.text),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pr.repo} #${pr.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TbText.label(size: 9, color: TbColors.muted, tracking: 0.36),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TbBadge(_ciLabel(pr.ciState), _ciSignal(pr.ciState), small: true),
              const SizedBox(width: 8),
              TbAvatarTile(login: pr.author, size: 16),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  _ago(pr.updatedAt),
                  textAlign: TextAlign.right,
                  style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6px square repo swatch (matches the mockup's square dots, not a circle).
class _RepoSquare extends StatelessWidget {
  const _RepoSquare({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Container(width: 6, height: 6, color: TbRepoColor.forSlug(slug));
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _ciLabel(PrCiState s) => switch (s) {
  PrCiState.passing => '✓ CI',
  PrCiState.pending => '● CI',
  PrCiState.failing => '✕ CI',
};

TbSignal _ciSignal(PrCiState s) => switch (s) {
  PrCiState.passing => TbSignal.ok,
  PrCiState.pending => TbSignal.warn,
  PrCiState.failing => TbSignal.bad,
};

/// Compact relative age, e.g. "5m", "3h", "2d", "4w". Clock passed implicitly
/// via DateTime.now() — fine for a display-only string.
String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}
