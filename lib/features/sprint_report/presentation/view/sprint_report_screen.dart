// lib/features/sprint_report/presentation/view/sprint_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../data/models/sprint_report.dart';
import '../providers/sprint_report_provider.dart';
import 'widgets/burndown_chart.dart';

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
              const Spacer(),
              TbBadge('Issues', TbSignal.info, small: true),
              const SizedBox(width: 8),
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

class _Body extends StatelessWidget {
  const _Body({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) {
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

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(report.sprintName, style: TbText.display(size: 15, tracking: 1.5)),
              const SizedBox(height: 2),
              Text(
                '${report.dateRange} · ${report.daysRemaining} days remaining',
                style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
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

  @override
  Widget build(BuildContext context) {
    final estPct = report.totalTickets == 0 ? 100 : (report.estimatedTickets / report.totalTickets * 100).round();
    return _Card(
      title: 'Estimate coverage',
      headerTrailing: const TbBadge('Forecast risk', TbSignal.orange, small: true),
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

// ─── Points per assignee ────────────────────────────────────────────────────

class _PointsPerAssignee extends StatelessWidget {
  const _PointsPerAssignee({required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context) {
    final maxTotal = report.people.fold<int>(1, (m, p) => p.total > m ? p.total : m);
    return _Card(
      title: 'Points per assignee',
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
            for (final p in report.people)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  children: [
                    TbAvatarTile(login: p.handle, size: 18),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 104,
                      child: Text(
                        p.handle,
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
                                flex: p.done,
                                child: Container(color: const Color(0xFF54AE39)),
                              ),
                              Expanded(
                                flex: p.inProgress,
                                child: Container(color: TbColors.cyan),
                              ),
                              Expanded(
                                flex: p.remaining,
                                child: Container(color: TbColors.borderStrong),
                              ),
                              // pad to the common scale so bars are comparable
                              Expanded(flex: (maxTotal - p.total).clamp(0, maxTotal), child: const SizedBox()),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${p.open} OPEN',
                        textAlign: TextAlign.right,
                        style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.muted, tracking: 0.4),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${p.total} PTS',
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

class _BurndownCard extends HookWidget {
  const _BurndownCard({required this.burndown});

  final Burndown burndown;

  @override
  Widget build(BuildContext context) {
    final target = useState(true);

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
                const SizedBox(width: 10),
                const TbBadge('Coming · needs history', TbSignal.gray, small: true),
                const Spacer(),
                _Segment(
                  options: const ['Target visual', 'V1 · no history'],
                  selected: target.value ? 0 : 1,
                  onSelect: (i) => target.value = i == 0,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TbColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                BurndownChart(data: burndown, showActual: target.value),
                if (!target.value)
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
                          'HISTORY ACCRUING',
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
                            '${burndown.snapshotsCaptured} of ${burndown.snapshotsTotal} daily snapshots captured. '
                            'The burndown line unlocks as snapshots accrue — the ideal line and today marker are live now.',
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
              'Remaining story points vs ideal run-rate · daily snapshots start with the reporting job (Sprint 25)',
              style: TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface2,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                color: i == selected ? TbColors.blue : Colors.transparent,
                child: Text(
                  options[i].toUpperCase(),
                  style: TbText.label(
                    size: 9,
                    weight: FontWeight.w500,
                    color: i == selected ? Colors.white : TbColors.muted,
                    tracking: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
