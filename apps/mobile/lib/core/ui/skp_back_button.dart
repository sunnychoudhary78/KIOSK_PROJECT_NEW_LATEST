import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class SkpBackButton extends StatelessWidget {
  const SkpBackButton({super.key, this.onPressed, this.enabled = true});

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? (onPressed ?? () => Navigator.of(context).maybePop()) : null,
      style: IconButton.styleFrom(
        backgroundColor: SkpColors.panel,
        side: const BorderSide(color: SkpColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}
