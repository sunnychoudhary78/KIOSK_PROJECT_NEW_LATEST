import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskNumericKeypad extends StatelessWidget {
  const KioskNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: [
        for (final row in keys) ...[
          Expanded(
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _Key(
                        label: key,
                        onTap: () {
                          if (key == 'C') {
                            onClear();
                          } else if (key == '⌫') {
                            onBackspace();
                          } else {
                            onDigit(key);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final special = label == 'C' || label == '⌫';
    return Material(
      color: special ? SkpColors.panel : SkpColors.raised,
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: SkpTokens.keypadKeySize),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(color: SkpColors.line),
          ),
          child: label == '⌫'
              ? const Icon(Icons.backspace_outlined, size: 28, color: SkpColors.text)
              : Text(
                  label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: label == 'C' ? SkpColors.gold : SkpColors.text,
                      ),
                ),
        ),
      ),
    );
  }
}
