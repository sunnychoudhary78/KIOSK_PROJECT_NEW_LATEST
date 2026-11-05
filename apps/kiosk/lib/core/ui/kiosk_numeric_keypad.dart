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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final special = label == 'C' || label == '⌫';

    final Color bgColor = isDark
        ? (special ? const Color(0xFF1E163E) : const Color(0xFF281C54))
        : (special ? Colors.white : const Color(0xFFF1F5F9));

    final Color borderColor = isDark
        ? const Color(0xFF4A347D)
        : const Color(0xFFDCE4EE);

    final Color textColor = isDark ? Colors.white : const Color(0xFF1B2234);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x2E8B35FF)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: label == '⌫'
              ? Icon(Icons.backspace_outlined, size: 24, color: textColor)
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: label == 'C' ? const Color(0xFFE6007A) : textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
