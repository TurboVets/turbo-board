// lib/shared/ui/shell/nav_rail.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../../features/repo_setup/presentation/providers/watched_repos_provider.dart';

/// Left navigation rail of the app shell. [collapsed] hides labels (tablet).
class AppNavRail extends ConsumerWidget {
  const AppNavRail({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final watched = ref.watch(watchedReposProvider);
    final auth = ref.watch(authStateProvider);
    final text = Theme.of(context).textTheme;

    final login = switch (auth) {
      AuthAuthenticated(:final user) => user.login,
      _ => null,
    };

    return Container(
      width: collapsed ? 64 : 240,
      color: colors.background.secondary,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(LucideIcons.crosshair, color: colors.foreground.link),
          ),
          const SizedBox(height: 24),
          // Workspace nav
          _NavItem(
            icon: LucideIcons.layoutGrid,
            label: 'PR Board',
            collapsed: collapsed,
            active: true,
            onTap: () => context.go('/'),
          ),
          _NavItem(icon: LucideIcons.circleDot, label: 'Needs attention', collapsed: collapsed, enabled: false),
          _NavItem(icon: LucideIcons.settings2, label: 'Filters', collapsed: collapsed, enabled: false),
          _NavItem(icon: LucideIcons.circleDashed, label: 'Issues', collapsed: collapsed, enabled: false),
          const SizedBox(height: 16),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Watched repos', style: text.labelSmall?.copyWith(color: colors.foreground.primaryMuted)),
            ),
          Expanded(
            child: ListView(
              children: [for (final slug in watched) _RepoItem(slug: slug, collapsed: collapsed)],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // User footer + sign out
          Row(
            children: [
              TetherAvatar(initials: _initials(login), size: TetherAvatarSize.sm),
              if (!collapsed) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(login ?? '—', style: text.bodySmall, overflow: TextOverflow.ellipsis),
                ),
              ],
              TetherIconButton(
                icon: LucideIcons.logOut,
                type: TetherButtonType.ghost,
                size: TetherButtonSize.small,
                semanticsLabel: 'Sign out',
                onPressed: () => ref.read(authStateProvider.notifier).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String? login) {
    if (login == null || login.isEmpty) return '?';
    return login.substring(0, login.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    this.active = false,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = !enabled
        ? colors.foreground.onDisabled
        : active
        ? colors.foreground.link
        : colors.foreground.primary;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepoItem extends StatelessWidget {
  const _RepoItem({required this.slug, required this.collapsed});

  final String slug;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final name = slug.contains('/') ? slug.split('/').last : slug;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const TetherSignalDot(color: TetherBadgeColor.green, size: 8),
          if (!collapsed) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}
