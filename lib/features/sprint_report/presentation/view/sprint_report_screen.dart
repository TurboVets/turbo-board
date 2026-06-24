// lib/features/sprint_report/presentation/view/sprint_report_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../ai/presentation/view/widgets/ai_narrative_card.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
import '../../data/models/sprint_report.dart';
import '../providers/sprint_report_provider.dart';
import 'widgets/burndown_chart.dart';
import 'widgets/report_export_dialog.dart';

Color _statusColor(ReportStatusKind k) => switch (k) {
  ReportStatusKind.done => TbSignal.ok.border,
  ReportStatusKind.inProgress => TbColors.cyan,
  ReportStatusKind.inReview => TbSignal.warn.border,
  ReportStatusKind.notStarted => const Color(0xFFBABBBF),
};

/// Sprint Report — analytical rollup of the current sprint (points, coverage,
/// per-assignee load, epic progress, burndown). Read-only. Reached via
/// /sprint-report inside the shell. Matches TurboBoard.dc.html.
class SprintReportScreen extends ConsumerWidget {
  const SprintReportScreen({super.key});

  static const String routeName = 'sprintReport';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);

    // No board picked yet → same picker the Lead Cockpit uses.
    if (selected == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _ReportHeader(),
          Expanded(child: _ChooseProject()),
        ],
      );
    }

    final report = ref.watch(sprintReportProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0x99141418),
            border: Border(bottom: BorderSide(color: TbColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Text('Sprint Report', style: TbText.display(size: 14, tracking: 2.0)),
              // Reload indicator — shown while switching sprints / refreshing
              // (the body keeps the previous sprint via skipLoadingOnReload).
              if (report.isLoading && report.hasValue) ...[
                const SizedBox(width: 12),
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
              const Spacer(),
              TbBadge('Issues', TbSignal.info, small: true),
              const SizedBox(width: 8),
              if (report.hasValue) ...[
                Builder(
                  builder: (context) {
                    final keyReady = ref.watch(aiKeyReadyProvider);
                    return GestureDetector(
                      onTap: keyReady
                          ? () => showDialog<void>(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: TbColors.surface,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 560),
                                  child: ReportExportDialog(report: report.value!),
                                ),
                              ),
                            )
                          : null,
                      child: Text(
                        'EXPORT',
                        style: TbText.label(size: 11, color: keyReady ? TbColors.cyan : TbColors.muted, tracking: 0.8),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
              ],
              GestureDetector(
                onTap: () => ref.invalidate(sprintReportProvider),
                child: Text('REFRESH', style: TbText.label(size: 11, color: TbColors.muted, tracking: 0.8)),
              ),
            ],
          ),
        ),
        Expanded(
          child: report.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TbBadge('ERROR', TbSignal.bad),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load the sprint report.\n$err',
                    textAlign: TextAlign.center,
                    style: TbText.body(size: 14),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.invalidate(sprintReportProvider),
                    child: Text('Retry', style: TbText.body(size: 14, color: TbColors.cyan)),
                  ),
                ],
              ),
            ),
            data: (r) => _Body(report: r),
          ),
        ),
      ],
    );
  }
}

/// Plain header bar (no refresh/badge) for the no-selection state.
class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0x99141418),
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.centerLeft,
      child: Text('Sprint Report', style: TbText.display(size: 14, tracking: 2.0)),
    );
  }
}

