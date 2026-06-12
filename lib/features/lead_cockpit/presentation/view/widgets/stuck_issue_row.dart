import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/cockpit_data.dart';
import '../../helpers/cockpit_palette.dart';

/// One row in the "aging / stuck" list: status dot, title, repo chip, assignee,
/// priority, status, time-in-status, and linked-PR indicator.
class StuckIssueRow extends StatelessWidget {
  const StuckIssueRow({super.key, required this.issue, this.showDivider = true});

  final StuckIssue issue;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final statusLabel = CockpitPalette.statusLabel(issue.status);
    final ageColor = issue.critical ? const Color(0xFFE94A5F) : const Color(0xFFFF5A1F);
    final url = issue.url;

    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: TbColors.border)) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 7, height: 7, child: ColoredBox(color: CockpitPalette.statusDot(issue.status))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              issue.title,
              overflow: TextOverflow.ellipsis,
              style: TbText.body(size: 13, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          _RepoChip(repo: issue.repo),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              issue.assignee,
              overflow: TextOverflow.ellipsis,
              style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.4, weight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          TbBadge(
            CockpitPalette.priorityLabel(issue.priority),
            CockpitPalette.prioritySignal(issue.priority),
            small: true,
            tooltip: CockpitPalette.priorityTooltip(issue.priority),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              statusLabel,
              style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5, weight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(
              '${issue.ageDays}D IN ${statusLabel.toUpperCase()}',
              style: TbText.label(size: 10, weight: FontWeight.w600, color: ageColor, tracking: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 148,
            child: Text(
              issue.prLabel,
              overflow: TextOverflow.ellipsis,
              style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.3, weight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );

    if (url == null) return container;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Tooltip(message: 'Open issue on GitHub', child: container),
      ),
    );
  }
}

class _RepoChip extends StatelessWidget {
  const _RepoChip({required this.repo});

  final String repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: TbColors.surface2,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        repo,
        style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.4, weight: FontWeight.w500),
      ),
    );
  }
}
