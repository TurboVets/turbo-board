// lib/features/ai/presentation/view/widgets/ai_buttons.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';

/// Filled blue primary action button in the TurboBoard style. Disabled when
/// [onPressed] is null.
class AiPrimaryButton extends StatefulWidget {
  const AiPrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<AiPrimaryButton> createState() => _AiPrimaryButtonState();
}

class _AiPrimaryButtonState extends State<AiPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = !enabled
        ? TbColors.surface2
        : _hovered
        ? TbColors.blueBright
        : TbColors.blue;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(
            widget.label,
            style: TbText.label(
              size: 12,
              weight: FontWeight.w600,
              color: enabled ? Colors.white : TbColors.dim,
              tracking: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Outline/ghost action button in the TurboBoard style.
class AiGhostButton extends StatefulWidget {
  const AiGhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<AiGhostButton> createState() => _AiGhostButtonState();
}

class _AiGhostButtonState extends State<AiGhostButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered && enabled ? TbColors.surface : Colors.transparent,
            border: Border.all(color: enabled ? TbColors.borderStrong : TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TbText.label(
              size: 12,
              weight: FontWeight.w600,
              color: enabled ? TbColors.text : TbColors.dim,
              tracking: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
