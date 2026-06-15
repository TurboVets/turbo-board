import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../ai/presentation/view/widgets/ai_narrative_card.dart';
import '../../data/models/cockpit_data.dart';
import '../../data/repositories/cockpit_mapper.dart';
import '../providers/lead_cockpit_provider.dart';
import 'widgets/project_picker.dart';
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
    final selected = ref.watch(selectedProjectProvider);

    // No board picked yet → let the user choose one right here.
    if (selected == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _Topbar(onRefresh: null),
          Expanded(child: _ChooseProject()),
        ],
      );
    }

    final cockpit = ref.watch(leadCockpitProvider);
    if (cockpit.isLoading && !cockpit.hasValue) {
      // Loading for the first time → show a spinner.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _Topbar(onRefresh: null, isRefreshing: true),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Topbar(
          onRefresh: () => ref.invalidate(leadCockpitProvider),
          isRefreshing: cockpit.isLoading && cockpit.hasValue,
        ),
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

class _CockpitBody extends ConsumerWidget {
  const _CockpitBody({required this.data});

  final CockpitData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyReady = ref.watch(aiKeyReadyProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SprintHealthStrip(data: data),
              const SizedBox(height: 18),

              // AI sprint brief + weekly digest (BYOK — only when a key is set).
              if (keyReady) ...[
                AiNarrativeCard(
                  title: 'AI Sprint Brief',
                  idleLabel: 'Sprint brief',
                  state: ref.watch(cockpitBriefControllerProvider),
                  onGenerate: () => ref.read(cockpitBriefControllerProvider.notifier).generate(data),
                  onHide: () => ref.read(cockpitBriefControllerProvider.notifier).clear(),
                ),
                const SizedBox(height: 12),
                AiNarrativeCard(
                  title: 'AI Weekly Digest',
                  idleLabel: 'Weekly digest',
                  state: ref.watch(weeklyDigestControllerProvider),
                  onGenerate: () => ref.read(weeklyDigestControllerProvider.notifier).generate(data),
                  onHide: () => ref.read(weeklyDigestControllerProvider.notifier).clear(),
                ),
                const SizedBox(height: 18),
              ],

              _TeamSection(team: data.team),
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

/// Team load section: a header with the gauge-scale toggle, then a responsive
/// grid of member cards (~208px min, matching the design's `auto-fit minmax`).
/// The scale toggle is local UI state, so it lives in a hook.
class _TeamSection extends HookWidget {
  const _TeamSection({required this.team});

  final List<TeamMemberLoad> team;

  static const double _minCardWidth = 208;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final gaugeMode = useState(GaugeMode.capacity);
    final maxPoints = team.fold<int>(0, (m, t) => t.points > m ? t.points : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SectionLabel('TEAM LOAD'),
            const Spacer(),
            Text(
              'SCALE',
              style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.8, weight: FontWeight.w400),
            ),
            const SizedBox(width: 8),
            _GaugeScaleToggle(mode: gaugeMode.value, onChanged: (m) => gaugeMode.value = m),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
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
                    child: TeamLoadCard(member: member, gaugeMode: gaugeMode.value, maxPoints: maxPoints),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Two-segment control switching the load gauge between a fixed point capacity
/// and a relative-to-busiest scale.
class _GaugeScaleToggle extends StatelessWidget {
  const _GaugeScaleToggle({required this.mode, required this.onChanged});

  final GaugeMode mode;
  final ValueChanged<GaugeMode> onChanged;

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
        children: [_segment('40PT CAP', GaugeMode.capacity), _segment('RELATIVE', GaugeMode.relative)],
      ),
    );
  }

  Widget _segment(String label, GaugeMode value) {
    final selected = mode == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: selected ? TbColors.blue : Colors.transparent,
          child: Text(
            label,
            style: TbText.label(
              size: 9,
              color: selected ? Colors.white : TbColors.muted,
              tracking: 0.6,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
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
      child: stuck.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  const SizedBox(width: 7, height: 7, child: ColoredBox(color: Color(0xFF54AE39))),
                  const SizedBox(width: 10),
                  Text(
                    'Nothing aging — every open item has moved within the last $stuckAfterDays days.',
                    style: TbText.body(size: 12, color: TbColors.muted),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stuck.length; i++)
                  StuckIssueRow(issue: stuck[i], showDivider: i < stuck.length - 1),
              ],
            ),
    );
  }
}

class _Topbar extends StatefulWidget {
  const _Topbar({required this.onRefresh, this.isRefreshing = false});

  final VoidCallback? onRefresh;
  final bool isRefreshing;

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
          if (widget.onRefresh != null)
            MouseRegion(
              cursor: widget.isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                onTap: widget.isRefreshing ? null : widget.onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: _hovered && !widget.isRefreshing ? TbColors.blue : TbColors.borderStrong),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isRefreshing) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: TbColors.dim),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.isRefreshing ? 'REFRESHING' : 'REFRESH',
                        style: TbText.label(
                          size: 12,
                          weight: FontWeight.w600,
                          color: widget.isRefreshing ? TbColors.dim : (_hovered ? TbColors.blue : TbColors.text),
                          tracking: 0.96,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state shown until a board is selected: pick one to populate the cockpit.
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CHOOSE A PROJECT', style: TbText.label(size: 12, tracking: 1.4)),
              const SizedBox(height: 6),
              Text(
                'Pick the GitHub Projects v2 board this cockpit should track. '
                'You can change it any time in Settings.',
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
