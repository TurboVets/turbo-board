import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/cockpit_data.dart';
import '../../providers/lead_cockpit_provider.dart';

/// A selectable list of the user's GitHub Projects v2 boards. Used by the
/// cockpit empty-state and the Settings "Lead Cockpit project" section.
class ProjectPickerList extends ConsumerWidget {
  const ProjectPickerList({super.key, required this.onSelected, this.selectedKey});

  final void Function(ProjectRef project) onSelected;
  final String? selectedKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(availableProjectsProvider);

    return projects.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text('$err', style: TbText.body(size: 12, color: const Color(0xFFFBD0D3), height: 1.5)),
            ),
            const SizedBox(width: 12),
            _LinkText('Retry', onTap: () => ref.invalidate(availableProjectsProvider)),
          ],
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No Projects v2 boards found for your account or orgs.',
              style: TbText.body(size: 13, color: TbColors.muted),
            ),
          );
        }
        // Cap the list height so a long board list scrolls in place rather than
        // growing unbounded in the cockpit empty-state and Settings.
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < projects.length; i++)
                _ProjectRow(
                  project: projects[i],
                  selected: projects[i].key == selectedKey,
                  showDivider: i < projects.length - 1,
                  onTap: () => onSelected(projects[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.selected, required this.showDivider, required this.onTap});

  final ProjectRef project;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: TbColors.border)) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.title, style: TbText.label(size: 13, weight: FontWeight.w600, tracking: 0.3)),
                    const SizedBox(height: 2),
                    Text('${project.owner} · #${project.number}', style: TbText.body(size: 11, color: TbColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              if (selected)
                Text('✓ Selected', style: TbText.label(size: 10, color: TbColors.cyan, tracking: 0.4))
              else
                Text('Select', style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: TbText.body(size: 13, color: TbColors.cyan)),
      ),
    );
  }
}
