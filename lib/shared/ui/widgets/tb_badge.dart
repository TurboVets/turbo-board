import 'package:flutter/widgets.dart';

import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';

/// A Tether signal chip: deep background, bright border, pale uppercase text.
/// Matches the design's badge recipe exactly.
class TbBadge extends StatelessWidget {
  const TbBadge(this.label, this.signal, {super.key, this.small = false});

  final String label;
  final TbSignal signal;

  /// `small` = the 10px metadata variant; default is the 11px card variant.
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: signal.bg,
        border: Border.all(color: signal.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TbText.label(size: small ? 10 : 11, weight: FontWeight.w500, color: signal.text, tracking: 0.4),
      ),
    );
  }
}

/// A small square status dot (the design uses sharp 7–9px squares, not circles).
class TbSignalDot extends StatelessWidget {
  const TbSignalDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ColoredBox(color: color),
  );
}

/// A monogram avatar tile (rounded square, brand-tinted background).
class TbAvatarTile extends StatelessWidget {
  const TbAvatarTile({super.key, required this.login, this.size = 18});

  final String login;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TbAvatar.bgFor(login),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Text(
        TbAvatar.initials(login),
        style: TbText.label(size: size * 0.5, weight: FontWeight.w700, color: TbColors.text, tracking: 0.2),
      ),
    );
  }
}
