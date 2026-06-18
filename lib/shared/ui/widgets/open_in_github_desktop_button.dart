// lib/shared/ui/widgets/open_in_github_desktop_button.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';

/// Opens a pull request's branch in the GitHub Desktop app.
///
/// Uses GitHub Desktop's deep-link scheme:
/// ```
/// x-github-client://openRepo/https://github.com/OWNER/REPO?branch=BRANCH&pr=NUMBER
/// ```
/// GitHub Desktop checks out (or fetches) the head branch and surfaces the PR.
///
/// The scheme is handled by the OS protocol handler, so it works from desktop
/// builds and from the browser (web) — the browser hands the URL off to the OS,
/// which launches GitHub Desktop if installed. When GitHub Desktop is not
/// installed the OS simply ignores the request.
class OpenInGitHubDesktopButton extends StatefulWidget {
  const OpenInGitHubDesktopButton({
    super.key,
    required this.repo,
    required this.headRefName,
    required this.number,
    this.isCrossRepository = false,
    this.compact = false,
  });

  /// "owner/name" of the base repo (the one being viewed).
  final String repo;

  /// Head (feature) branch name to check out.
  final String headRefName;

  /// PR number to surface.
  final int number;

  /// Whether the head branch lives in a fork. Fork PRs check out via the
  /// synthetic `pr/<number>` ref instead of the head branch name.
  final bool isCrossRepository;

  /// Icon-only variant (24×24) — use where horizontal space is tight (phones).
  final bool compact;

  @override
  State<OpenInGitHubDesktopButton> createState() => _OpenInGitHubDesktopButtonState();
}

class _OpenInGitHubDesktopButtonState extends State<OpenInGitHubDesktopButton> {
  bool _hover = false;

  Uri _deepLink() {
    final base = 'x-github-client://openRepo/https://github.com/${widget.repo}';
    // GitHub Desktop's URL handler validates the params strictly: when `pr` is
    // present it expects a fork PR and requires `branch` to be `pr/<number>`;
    // for a same-repo PR it wants just the head branch and NO `pr` param.
    // Sending both with a plain branch name makes Desktop open the repo without
    // checking anything out.
    if (widget.isCrossRepository) {
      return Uri.parse('$base?pr=${widget.number}&branch=${Uri.encodeQueryComponent('pr/${widget.number}')}');
    }
    return Uri.parse('$base?branch=${Uri.encodeQueryComponent(widget.headRefName)}');
  }

  Future<void> _open() async {
    try {
      await launchUrl(_deepLink(), mode: LaunchMode.externalApplication);
    } catch (e, st) {
      log('Failed to open branch in GitHub Desktop', error: e, stackTrace: st);
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
          message: 'Check out this branch in GitHub Desktop',
          child: widget.compact ? _iconOnly() : _labeled(),
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
      child: Icon(LucideIcons.gitBranch, size: 13, color: color),
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
          Icon(LucideIcons.gitBranch, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            'OPEN IN DESKTOP',
            style: TbText.label(size: 11, weight: FontWeight.w600, color: color, tracking: 0.66),
          ),
        ],
      ),
    );
  }
}