/// Empty state shown until a board is selected: pick one to populate the report.
class _ChooseProject extends ConsumerWidget {
  const _ChooseProject();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CHOOSE A PROJECT', style: TbText.label(size: 12, tracking: 1.4)),
              const SizedBox(height: 6),
              Text(
                'Pick the GitHub Projects v2 board to report on. Shared with the Lead Cockpit; '
                'change it any time in Settings.',
                style: TbText.body(size: 13, color: TbColors.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: TbColors.surface,
                  border: Border.all(color: TbColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProjectPickerList(onSelected: (p) => ref.read(selectedProjectProvider.notifier).select(p)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyReady = ref.watch(aiKeyReadyProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderStrip(report: report),
              const SizedBox(height: 14),
              // AI sprint summary + digest (BYOK — only when a key is set).
              if (keyReady) ...[
                AiNarrativeCard(
                  title: 'AI Sprint Summary',
                  idleLabel: 'Summarize sprint',
                  state: ref.watch(sprintSummaryControllerProvider),
                  onGenerate: () => ref.read(sprintSummaryControllerProvider.notifier).generate(report),
                  onHide: () => ref.read(sprintSummaryControllerProvider.notifier).clear(),
                ),
                const SizedBox(height: 12),
                AiNarrativeCard(
                  title: 'AI Sprint Digest',
                  idleLabel: 'Sprint digest',
                  state: ref.watch(sprintDigestControllerProvider),
                  onGenerate: () => ref.read(sprintDigestControllerProvider.notifier).generate(report),
                  onHide: () => ref.read(sprintDigestControllerProvider.notifier).clear(),
                ),
                const SizedBox(height: 14),
              ],
              LayoutBuilder(
                builder: (context, c) {
                  final twoCol = c.maxWidth >= 680;
                  final status = _PointsByStatus(report: report);
                  final coverage = _EstimateCoverage(report: report);
                  return twoCol
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: status),
                            const SizedBox(width: 14),
                            Expanded(child: coverage),
                          ],
                        )
                      : Column(children: [status, const SizedBox(height: 14), coverage]);
                },
              ),
              const SizedBox(height: 14),
              _TicketsPerAssignee(report: report),
              const SizedBox(height: 14),
              _PointsPerAssignee(report: report),
              const SizedBox(height: 14),
              _EpicProgressCard(report: report),
              const SizedBox(height: 14),
              _BurndownCard(burndown: report.burndown),
              const SizedBox(height: 10),
              Text(
                'Read-only · computed from a single GitHub Projects v2 snapshot · '
                'excludes ${report.unestimatedTickets} unestimated tickets',
                style: TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card shell ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.headerTrailing, this.bodyPadding = 14});

  final String title;
  final Widget child;
  final Widget? headerTrailing;
  final double bodyPadding;

  @override
  Widget build(BuildContext context) {
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
            color: TbColors.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 1.0)),
                ),
                ?headerTrailing,
              ],
            ),
          ),
          const Divider(height: 1, color: TbColors.border),
          Padding(padding: EdgeInsets.all(bodyPadding), child: child),
        ],
      ),
    );
  }
}

// ─── Header strip ───────────────────────────────────────────────────────────

class _HeaderStrip extends ConsumerWidget {
  const _HeaderStrip({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedSprintProvider.notifier);
    // Disable nav while a sprint is loading to prevent racing rapid switches.
    final loading = ref.watch(sprintReportProvider).isLoading;
    final subtitle = [
      if (report.dateRange.isNotEmpty) report.dateRange,
      if (report.daysRemaining > 0) '${report.daysRemaining} days remaining',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 26,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SprintChevron(
                enabled: report.hasPrev && !loading,
                left: true,
                onTap: () => notifier.select(report.prevTitle),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(report.sprintName, style: TbText.display(size: 15, tracking: 1.5)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              _SprintChevron(
                enabled: report.hasNext && !loading,
                left: false,
                onTap: () => notifier.select(report.nextTitle),
              ),
            ],
          ),
          _Stat(value: '${report.totalTickets}', label: 'Tickets'),
          _Stat(value: '${report.pointsCommitted}', label: 'Pts committed'),
          _Stat(value: '${report.repoCount}', label: 'Repos'),
          Tooltip(
            message: report.forecastDetail,
            child: TbBadge(report.forecastLabel, report.behind ? TbSignal.orange : TbSignal.ok, small: true),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TbText.display(size: 20, tracking: 0.5)),
        Text(
          label.toUpperCase(),
          style: TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 1.0),
        ),
      ],
    );
  }
}

class _SprintChevron extends StatelessWidget {
  const _SprintChevron({required this.enabled, required this.left, required this.onTap});

  final bool enabled;
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? TbColors.borderStrong : TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        left ? Icons.chevron_left : Icons.chevron_right,
        size: 18,
        color: enabled ? TbColors.text : TbColors.dim,
      ),
    );
    if (!enabled) return Opacity(opacity: 0.4, child: child);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

// ─── Points by status ───────────────────────────────────────────────────────

