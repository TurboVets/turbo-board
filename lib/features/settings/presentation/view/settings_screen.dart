// lib/features/settings/presentation/view/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/providers/refresh_interval_provider.dart';
import '../../../../shared/ui/providers/text_scale_provider.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../../repo_setup/presentation/providers/watched_repos_provider.dart';

/// The Settings screen — GitHub connection, watched repos, Anthropic key,
/// appearance. Reached via /settings inside the shell. Matches TurboBoard.dc.html.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0x99141418),
            border: Border(bottom: BorderSide(color: TbColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.centerLeft,
          child: Text('Settings', style: TbText.display(size: 14, tracking: 2.0)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    _GithubSection(),
                    SizedBox(height: 14),
                    _WatchedReposSection(),
                    SizedBox(height: 14),
                    _ProjectSection(),
                    SizedBox(height: 14),
                    _AnthropicKeySection(),
                    SizedBox(height: 14),
                    _BillingCard(),
                    SizedBox(height: 14),
                    _RefreshSection(),
                    SizedBox(height: 14),
                    _AppearanceSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable section card ──────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.body, this.headerTrailing});

  final String title;
  final Widget body;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: TbColors.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text(title, style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 1.0)),
                if (headerTrailing != null) ...[const SizedBox(width: 9), headerTrailing!],
              ],
            ),
          ),
          const Divider(height: 1, color: TbColors.border),
          body,
        ],
      ),
    );
  }
}

enum _BtnKind { primary, outline, danger }

class _Btn extends StatefulWidget {
  const _Btn(this.label, {required this.kind, required this.onTap});

  final String label;
  final _BtnKind kind;
  final VoidCallback? onTap;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    late Color bg, border, fg;
    switch (widget.kind) {
      case _BtnKind.primary:
        bg = !enabled
            ? TbColors.surface2
            : _h
            ? TbColors.blueBright
            : TbColors.blue;
        border = bg;
        fg = enabled ? Colors.white : TbColors.dim;
      case _BtnKind.outline:
        bg = Colors.transparent;
        border = !enabled
            ? TbColors.border
            : _h
            ? TbColors.blue
            : TbColors.borderStrong;
        fg = !enabled
            ? TbColors.dim
            : _h
            ? TbColors.blue
            : TbColors.text;
      case _BtnKind.danger:
        bg = _h && enabled ? TbColors.shiraz : Colors.transparent;
        border = TbColors.shiraz;
        fg = _h && enabled ? Colors.white : TbSignal.bad.text;
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _h = true) : null,
      onExit: enabled ? (_) => setState(() => _h = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
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

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TbText.body(size: 13, color: TbColors.dim),
  filled: true,
  fillColor: TbColors.canvas,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: TbColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: TbColors.blue),
  ),
  isDense: true,
);

Widget _maskedCode(String text) => Builder(
  builder: (context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: TbColors.canvas,
      border: Border.all(color: TbColors.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TbText.label(size: 13, weight: FontWeight.w500, color: TbColors.muted, tracking: 0.6),
    ),
  ),
);

Widget _hint(String text) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: Text(
    text,
    style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
  ),
);

// ─── GitHub connection ──────────────────────────────────────────────────────

class _GithubSection extends HookConsumerWidget {
  const _GithubSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final tokenAsync = ref.watch(githubTokenProvider);
    final editing = useState(false);
    final controller = useTextEditingController();
    final saving = useState(false);

    final login = switch (auth) {
      AuthAuthenticated(:final user) => user.login,
      _ => '—',
    };
    final masked = maskSecret(tokenAsync.asData?.value) ?? '••••••••';

    Future<void> save() async {
      final value = controller.text.trim();
      if (value.isEmpty) return;
      saving.value = true;
      await ref.read(authStateProvider.notifier).submitToken(value);
      saving.value = false;
      editing.value = false;
      controller.clear();
    }

