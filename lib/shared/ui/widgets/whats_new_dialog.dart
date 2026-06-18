// lib/shared/ui/widgets/whats_new_dialog.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/changelog_provider.dart';
import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';

/// Opens the "What's new" dialog. Content is read from the bundled
/// `CHANGELOG.md` (see [changelogProvider]); the section matching [version] is
/// shown, falling back to the latest release entry.
Future<void> showWhatsNewDialog(BuildContext context, String version) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _WhatsNewDialog(version: version),
  );
}

class _WhatsNewDialog extends ConsumerWidget {
  const _WhatsNewDialog({required this.version});

  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changelog = ref.watch(changelogProvider);

    return Dialog(
      backgroundColor: TbColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: changelog.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => _body(context, null),
            data: (entries) {
              final entry = entries.where((e) => e.version == version).firstOrNull ?? entries.firstOrNull;
              return _body(context, entry);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ChangelogEntry? entry) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: TbColors.cyan),
            const SizedBox(width: 8),
            Text("WHAT'S NEW", style: TbText.label(size: 13, weight: FontWeight.w600, tracking: 1.0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: TbColors.navy, borderRadius: BorderRadius.circular(4)),
              child: Text(
                'v${entry?.version ?? version}',
                style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.4),
              ),
            ),
          ],
        ),
        if (entry?.date != null) ...[
          const SizedBox(height: 4),
          Text(
            'Released ${entry!.date}',
            style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.6, weight: FontWeight.w400),
          ),
        ],
        const SizedBox(height: 16),
        if (entry == null)
          Text('Release notes are unavailable.', style: TbText.body(size: 13, color: TbColors.muted, height: 1.5))
        else
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final section in entry.sections) ...[
                    Text(
                      section.title.toUpperCase(),
                      style: TbText.label(size: 10, color: TbColors.dim, tracking: 1.2, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (final bullet in section.bullets) _Bullet(bullet),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _GotItButton(onTap: () => Navigator.pop(context)),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: TbColors.cyan, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TbText.body(size: 13, color: TbColors.muted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _GotItButton extends StatefulWidget {
  const _GotItButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GotItButton> createState() => _GotItButtonState();
}

class _GotItButtonState extends State<_GotItButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: _h ? TbColors.surface2 : Colors.transparent,
            border: Border.all(color: _h ? TbColors.blue : TbColors.borderStrong),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Got it',
            style: TbText.label(
              size: 12,
              weight: FontWeight.w600,
              color: _h ? TbColors.blue : TbColors.text,
              tracking: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
