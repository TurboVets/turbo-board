import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

    final priorityBadge = TbBadge(
      CockpitPalette.priorityLabel(issue.priority),
      CockpitPalette.prioritySignal(issue.priority),
      small: true,
      tooltip: CockpitPalette.priorityTooltip(issue.priority),
    );
    final ageText = Text(
      '${issue.ageDays}D IN ${statusLabel.toUpperCase()}',
      style: TbText.label(size: 10, weight: FontWeight.w600, color: ageColor, tracking: 0.4),
    );

    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: TbColors.border)) : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Phone: the eight columns can't fit on one line — stack the metadata
          // under the title as a wrapping chip row.
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    priorityBadge,
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 19),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _RepoChip(repo: issue.repo),
                      Text(
                        issue.assignee,
                        style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.4, weight: FontWeight.w400),
                      ),
                      ageText,
                      if (issue.prLabel.isNotEmpty)
                        Text(
                          issue.prLabel,
                          style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.3, weight: FontWeight.w400),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
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
              priorityBadge,
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                child: Text(
                  statusLabel,
                  style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5, weight: FontWeight.w400),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 112, child: ageText),
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
          );
        },
      ),
    );

    if (url == null) return container;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final u = Uri.tryParse(url);
          final seg = u?.pathSegments ?? const [];
          // GitHub issue URLs: https://github.com/{owner}/{repo}/issues/{number}
          if (seg.length >= 4 && seg[2] == 'issues') {
            context.push('/issue/${seg[0]}/${seg[1]}/${seg[3]}');
          } else {
            launchUrl(u ?? Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        },
        child: Tooltip(message: 'Open issue', child: container),
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