    return _Card(
      title: 'GitHub connection',
      headerTrailing: const TbBadge('✓ Connected', TbSignal.ok, small: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TbAvatarTile(login: login, size: 34),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(login, style: TbText.body(size: 13, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        'turbovets org · personal access token',
                        style: TbText.body(size: 11, color: TbColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                _Btn('Disconnect', kind: _BtnKind.danger, onTap: () => ref.read(authStateProvider.notifier).signOut()),
              ],
            ),
            const SizedBox(height: 15),
            if (!editing.value)
              Row(
                children: [
                  Expanded(child: _maskedCode(masked)),
                  const SizedBox(width: 12),
                  _Btn('Change PAT', kind: _BtnKind.outline, onTap: () => editing.value = true),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TbText.body(size: 13),
                      decoration: _fieldDecoration('ghp_… or github_pat_…'),
                      onSubmitted: (_) => save(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Btn(
                    'Cancel',
                    kind: _BtnKind.outline,
                    onTap: () {
                      editing.value = false;
                      controller.clear();
                    },
                  ),
                  const SizedBox(width: 10),
                  _Btn(saving.value ? 'Saving…' : 'Save', kind: _BtnKind.primary, onTap: saving.value ? null : save),
                ],
              ),
            _hint('Classic PAT · scopes: repo · read:org · read:project · stored in Keychain / Keystore'),
          ],
        ),
      ),
    );
  }
}

// ─── Watched repositories ───────────────────────────────────────────────────

class _WatchedReposSection extends HookConsumerWidget {
  const _WatchedReposSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watched = ref.watch(watchedReposProvider);
    final accessibleAsync = ref.watch(accessibleReposProvider);
    final addController = useTextEditingController();

    // Union of accessible repos and currently-watched slugs, with descriptions.
    final descBySlug = <String, String?>{};
    for (final r in accessibleAsync.asData?.value ?? const []) {
      descBySlug[r.nameWithOwner] = r.description;
    }
    final slugs = {...descBySlug.keys, ...watched}.toList()..sort();

    void add() {
      final value = addController.text.trim();
      if (!RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(value)) return;
      if (!watched.contains(value)) ref.read(watchedReposProvider.notifier).toggle(value);
      addController.clear();
    }

    return _Card(
      title: 'Watched repositories',
      headerTrailing: Text(
        '${watched.length} of ${slugs.length} watched',
        style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.6),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slugs.isEmpty && accessibleAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (slugs.isEmpty && accessibleAsync.hasError)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Could not load repositories. Add one manually below.',
                style: TbText.body(size: 13, color: TbColors.muted),
              ),
            )
          else if (slugs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('No repositories yet — add one below.', style: TbText.body(size: 13, color: TbColors.muted)),
            )
          else
            // Cap the list height so a long repo list scrolls instead of pushing
            // the Add field off-screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final slug in slugs)
                    _RepoRow(
                      slug: slug,
                      desc: descBySlug[slug],
                      watched: watched.contains(slug),
                      onToggle: () => ref.read(watchedReposProvider.notifier).toggle(slug),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addController,
                    style: TbText.body(size: 13),
                    decoration: _fieldDecoration('owner/repo'),
                    onSubmitted: (_) => add(),
                  ),
                ),
                const SizedBox(width: 10),
                _Btn('+ Add', kind: _BtnKind.outline, onTap: add),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow({required this.slug, required this.desc, required this.watched, required this.onToggle});

  final String slug;
  final String? desc;
  final bool watched;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: TbColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slug, style: TbText.label(size: 13, weight: FontWeight.w600, tracking: 0.3)),
                    if (desc != null && desc!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc!,
                        style: TbText.body(size: 11, color: TbColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 11),
              _Toggle(value: watched),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 38,
      height: 21,
      decoration: BoxDecoration(
        color: value ? TbColors.blue : TbColors.borderStrong,
        borderRadius: BorderRadius.circular(4),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
    );
  }
}

