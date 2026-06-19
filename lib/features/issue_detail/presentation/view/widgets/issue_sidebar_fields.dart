// lib/features/issue_detail/presentation/view/widgets/issue_sidebar_fields.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../data/models/issue_detail.dart';
import '../../providers/issue_composer_provider.dart';

/// Sidebar column: Assignees, Labels, Project fields (Status / Priority /
/// Sprint / Complexity / Milestone), Relationships, Participants. Each
/// non-empty section is a bordered card with a surface2 header. Empty sections
/// return [SizedBox.shrink].
class IssueSidebarFields extends StatelessWidget {
  const IssueSidebarFields({super.key, required this.issue, required this.onTapRef});

  final IssueDetail issue;
  final void Function(IssueRef) onTapRef;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssignees(),
        _buildLabels(),
        _buildProject(),
        _buildRelationships(),
        _buildParticipants(),
      ].where((w) => w is! SizedBox).toList(),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text(title, style: TbText.label(size: 10, tracking: 1.0, color: TbColors.muted)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignees() {
    if (issue.assignees.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      title: 'ASSIGNEES',
      children: [
        for (final login in issue.assignees)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                TbAvatarTile(login: login, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(login, style: TbText.body(size: 12), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLabels() {
    if (issue.labels.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      title: 'LABELS',
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: [for (final label in issue.labels) _LabelChip(label: label)]),
      ],
    );
  }

  Widget _buildProject() {
    final rows = <Widget>[];

    if (issue.canUpdateStatus) {
      rows.add(
        _FieldRow(
          label: 'Status',
          child: _StatusMenu(issue: issue),
        ),
      );
    } else if (issue.status != null) {
      rows.add(
        _FieldRow(
          label: 'Status',
          child: TbBadge(CockpitPalette.statusLabel(issue.status!), TbSignal.gray, small: true),
        ),
      );
    }

    if (issue.priority != null) {
      rows.add(
        _FieldRow(
          label: 'Priority',
          child: TbBadge(
            CockpitPalette.priorityLabel(issue.priority!),
            CockpitPalette.prioritySignal(issue.priority!),
            small: true,
          ),
        ),
      );
    }

    if (issue.sprint != null) {
      rows.add(
        _FieldRow(
          label: 'Sprint',
          child: Text(issue.sprint!, style: TbText.body(size: 12)),
        ),
      );
    }

    if (issue.points != null) {
      rows.add(
        _FieldRow(
          label: 'Complexity',
          child: Text('${issue.points} pts', style: TbText.body(size: 12)),
        ),
      );
    }

    if (issue.milestone != null) {
      rows.add(
        _FieldRow(
          label: 'Milestone',
          child: Text(issue.milestone!, style: TbText.body(size: 12)),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return _sectionCard(title: 'PROJECT', children: rows);
  }

  Widget _buildRelationships() {
    final parent = issue.parent;
    if (parent == null) return const SizedBox.shrink();
    return _sectionCard(
      title: 'RELATIONSHIPS',
      children: [
        InkWell(
          onTap: () => onTapRef(parent),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.link, size: 13, color: TbColors.dim),
                const SizedBox(width: 6),
                Text('#${parent.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(parent.title, style: TbText.body(size: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipants() {
    if (issue.participants.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      title: 'PARTICIPANTS',
      children: [
        Row(
          children: [
            // Overlapping avatar cluster (up to 5 visible)
            SizedBox(
              width: (issue.participants.take(5).length * 14.0) + 6,
              height: 22,
              child: Stack(
                children: [
                  for (var i = 0; i < issue.participants.take(5).length; i++)
                    Positioned(
                      left: i * 14.0,
                      child: TbAvatarTile(login: issue.participants[i], size: 20),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${issue.participants.length} participant${issue.participants.length == 1 ? '' : 's'}',
              style: TbText.body(size: 12, color: TbColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.3)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final IssueLabel label;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    try {
      final hex = label.colorHex.replaceAll('#', '');
      if (hex.length == 6 || hex.length == 8) {
        bg = Color(int.parse('FF$hex'.substring(0, 8), radix: 16));
      }
    } catch (_) {
      bg = null;
    }
    final chipColor = bg ?? TbColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(40),
        border: Border.all(color: chipColor.withAlpha(120)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.name, style: TbText.body(size: 11, color: chipColor)),
    );
  }
}

/// Tappable Status chip → dropdown of the project's Status options. Selecting
/// one writes the new status (then the detail reloads with it).
class _StatusMenu extends ConsumerWidget {
  const _StatusMenu({required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = issue.repo.split('/');
    final owner = parts.first;
    final name = parts.length > 1 ? parts[1] : '';
    final composer = ref.read(issueComposerProvider(owner: owner, name: name, number: issue.number).notifier);
    final label = issue.status != null ? CockpitPalette.statusLabel(issue.status!) : 'Set status';

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(TbColors.surface),
        side: const WidgetStatePropertyAll(BorderSide(color: TbColors.border)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      menuChildren: [
        for (final opt in issue.statusOptions)
          MenuItemButton(
            leadingIcon: opt.status != null
                ? TbSignalDot(color: CockpitPalette.statusDot(opt.status!), size: 8)
                : const SizedBox(width: 8),
            onPressed: () => composer.setStatus(issue.projectId!, issue.projectItemId!, issue.statusFieldId!, opt.id),
            child: Text(opt.name, style: TbText.body(size: 13, color: TbColors.text)),
          ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TbBadge(label, TbSignal.gray, small: true),
            const Icon(Icons.arrow_drop_down, size: 16, color: TbColors.muted),
          ],
        ),
      ),
    );
  }
}
