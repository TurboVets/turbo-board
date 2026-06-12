// lib/features/ai/presentation/view/ai_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../providers/ai_provider.dart';
import 'widgets/ai_buttons.dart';

/// BYOK Anthropic key entry. Reached via /ai-settings inside the shell.
class AiSettingsScreen extends HookConsumerWidget {
  const AiSettingsScreen({super.key});

  static const String routeName = 'aiSettings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiKeyProvider);
    final controller = useTextEditingController();

    final validating = state is AiKeyValidating;
    final errorText = state is AiKeyError ? state.message : null;

    void submit() {
      final value = controller.text.trim();
      if (value.isEmpty) return;
      ref.read(aiKeyProvider.notifier).submit(value);
    }

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
          child: Text('AI Settings', style: TbText.display(size: 14, tracking: 2.0)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TurboBoard uses your own Anthropic API key (BYOK) for PR summaries and reply drafts. '
                      'The key is stored securely on this device and only leaves it to call Anthropic.',
                      style: TbText.body(size: 13, color: TbColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: TbColors.surface,
                        border: Border.all(color: TbColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ANTHROPIC API KEY',
                                style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4),
                              ),
                              const SizedBox(width: 8),
                              if (state is AiKeyValid) TbBadge('Active', TbSignal.ok, small: true),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _KeyField(controller: controller, enabled: !validating, onSubmit: submit),
                          if (errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(errorText, style: TbText.body(size: 12, color: TbSignal.bad.border)),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              AiPrimaryButton(
                                label: validating ? 'VALIDATING…' : 'SAVE & VALIDATE',
                                onPressed: validating ? null : submit,
                              ),
                              const SizedBox(width: 8),
                              if (state is AiKeyValid)
                                AiGhostButton(
                                  label: 'REMOVE KEY',
                                  onPressed: () {
                                    controller.clear();
                                    ref.read(aiKeyProvider.notifier).clear();
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _KeyField extends StatelessWidget {
  const _KeyField({required this.controller, required this.enabled, required this.onSubmit});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      onSubmitted: (_) => onSubmit(),
      style: TbText.body(size: 13, color: TbColors.text),
      decoration: InputDecoration(
        hintText: 'sk-ant-...',
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: TbColors.border),
        ),
        isDense: true,
      ),
    );
  }
}