// ─── Lead Cockpit project ───────────────────────────────────────────────────

class _ProjectSection extends HookConsumerWidget {
  const _ProjectSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    final picking = useState(selected == null);

    void select(ProjectRef project) {
      ref.read(selectedProjectProvider.notifier).select(project);
      picking.value = false;
    }

    return _Card(
      title: 'Lead Cockpit project',
      headerTrailing: selected == null
          ? const TbBadge('None selected', TbSignal.gray, small: true)
          : const TbBadge('✓ Selected', TbSignal.ok, small: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: selected == null
                          ? Text('No project selected.', style: TbText.body(size: 13, color: TbColors.muted))
                          : _maskedCode('${selected.title}  ·  ${selected.owner} #${selected.number}'),
                    ),
                    const SizedBox(width: 12),
                    _Btn(
                      picking.value ? 'Cancel' : 'Change',
                      kind: _BtnKind.outline,
                      onTap: () => picking.value = !picking.value,
                    ),
                    if (selected != null) ...[
                      const SizedBox(width: 10),
                      _Btn(
                        'Clear',
                        kind: _BtnKind.danger,
                        onTap: () {
                          ref.read(selectedProjectProvider.notifier).clear();
                          picking.value = true;
                        },
                      ),
                    ],
                  ],
                ),
                _hint('The board the Lead Cockpit reads · stored on this device'),
              ],
            ),
          ),
          if (picking.value) ...[
            const Divider(height: 1, color: TbColors.border),
            ProjectPickerList(onSelected: select, selectedKey: selected?.key),
          ],
        ],
      ),
    );
  }
}

// ─── Anthropic API key ──────────────────────────────────────────────────────

enum _ValidateResult { none, checking, valid, invalid, error }

class _AnthropicKeySection extends HookConsumerWidget {
  const _AnthropicKeySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiKeyProvider);
    final saved = state is AiKeyValid;
    final controller = useTextEditingController();
    final validateState = useState(_ValidateResult.none);
    final maskedAsync = ref.watch(anthropicKeyMaskedProvider);

    Widget? badge;
    if (saved) {
      badge = const TbBadge('Active', TbSignal.ok, small: true);
    } else if (state is AiKeyValidating) {
      badge = const TbBadge('Validating', TbSignal.info, small: true);
    } else if (state is AiKeyError) {
      badge = const TbBadge('Error', TbSignal.bad, small: true);
    }

    Future<void> validate() async {
      final value = controller.text.trim();
      if (value.isEmpty) return;
      validateState.value = _ValidateResult.checking;
      final result = await ref.read(aiKeyProvider.notifier).validate(value);
      validateState.value = switch (result) {
        true => _ValidateResult.valid,
        false => _ValidateResult.invalid,
        null => _ValidateResult.error,
      };
    }

    final validateLabel = switch (validateState.value) {
      _ValidateResult.checking => 'Checking…',
      _ValidateResult.valid => '✓ Valid',
      _ValidateResult.invalid => '✗ Invalid',
      _ValidateResult.error => 'Retry',
      _ValidateResult.none => 'Validate',
    };

    return _Card(
      title: 'Anthropic API key',
      headerTrailing: badge,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: saved
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _maskedCode(maskedAsync.asData?.value ?? '••••••••')),
                      const SizedBox(width: 12),
                      _Btn('Remove key', kind: _BtnKind.danger, onTap: () => ref.read(aiKeyProvider.notifier).clear()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Summary, Draft reply and Inbox triage are enabled. The key lives in your device '
                    'Keychain / Keystore — never logged, never sent to GitHub.',
                    style: TbText.body(size: 12, color: TbColors.muted, height: 1.5),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: TbText.body(size: 13, color: TbColors.muted, height: 1.55),
                      children: [
                        const TextSpan(text: 'Create a key at '),
                        TextSpan(
                          text: 'console.anthropic.com',
                          style: TbText.body(size: 13, weight: FontWeight.w600),
                        ),
                        const TextSpan(
                          text:
                              ' (Settings → API keys) and paste it here — keys start with sk-ant-. '
                              'Note: a claude.ai Pro/Max subscription does not include API access; the API '
                              'is billed separately, pay-per-use.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          obscureText: true,
                          style: TbText.body(size: 13),
                          decoration: _fieldDecoration('sk-ant-api03-…'),
                          onChanged: (_) => validateState.value = _ValidateResult.none,
                          onSubmitted: (_) => validate(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Btn(
                        validateLabel,
                        kind: _BtnKind.outline,
                        onTap: validateState.value == _ValidateResult.checking ? null : validate,
                      ),
                      const SizedBox(width: 10),
                      _Btn(
                        state is AiKeyValidating ? 'Saving…' : 'Save',
                        kind: _BtnKind.primary,
                        onTap: state is AiKeyValidating
                            ? null
                            : () => ref.read(aiKeyProvider.notifier).submit(controller.text.trim()),
                      ),
                    ],
                  ),
                  if (state is AiKeyError) ...[
                    const SizedBox(height: 8),
                    Text(state.message, style: TbText.body(size: 12, color: TbSignal.bad.border)),
                  ],
                  _hint('Validated with a 1-token test call · stored in Keychain / Keystore — never logged'),
                ],
              ),
      ),
    );
  }
}