class _PointsByStatus extends StatelessWidget {
  const _PointsByStatus({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) {
    final committed = report.pointsCommitted;
    return _Card(
      title: 'Points by status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${report.pointsDone}', style: TbText.display(size: 26, tracking: 0.5)),
              const SizedBox(width: 8),
              Text(
                'of $committed pts done',
                style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.8),
              ),
              const Spacer(),
              TbBadge('${report.percentDone}%', TbSignal.ok, small: true),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                for (final s in report.status)
                  Expanded(
                    flex: s.points,
                    child: Container(height: 12, color: _statusColor(s.kind)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final s in report.status)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(width: 7, height: 7, color: _statusColor(s.kind)),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 96,
                    child: Text(
                      s.label.toUpperCase(),
                      style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.muted, tracking: 0.6),
                    ),
                  ),
                  Text(
                    '${s.tickets} tickets',
                    style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
                  ),
                  const Spacer(),
                  Text('${s.points} pts', style: TbText.label(size: 10, weight: FontWeight.w600, tracking: 0.6)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Estimate coverage ──────────────────────────────────────────────────────

class _EstimateCoverage extends StatelessWidget {
  const _EstimateCoverage({required this.report});

  final SprintReport report;

  /// Forecast risk derived from the share of unestimated tickets, since every
  /// forecast on the screen excludes them. More unestimated work = less
  /// trustworthy burndown/behind-ahead call.
  ({String label, TbSignal signal}) get _risk {
    final pct = report.unestimatedPercent;
    if (pct == 0) return (label: 'Forecast solid', signal: TbSignal.ok);
    if (pct <= 15) return (label: 'Low risk', signal: TbSignal.warn);
    if (pct <= 35) return (label: 'Moderate risk', signal: TbSignal.orange);
    return (label: 'High risk', signal: TbSignal.bad);
  }

  @override
  Widget build(BuildContext context) {
    final estPct = report.totalTickets == 0 ? 100 : (report.estimatedTickets / report.totalTickets * 100).round();
    final risk = _risk;
    return _Card(
      title: 'Estimate coverage',
      headerTrailing: TbBadge(risk.label, risk.signal, small: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${report.unestimatedTickets}',
                style: TbText.display(size: 26, tracking: 0.5, color: TbSignal.orange.text),
              ),
              const SizedBox(width: 8),
              Text(
                'unestimated tickets (${report.unestimatedPercent}%)',
                style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: estPct,
                  child: Container(height: 12, color: TbColors.borderStrong),
                ),
                Expanded(
                  flex: 100 - estPct,
                  child: Container(height: 12, color: TbSignal.orange.border),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CoverageRow(
            color: TbColors.borderStrong,
            label: 'Estimated',
            tickets: '${report.estimatedTickets} tickets',
            pts: '${report.estimatedPoints} pts',
          ),
          const SizedBox(height: 7),
          _CoverageRow(
            color: TbSignal.orange.border,
            label: 'Unestimated',
            tickets: '${report.unestimatedTickets} tickets',
            pts: '? pts',
            ptsColor: TbSignal.orange.text,
          ),
          const SizedBox(height: 12),
          Text(
            'Every forecast on this screen excludes these ${report.unestimatedTickets} tickets. '
            'Estimate them to make the burndown and the behind/ahead call trustworthy.',
            style: TbText.body(size: 12, color: TbColors.muted, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.color,
    required this.label,
    required this.tickets,
    required this.pts,
    this.ptsColor,
  });

  final Color color;
  final String label;
  final String tickets;
  final String pts;
  final Color? ptsColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 9),
        SizedBox(
          width: 96,
          child: Text(
            label.toUpperCase(),
            style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.muted, tracking: 0.6),
          ),
        ),
        Text(
          tickets,
          style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
        ),
        const Spacer(),
        Text(
          pts,
          style: TbText.label(size: 10, weight: FontWeight.w600, color: ptsColor ?? TbColors.text, tracking: 0.6),
        ),
      ],
    );
  }
}

// ─── Tickets / Points per assignee ──────────────────────────────────────────

class _TicketsPerAssignee extends StatelessWidget {
  const _TicketsPerAssignee({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) => _AssigneeBars(
    title: 'Tickets per assignee',
    unit: 'TIX',
    totalWidth: 46,
    rows: [
      for (final t in report.peopleTickets)
        _AssigneeRow(handle: t.handle, done: t.done, inProgress: t.inProgress, remaining: t.remaining),
    ],
  );
}

class _PointsPerAssignee extends StatelessWidget {
  const _PointsPerAssignee({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) => _AssigneeBars(
    title: 'Points per assignee',
    unit: 'PTS',
    totalWidth: 52,
    rows: [
      for (final p in report.people)
        _AssigneeRow(handle: p.handle, done: p.done, inProgress: p.inProgress, remaining: p.remaining),
    ],
  );
}

class _AssigneeRow {
  const _AssigneeRow({required this.handle, required this.done, required this.inProgress, required this.remaining});

  final String handle;
  final int done;
  final int inProgress;
  final int remaining;

