import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../../ai/presentation/view/widgets/ai_narrative_card.dart';
import '../../../data/models/cockpit_data.dart';
import '../../providers/lead_cockpit_provider.dart';

/// The on-demand AI reports offered from the cockpit top bar. Each maps to its
/// own controller (all `AsyncValue<String>?` notifiers with `generate`/`clear`).
enum CockpitReport {
  dailyStandup('AI Daily Standup', 'Daily Standup', 'Generated from sprint board snapshot · claude-haiku · BYOK'),
  sprintBrief('AI Sprint Brief', 'Sprint Brief', 'Generated from sprint board + PR state · claude-haiku · BYOK'),
  weeklyDigest('AI Weekly Digest', 'Weekly Digest', 'Generated from sprint board + PR state · claude-haiku · BYOK');

  const CockpitReport(this.title, this.menuLabel, this.caption);

  final String title;
  final String menuLabel;
  final String caption;
}

/// Reads the report's controller state. Kept here so the button and the dialog
/// stay in sync on a single source of truth.
AsyncValue<String>? _watchReport(WidgetRef ref, CockpitReport report) => switch (report) {
  CockpitReport.dailyStandup => ref.watch(dailyStandupControllerProvider),
  CockpitReport.sprintBrief => ref.watch(cockpitBriefControllerProvider),
  CockpitReport.weeklyDigest => ref.watch(weeklyDigestControllerProvider),
};

void _generateReport(WidgetRef ref, CockpitReport report, CockpitData data) {
  switch (report) {
    case CockpitReport.dailyStandup:
      ref.read(dailyStandupControllerProvider.notifier).generate(data);
    case CockpitReport.sprintBrief:
      ref.read(cockpitBriefControllerProvider.notifier).generate(data);
    case CockpitReport.weeklyDigest:
      ref.read(weeklyDigestControllerProvider.notifier).generate(data);
  }
}

/// Top-bar AI button for the Lead Cockpit: a single cyan CTA that opens a menu
/// of the available reports. Picking one generates it (on-demand, never on load)
/// and shows the result in a dialog. Renders nothing until a BYOK key is set.
class CockpitAiMenu extends ConsumerWidget {
  const CockpitAiMenu({super.key, required this.data});

  final CockpitData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<CockpitReport>(
      tooltip: 'AI reports',
      color: TbColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: TbColors.border),
      ),
      onSelected: (report) {
        // Selecting the report IS the CTA. The dialog itself fires the
        // generation once it is mounted and watching, so the (autodispose)
        // controller keeps a listener and its result reaches the dialog.
        showDialog<void>(
          context: context,
          builder: (_) => _CockpitAiReportDialog(report: report, data: data),
        );
      },
      itemBuilder: (context) => [
        for (final report in CockpitReport.values)
          PopupMenuItem<CockpitReport>(
            value: report,
            child: Text(report.menuLabel, style: TbText.body(size: 13, color: TbColors.text)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: TbColors.cyan),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 11, color: TbColors.cyan),
            const SizedBox(width: 7),
            Text(
              'AI',
              style: TbText.label(size: 12, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.96),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: TbColors.cyan),
          ],
        ),
      ),
    );
  }
}

/// Modal that renders the selected report via [AiNarrativeCard]. Watches the
/// report's controller so loading → data/error transitions stream in live, and
/// fires the generation once after mount (so the autodispose controller keeps a
/// listener). "Hide" closes the dialog, "Retry" regenerates.
class _CockpitAiReportDialog extends ConsumerStatefulWidget {
  const _CockpitAiReportDialog({required this.report, required this.data});

  final CockpitReport report;
  final CockpitData data;

  @override
  ConsumerState<_CockpitAiReportDialog> createState() => _CockpitAiReportDialogState();
}

class _CockpitAiReportDialogState extends ConsumerState<_CockpitAiReportDialog> {
  bool _autoTriggered = false;

  String get _projectKey => ref.read(selectedProjectProvider)?.key ?? '';

  void _generate() => _generateReport(ref, widget.report, widget.data);

  void _persist(AsyncValue<String>? next) {
    if (next is AsyncData<String>) {
      ref.read(cockpitReportsProvider.notifier).write(_projectKey, widget.report.name, next.value);
    }
  }

  /// Persist any freshly generated report so reopening shows it next time. The
  /// listener types are inferred per provider, so the lambdas stay un-annotated.
  void _persistOnSuccess() {
    switch (widget.report) {
      case CockpitReport.dailyStandup:
        ref.listen(dailyStandupControllerProvider, (_, next) => _persist(next));
      case CockpitReport.sprintBrief:
        ref.listen(cockpitBriefControllerProvider, (_, next) => _persist(next));
      case CockpitReport.weeklyDigest:
        ref.listen(weeklyDigestControllerProvider, (_, next) => _persist(next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final reportsAsync = ref.watch(cockpitReportsProvider);
    final gen = _watchReport(ref, report);
    final cached = ref.read(cockpitReportsProvider.notifier).cached(_projectKey, report.name);

    _persistOnSuccess();

    // First open with nothing cached → generate once (the menu pick is the CTA).
    // Wait until the store has resolved so a stored report is never clobbered.
    if (!_autoTriggered && reportsAsync is! AsyncLoading && gen == null && cached == null) {
      _autoTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }

    // Live generation state wins; otherwise fall back to the cached report.
    final effective = gen ?? (cached != null ? AsyncData<String>(cached) : null);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          child: AiNarrativeCard(
            title: report.title,
            idleLabel: report.menuLabel,
            caption: report.caption,
            state: effective,
            onGenerate: _generate,
            onRegenerate: _generate,
            onHide: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
