// lib/shared/ui/widgets/open_on_github_button.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';

/// Opens a GitHub URL (PR page) in the user's browser.
///
/// Two variants from the design:
/// - [OpenOnGitHubButton.icon] — a compact 24×24 icon button used on PR cards,
///   sitting at the top-right of the repo line.
/// - [OpenOnGitHubButton.labeled] — the full "OPEN ON GITHUB ↗" action used in
///   the PR detail header.
///
/// The tap is self-contained (launches the URL); when nested inside another
/// tappable (the PR card), Flutter routes the tap to this inner button so the
/// card's own onTap does not fire.
class OpenOnGitHubButton extends StatefulWidget {
  const OpenOnGitHubButton.icon({super.key, required this.url}) : labeled = false;
  const OpenOnGitHubButton.labeled({super.key, required this.url}) : labeled = true;

  final String url;
  final bool labeled;

  @override
  State<OpenOnGitHubButton> createState() => _OpenOnGitHubButtonState();
}

class _OpenOnGitHubButtonState extends State<OpenOnGitHubButton> {
  bool _hover = false;

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      log('Failed to open GitHub URL', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Tooltip(
          message: widget.labeled ? 'Open this pull request on GitHub' : 'Open on GitHub',
          child: widget.labeled ? _labeled() : _iconOnly(),
        ),
      ),
    );
  }

  Widget _iconOnly() {
    final color = _hover ? TbColors.cyan : TbColors.muted;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _hover ? TbColors.blue : TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(LucideIcons.gitPullRequest, size: 13, color: color),
    );
  }

  Widget _labeled() {
    final color = _hover ? TbColors.blue : TbColors.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: _hover ? TbColors.blue : TbColors.borderStrong),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gitPullRequest, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            'OPEN ON GITHUB',
            style: TbText.label(size: 11, weight: FontWeight.w600, color: color, tracking: 0.66),
          ),
          const SizedBox(width: 6),
          Text('↗', style: TbText.body(size: 12, color: color)),
        ],
      ),
    );
  }
}