  int get total => done + inProgress + remaining;
  int get open => inProgress + remaining;
}

/// Shared horizontal stacked-bar chart (done / in-progress / remaining) used by
/// both the tickets-per-assignee and points-per-assignee sections. Bars scale
/// to the busiest assignee so the two charts read consistently.
class _AssigneeBars extends StatelessWidget {
  const _AssigneeBars({required this.title, required this.unit, required this.totalWidth, required this.rows});

  final String title;
  final String unit;
  final double totalWidth;
  final List<_AssigneeRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxTotal = rows.fold<int>(1, (m, r) => r.total > m ? r.total : m);
    return _Card(
      title: title,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendDot(color: Color(0xFF54AE39), label: 'DONE'),
          SizedBox(width: 12),
          _LegendDot(color: TbColors.cyan, label: 'IN PROGRESS'),
          SizedBox(width: 12),
          _LegendDot(color: TbColors.borderStrong, label: 'REMAINING'),
        ],
      ),
      bodyPadding: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  children: [
                    TbAvatarTile(login: r.handle, size: 18),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 104,
                      child: Text(
                        r.handle,
                        style: TbText.label(size: 11, weight: FontWeight.w500, tracking: 0.4),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 10,
                          color: TbColors.surface2,
                          child: Row(
                            children: [
                              Expanded(
                                flex: r.done,
                                child: Container(color: const Color(0xFF54AE39)),
                              ),
                              Expanded(
                                flex: r.inProgress,
                                child: Container(color: TbColors.cyan),
                              ),
                              Expanded(
                                flex: r.remaining,
                                child: Container(color: TbColors.borderStrong),
                              ),
                              // pad to the common scale so bars are comparable
                              Expanded(flex: (maxTotal - r.total).clamp(0, maxTotal), child: const SizedBox()),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${r.open} OPEN',
                        textAlign: TextAlign.right,
                        style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.muted, tracking: 0.4),
                      ),
                    ),
                    SizedBox(
                      width: totalWidth,
                      child: Text(
                        '${r.total} $unit',
                        textAlign: TextAlign.right,
                        style: TbText.label(size: 10, weight: FontWeight.w600, tracking: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
        ),
      ],
    );
  }
}

// ─── Epic progress ──────────────────────────────────────────────────────────

class _EpicProgressCard extends StatelessWidget {
  const _EpicProgressCard({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Epic progress',
      bodyPadding: 0,
      child: Column(
        children: [
          for (final e in report.epics)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TbColors.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: TbText.body(size: 13, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${e.subsDone}/${e.subsTotal} SUB-ISSUES',
                      style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.5),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        color: TbColors.surface2,
                        child: Row(
                          children: [
                            Expanded(
                              flex: e.percent,
                              child: Container(color: TbColors.blue),
                            ),
                            Expanded(flex: 100 - e.percent, child: const SizedBox()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${e.pointsDone}/${e.pointsTotal} PTS',
                      textAlign: TextAlign.right,
                      style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.muted, tracking: 0.4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${e.percent}%',
                      textAlign: TextAlign.right,
                      style: TbText.label(size: 12, weight: FontWeight.w700, color: TbColors.cyan, tracking: 0.2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Burndown ───────────────────────────────────────────────────────────────

class _BurndownCard extends StatelessWidget {
  const _BurndownCard({required this.burndown});

  final Burndown burndown;

  @override
  Widget build(BuildContext context) {
    // The actual line is reconstructed from issue close dates; it needs at least
    // two points to draw (a sprint with no closed issues yet has none).
    final showActual = burndown.actualRemaining.length >= 2;

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
            color: TbColors.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text('Sprint burndown', style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 1.0)),
                if (!showActual) ...[
                  const SizedBox(width: 10),
                  const TbBadge('No closed issues yet', TbSignal.gray, small: true),
                ],
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: TbColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                BurndownChart(data: burndown, showActual: showActual),
                if (!showActual)
                  Container(
                    margin: const EdgeInsets.only(bottom: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: TbColors.surface2,
                      border: Border.all(color: TbColors.borderStrong),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NO COMPLETED ISSUES YET',
                          style: TbText.label(
                            size: 11,
                            weight: FontWeight.w600,
                            color: const Color(0xFFDADADD),
                            tracking: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 300,
                          child: Text(
                            'No issues in this sprint have been closed yet, so there is nothing to burn down. '
                            'The actual line draws from issue close dates as work completes.',
                            textAlign: TextAlign.center,
                            style: TbText.body(size: 12, color: TbColors.muted, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              'Remaining story points vs ideal run-rate · actual line reconstructed from issue close dates',
              style: TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
