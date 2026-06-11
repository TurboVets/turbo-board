// lib/features/repo_setup/presentation/view/widgets/auth_step_indicator.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

/// Two-segment progress bar for the setup wizard (mockup `.steps`/`.step`).
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({super.key, required this.currentStep, this.stepCount = 2});

  /// 0-based index of the active step.
  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: List.generate(stepCount, (i) {
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i == stepCount - 1 ? 0 : 8),
            color: i <= currentStep ? colors.background.accent : colors.border.subtle,
          ),
        );
      }),
    );
  }
}
