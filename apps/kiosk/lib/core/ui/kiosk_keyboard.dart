import 'package:flutter/material.dart';

class KioskKeyboard extends StatelessWidget {
  const KioskKeyboard({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.onSpace,
    this.accentColor,
    this.backgroundColor,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onSpace;
  final Color? accentColor;
  final Color? backgroundColor;

  static const _letters = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const _numbers = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '/', ':', ';', '(', ')', '@', '&', '#'],
    ['.', ',', '?', '!', "'", '"', '+', '=', '_'],
  ];

  @override
  Widget build(BuildContext context) {
    return _KeyboardBody(
      onKey: onKey,
      onBackspace: onBackspace,
      onSpace: onSpace ?? () => onKey(' '),
      accentColor: accentColor,
      backgroundColor: backgroundColor,
    );
  }
}

class _KeyboardBody extends StatefulWidget {
  const _KeyboardBody({
    required this.onKey,
    required this.onBackspace,
    required this.onSpace,
    this.accentColor,
    this.backgroundColor,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final Color? accentColor;
  final Color? backgroundColor;

  @override
  State<_KeyboardBody> createState() => _KeyboardBodyState();
}

class _KeyboardBodyState extends State<_KeyboardBody> {
  bool _shifted = true;
  bool _symbols = false;

  void _tapLetter(String raw) {
    final value = _symbols
        ? raw
        : (_shifted ? raw.toUpperCase() : raw.toLowerCase());
    widget.onKey(value);
    if (_shifted && !_symbols) {
      setState(() => _shifted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ??
        (isDark ? const Color(0xFFE11D48) : const Color(0xFF4F46E5));
    final bg = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1B2E) : Colors.white);
    final borderColor =
        isDark ? const Color(0xFF382F50) : const Color(0xFFE2E8F0);

    final rows = _symbols ? KioskKeyboard._numbers : KioskKeyboard._letters;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          // Row 1
          Expanded(
            child: Row(
              children: [
                for (final key in rows[0])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2.5,
                        vertical: 2.5,
                      ),
                      child: _KbKey(
                        label: _symbols
                            ? key
                            : (_shifted ? key : key.toLowerCase()),
                        onTap: () => _tapLetter(key),
                        accentColor: accent,
                        isDark: isDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Row 2
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final key in rows[1])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 2.5,
                        ),
                        child: _KbKey(
                          label: _symbols
                              ? key
                              : (_shifted ? key : key.toLowerCase()),
                          onTap: () => _tapLetter(key),
                          accentColor: accent,
                          isDark: isDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Row 3
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _symbols ? 16 : 38),
              child: Row(
                children: [
                  for (final key in rows[2])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 2.5,
                        ),
                        child: _KbKey(
                          label: _symbols
                              ? key
                              : (_shifted ? key : key.toLowerCase()),
                          onTap: () => _tapLetter(key),
                          accentColor: accent,
                          isDark: isDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Row 4: Modifiers (Shift, 123/ABC, Space, Backspace)
          Expanded(
            child: Row(
              children: [
                // Shift Key
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2.5,
                      vertical: 2.5,
                    ),
                    child: _KbKey(
                      label: _symbols ? 'ABC' : 'Shift',
                      icon: _symbols ? null : Icons.arrow_upward_rounded,
                      highlighted: _shifted && !_symbols,
                      isSpecial: true,
                      onTap: () => setState(() {
                        if (_symbols) {
                          _symbols = false;
                          _shifted = true;
                        } else {
                          _shifted = !_shifted;
                        }
                      }),
                      accentColor: accent,
                      isDark: isDark,
                    ),
                  ),
                ),

                // 123 / ABC Symbol Toggle
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2.5,
                      vertical: 2.5,
                    ),
                    child: _KbKey(
                      label: _symbols ? 'ABC' : '?123',
                      highlighted: _symbols,
                      isSpecial: true,
                      onTap: () => setState(() {
                        _symbols = !_symbols;
                        _shifted = true;
                      }),
                      accentColor: accent,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Space Bar
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2.5,
                      vertical: 2.5,
                    ),
                    child: _KbKey(
                      label: 'Space',
                      isSpecial: true,
                      onTap: widget.onSpace,
                      accentColor: accent,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Backspace Key
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2.5,
                      vertical: 2.5,
                    ),
                    child: _KbKey(
                      icon: Icons.backspace_outlined,
                      isSpecial: true,
                      onTap: widget.onBackspace,
                      accentColor: accent,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KbKey extends StatelessWidget {
  const _KbKey({
    required this.onTap,
    this.label,
    this.icon,
    this.highlighted = false,
    this.isSpecial = false,
    required this.accentColor,
    required this.isDark,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool highlighted;
  final bool isSpecial;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    if (highlighted) {
      bg = accentColor;
      border = accentColor;
      fg = Colors.white;
    } else if (isSpecial) {
      bg = isDark ? const Color(0xFF28203E) : const Color(0xFFF1F5F9);
      border = isDark ? const Color(0xFF3E325C) : const Color(0xFFCBD5E1);
      fg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    } else {
      bg = isDark ? const Color(0xFF1E1730) : Colors.white;
      border = isDark ? const Color(0xFF382C52) : const Color(0xFFE2E8F0);
      fg = isDark ? Colors.white : const Color(0xFF1E1B4B);
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      elevation: isDark ? 0 : 0.8,
      shadowColor: const Color(0x18000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1.1),
          ),
          child: icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    if (label != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        label!,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ],
                  ],
                )
              : Text(
                  label ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: isSpecial ? 13 : 17.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}

void appendToController(
  TextEditingController controller,
  String value, {
  int? maxLength,
}) {
  final next = controller.text + value;
  if (maxLength != null && next.length > maxLength) {
    return;
  }
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: next.length),
  );
}

void backspaceController(TextEditingController controller) {
  if (controller.text.isEmpty) {
    return;
  }
  final next = controller.text.substring(0, controller.text.length - 1);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: next.length),
  );
}
