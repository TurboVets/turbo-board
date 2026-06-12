import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../data/models/cockpit_data.dart';
import '../providers/lead_cockpit_provider.dart';
import 'widgets/sprint_health_strip.dart';
import 'widgets/stuck_issue_row.dart';
import 'widgets/team_load_card.dart';

/// Lead Cockpit — the headline Issues screen. Reads a GitHub Projects v2 board
/// rollup and surfaces what needs a team lead's attention: sprint health, team
/// load, and aging items. Read-only. Reached via /lead-cockpit inside the shell.
class LeadCockpitScreen extends ConsumerWidget {
  const LeadCockpitScreen({super.key});

  static const String routeName = 'leadCockpit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cockpit = ref.watch(leadCockpitProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Topbar(onRefresh: () => ref.invalidate(leadCockpitProvider)),
        Expanded(
          child: cockpit.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TbBadge('ERROR', TbSignal.bad),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load the sprint cockpit.\n$err',
                    textAlign: TextAlign.center,
                    style: TbText.body(size: 14),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.invalidate(leadCockpitProvider),
                    child: Text('Retry', style: TbText.body(size: 14, color: TbColors.cyan)),
                  ),
                ],
              ),
            ),
            data: (data) => _CockpitBody(data: data),
          ),
        ),
      ],
    );
  }
}

class _CockpitBody extends StatelessWidget {
  const _CockpitBody({required this.data});

  final CockpitData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SprintHealthStrip(sprint: data.sprint, aiBrief: data.aiBrief),
              const SizedBox(height: 18),

              const _SectionLabel('TEAM LOAD'),
              const SizedBox(height: 10),
              _TeamGrid(team: data.team),
              const SizedBox(height: 20),

              const _SectionLabel('AGING / STUCK · SITTING TOO LONG IN A STATUS'),
              const SizedBox(height: 10),
              _StuckList(stuck: data.stuck),
              const SizedBox(height: 8),
              Text(
                'READ-ONLY · SYNCED FROM GITHUB PROJECTS V2 · OPEN ITEMS IN GITHUB TO EDIT',
                style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.8, weight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4, weight: FontWeight.w600),
    );
  }
}

/// Responsive team-load grid: equal-width cards, ~192px min, matching the
/// design's `auto-fit minmax(192px, 1fr)`.
class _TeamGrid extends StatelessWidget {
  const _TeamGrid({required this.team});

  final List<TeamMemberLoad> team;

  static const double _minCardWidth = 192;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = ((width + _gap) / (_minCardWidth + _gap)).floor().clamp(1, team.length);
        final cardWidth = (width - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final member in team)
              SizedBox(
                width: cardWidth,
                child: TeamLoadCard(member: member),
              ),
          ],
        );
      },
    );
  }
}

class _StuckList extends StatelessWidget {
  const _StuckList({required this.stuck});

  final List<StuckIssue> stuck;

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
          for (var i = 0; i < stuck.length; i++) StuckIssueRow(issue: stuck[i], showDivider: i < stuck.length - 1),
        ],
      ),
    );
  }
}

class _Topbar extends StatefulWidget {
  const _Topbar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_Topbar> createState() => _TopbarState();
}

class _TopbarState extends State<_Topbar> {
  bool _hovered = false;

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
          Text('Lead Cockpit · Issues', style: TbText.display(size: 14, tracking: 2.0)),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _hovered ? TbColors.blue : TbColors.borderStrong),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'REFRESH',
                  style: TbText.label(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _hovered ? TbColors.blue : TbColors.text,
                    tracking: 0.96,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
