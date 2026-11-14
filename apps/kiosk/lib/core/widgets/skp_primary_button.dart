import 'package:flutter/material.dart';

class SkpPrimaryButton extends StatelessWidget {
  const SkpPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
