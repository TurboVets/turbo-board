// lib/shared/ui/shell/nav_rail.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/filters/presentation/providers/filters_provider.dart';
import '../../../features/needs_attention/presentation/providers/needs_attention_provider.dart';
import '../../../features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../../features/repo_setup/presentation/providers/watched_repos_provider.dart';
import '../providers/app_version_provider.dart';
import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';
import '../widgets/tb_badge.dart';
import '../widgets/turbo_mark.dart';
import '../widgets/whats_new_dialog.dart';

/// Left navigation rail of the app shell. [collapsed] hides labels (tablet).
class AppNavRail extends ConsumerWidget {
  const AppNavRail({super.key, required this.collapsed});

  final bool collapsed;

  static const double _expandedWidth = 236;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watched = ref.watch(watchedReposProvider);
    final auth = ref.watch(authStateProvider);
    final attentionCount = ref.watch(needsAttentionBadgeProvider);
    final version = ref.watch(appVersionProvider).asData?.value;
    // maybeOf so the rail still renders in isolation (widget tests) without a router.
    final location = GoRouter.maybeOf(context)?.state.matchedLocation ?? '/';

    final login = switch (auth) {
      AuthAuthenticated(:final user) => user.login,
      _ => null,
    };

    return Container(
      width: collapsed ? _collapsedWidth : _expandedWidth,
      decoration: const BoxDecoration(
        color: TbColors.railBg,
        border: Border(right: BorderSide(color: TbColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          _RailHeader(collapsed: collapsed),

          // ── Nav ──────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WORKSPACE section label
                  if (!collapsed) const _SectionLabel('WORKSPACE') else const SizedBox(height: 12),

                  // Active: PR Board
                  _NavItem(
                    icon: LucideIcons.layoutGrid,
                    label: 'PR Board',
                    collapsed: collapsed,
                    active: location == '/',
                    onTap: () => context.go('/'),
                  ),

                  _NavItem(
                    icon: LucideIcons.circleDot,
                    label: 'Needs attention',
                    collapsed: collapsed,
                    active: location == '/needs-attention',
                    badgeCount: attentionCount,
                    onTap: () => context.go('/needs-attention'),
                  ),
                  // ISSUES section
                  if (!collapsed) const _SectionLabel('ISSUES') else const SizedBox(height: 12),
                  _NavItem(
                    icon: LucideIcons.crosshair,
                    label: 'Lead cockpit',
                    collapsed: collapsed,
                    active: location == '/lead-cockpit',
                    onTap: () => context.go('/lead-cockpit'),
                  ),
                  _NavItem(
                    icon: LucideIcons.chartNoAxesColumn,
                    label: 'Sprint report',
                    collapsed: collapsed,
                    active: location == '/sprint-report',
                    onTap: () => context.go('/sprint-report'),
                  ),
                  _NavItem(
                    icon: LucideIcons.settings2,
                    label: 'Settings',
                    collapsed: collapsed,
                    active: location == '/settings',
                    onTap: () => context.go('/settings'),
                  ),

                  // WATCHED REPOS section label
                  if (!collapsed) const _SectionLabel('WATCHED REPOS') else const SizedBox(height: 12),

                  // Repo rows
                  for (final slug in watched) _RepoItem(slug: slug, collapsed: collapsed),
                ],
              ),
            ),
          ),
          _versionRow(context, version, collapsed),

          // ── Footer ───────────────────────────────────────────────────────
          _RailFooter(
            login: login,
            collapsed: collapsed,
            onSignOut: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  /// `v0.1.2` label at the bottom of the rail (above the user row) with a
  /// "What's new" button at the end of the row. Hidden until [PackageInfo]
  /// resolves (instant in practice). Collapsed: just the icon button.
  Widget _versionRow(BuildContext context, String? version, bool collapsed) {
    if (version == null) return const SizedBox.shrink();
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(child: _WhatsNewButton(version: version)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 10, bottom: 8),
      child: Row(
        children: [
          Text(
            'v$version',
            style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.8, weight: FontWeight.w600),
          ),
          const Spacer(),
          _WhatsNewButton(version: version),
        ],
      ),
    );
  }
}

/// 24×24 icon button opening the "What's new" dialog for the running version.
class _WhatsNewButton extends StatefulWidget {
  const _WhatsNewButton({required this.version});

  final String version;

  @override
  State<_WhatsNewButton> createState() => _WhatsNewButtonState();
}

