import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class SkpOtpPinField extends StatelessWidget {
  const SkpOtpPinField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = 6,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final base = PinTheme(
      width: 48,
      height: 56,
      textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: SkpColors.ink,
          ),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkpColors.line),
      ),
    );

    return AutofillGroup(
      child: Pinput(
        controller: controller,
        focusNode: focusNode,
        length: length,
        enabled: enabled,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofillHints: const [AutofillHints.oneTimeCode],
        defaultPinTheme: base,
        focusedPinTheme: base.copyWith(
          decoration: base.decoration!.copyWith(
            border: Border.all(color: SkpColors.accent, width: 1.6),
          ),
        ),
        submittedPinTheme: base.copyWith(
          decoration: base.decoration!.copyWith(
            border: Border.all(color: SkpColors.accent),
          ),
        ),
        errorPinTheme: base.copyWith(
          decoration: base.decoration!.copyWith(
            border: Border.all(color: SkpColors.danger),
          ),
        ),
        onCompleted: onCompleted,
        onChanged: onChanged,
        hapticFeedbackType: HapticFeedbackType.lightImpact,
      ),
    );
  }
}