// ─── Billing ────────────────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  const _BillingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILLING', style: TbText.label(size: 11, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 10),
          Text(
            'AI features call the Anthropic Messages API directly from the app with your key — there is no '
            'TurboBoard backend in the loop. Summaries, triage and reply drafts are pay-per-use, billed to your '
            'Anthropic account — typically well under \$1/month at this team\'s volume. No PR content is stored '
            'by TurboBoard.',
            style: TbText.body(size: 13, color: TbColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─── Auto-refresh ───────────────────────────────────────────────────────────

class _RefreshSection extends ConsumerWidget {
  const _RefreshSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(refreshIntervalProvider);
    final index = refreshIntervalSteps.indexOf(seconds).clamp(0, refreshIntervalSteps.length - 1);

    return _Card(
      title: 'Auto-refresh',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Refresh interval', style: TbText.body(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                    'How often the board, triage and PR detail refetch from GitHub',
                    style: TbText.body(size: 11, color: TbColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 240,
              child: Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: TbColors.blue,
                        inactiveTrackColor: TbColors.border,
                        thumbColor: TbColors.text,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        min: 0,
                        max: (refreshIntervalSteps.length - 1).toDouble(),
                        divisions: refreshIntervalSteps.length - 1,
                        value: index.toDouble(),
                        onChanged: (v) =>
                            ref.read(refreshIntervalProvider.notifier).setSeconds(refreshIntervalSteps[v.round()]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: TbColors.navy,
                      border: Border.all(color: TbColors.cyan),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      refreshIntervalLabel(seconds),
                      style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appearance ─────────────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    // Slider works in px (12–18); base 14px == scale 1.0.
    final px = (scale * 14).round().clamp(12, 18);

    return _Card(
      title: 'Appearance',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font size', style: TbText.body(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                    'Applies across the board, triage and PR detail',
                    style: TbText.body(size: 11, color: TbColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 240,
              child: Row(
                children: [
                  Text('A', style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.4)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: TbColors.blue,
                        inactiveTrackColor: TbColors.border,
                        thumbColor: TbColors.text,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        min: 12,
                        max: 18,
                        divisions: 6,
                        value: px.toDouble(),
                        onChanged: (v) => ref.read(textScaleProvider.notifier).setScale(v / 14.0),
                      ),
                    ),
                  ),
                  Text('A', style: TbText.label(size: 15, color: TbColors.dim, tracking: 0.4)),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: TbColors.navy,
                      border: Border.all(color: TbColors.cyan),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${px}PX',
                      style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