class _WhatsNewButtonState extends State<_WhatsNewButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? TbColors.cyan : TbColors.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showWhatsNewDialog(context, widget.version),
        child: Tooltip(
          message: "What's new",
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _hover ? TbColors.blue : TbColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(LucideIcons.sparkles, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: collapsed
          ? const EdgeInsets.symmetric(vertical: 16, horizontal: 10)
          : const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const TurboMark(size: 30),
          if (!collapsed) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TURBO-BOARD', style: TbText.display(size: 16, tracking: 2.88), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    'Boost your flow, ship faster',
                    style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.08, weight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        text,
        style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.08, weight: FontWeight.w400),
      ),
    );
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    this.active = false,
    this.badgeCount = 0,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fgColor;
    final Color bgColor;
    final Color leftBorderColor;

    if (widget.active) {
      fgColor = TbColors.text;
      bgColor = TbColors.surface;
      leftBorderColor = TbColors.blue;
    } else if (_hovered) {
      fgColor = TbColors.text;
      bgColor = TbColors.surface;
      leftBorderColor = Colors.transparent;
    } else {
      fgColor = TbColors.muted;
      bgColor = Colors.transparent;
      leftBorderColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: leftBorderColor, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(9, 9, 11, 9),
          child: Row(
            children: [
              SizedBox(
                width: 15,
                // Collapsed: overlay the badge dot on the icon (no room for a
                // sibling in the 21px-wide icon-only row).
                child: widget.collapsed && widget.badgeCount > 0
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(widget.icon, size: 14, color: fgColor),
                          Positioned(right: -4, top: -3, child: TbSignalDot(color: TbColors.cyan, size: 6)),
                        ],
                      )
                    : Icon(widget.icon, size: 14, color: fgColor),
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TbText.body(size: 13, weight: FontWeight.w500, color: fgColor, height: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: TbColors.navy, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '${widget.badgeCount}',
                      style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Repo item ────────────────────────────────────────────────────────────────

/// A watched-repo row in the nav rail. Tapping it includes/excludes that repo
/// from the board (see [ActiveFilters.toggleRepoVisibility]); excluded rows dim.
class _RepoItem extends ConsumerStatefulWidget {
  const _RepoItem({required this.slug, required this.collapsed});

  final String slug;
  final bool collapsed;

  @override
  ConsumerState<_RepoItem> createState() => _RepoItemState();
}

class _RepoItemState extends ConsumerState<_RepoItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.slug.contains('/') ? widget.slug.split('/').last : widget.slug;
    final dotColor = TbRepoColor.forSlug(widget.slug);

    final visible = ref.watch(activeFiltersProvider.select((f) => f.repos.isEmpty || f.repos.contains(widget.slug)));
    final count = ref.watch(prCountsByRepoProvider)[widget.slug];

    final fgColor = _hovered ? TbColors.text : TbColors.muted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: visible ? 'Click to hide from the board' : 'Click to show on the board',
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: () => ref
              .read(activeFiltersProvider.notifier)
              .toggleRepoVisibility(widget.slug, ref.read(watchedReposProvider)),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: visible ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: _hovered ? TbColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: const Border(left: BorderSide(color: Colors.transparent, width: 2)),
              ),
              padding: const EdgeInsets.fromLTRB(9, 9, 11, 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 15,
                    child: Center(child: TbSignalDot(color: dotColor, size: 8)),
                  ),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TbText.body(size: 13, weight: FontWeight.w500, color: fgColor, height: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Open-PR count chip — em-dash until the board data lands.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        count == null ? '—' : '$count',
                        style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.muted, tracking: 0),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _RailFooter extends StatefulWidget {
  const _RailFooter({required this.login, required this.collapsed, required this.onSignOut});

  final String? login;
  final bool collapsed;
  final VoidCallback onSignOut;

  @override
  State<_RailFooter> createState() => _RailFooterState();
}

class _RailFooterState extends State<_RailFooter> {
  bool _exitHovered = false;

  String get _initials {
    final l = widget.login;
    if (l == null || l.isEmpty) return '?';
    return l.substring(0, l.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Confirm before signing out — prevents accidental clicks on EXIT.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: TbColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: TbColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign out?', style: TbText.label(size: 13, weight: FontWeight.w600, tracking: 1.0)),
                const SizedBox(height: 10),
                Text(
                  "You'll need to re-enter your GitHub token to sign back in.",
                  style: TbText.body(size: 13, color: TbColors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(label: 'Cancel', danger: false, onTap: () => Navigator.pop(ctx, false)),
                    const SizedBox(width: 10),
                    _DialogButton(label: 'Sign out', danger: true, onTap: () => Navigator.pop(ctx, true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: widget.collapsed ? _buildCollapsed() : _buildExpanded(),
    );
  }

  Widget _buildCollapsed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarTile(initials: _initials),
        const SizedBox(height: 8),
        MouseRegion(
          onEnter: (_) => setState(() => _exitHovered = true),
          onExit: (_) => setState(() => _exitHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _confirmSignOut(context),
            child: Tooltip(
              message: 'Sign out',
              child: Icon(LucideIcons.logOut, size: 16, color: _exitHovered ? const Color(0xFFE94A5F) : TbColors.dim),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _AvatarTile(initials: _initials),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sang Nguyen', style: TbText.body(size: 12, height: 1.2), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(
                    widget.login ?? '—',
                    style: TbText.body(size: 11, color: TbColors.muted, height: 1.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            MouseRegion(
              onEnter: (_) => setState(() => _exitHovered = true),
              onExit: (_) => setState(() => _exitHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _confirmSignOut(context),
                child: Text(
                  'EXIT',
                  style: TbText.label(
                    size: 10,
                    color: _exitHovered ? const Color(0xFFE94A5F) : TbColors.dim,
                    tracking: 0.8,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 30×30 avatar tile: navy bg, blue border, pale initials — matches the design.
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TbColors.navy,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TbColors.blue),
      ),
      child: Text(
        initials,
        style: TbText.label(size: 11, weight: FontWeight.w700, color: const Color(0xFFCFE3FF), tracking: 0),
      ),
    );
  }
}

/// A confirm-dialog button: danger (shiraz) or neutral (outline), with hover.
class _DialogButton extends StatefulWidget {
  const _DialogButton({required this.label, required this.danger, required this.onTap});

  final String label;
  final bool danger;
  final VoidCallback onTap;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final Color border = widget.danger ? TbColors.shiraz : TbColors.borderStrong;
    final Color bg = _h ? (widget.danger ? TbColors.shiraz : TbColors.surface2) : Colors.transparent;
    final Color fg = widget.danger
        ? (_h ? Colors.white : const Color(0xFFFBD0D3))
        : (_h ? const Color(0xFF0073FF) : TbColors.text);
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
            color: bg,
            border: Border.all(color: _h && !widget.danger ? const Color(0xFF0073FF) : border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TbText.label(size: 12, weight: FontWeight.w600, color: fg, tracking: 0.8),
          ),
        ),
      ),
    );
  }
}
