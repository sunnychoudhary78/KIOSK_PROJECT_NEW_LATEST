import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskKeyboard extends StatelessWidget {
  const KioskKeyboard({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.onSpace,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onSpace;

  static const _letters = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const _numbers = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '_', '.', '@', '/', ',', ':', ';'],
    ['!', '#', '&', '+', '=', '?', "'"],
  ];

  @override
  Widget build(BuildContext context) {
    return _KeyboardBody(
      onKey: onKey,
      onBackspace: onBackspace,
      onSpace: onSpace ?? () => onKey(' '),
    );
  }
}

class _KeyboardBody extends StatefulWidget {
  const _KeyboardBody({
    required this.onKey,
    required this.onBackspace,
    required this.onSpace,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;

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
    final rows = _symbols ? KioskKeyboard._numbers : KioskKeyboard._letters;
    return Container(
      color: SkpColors.panel,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r == 1 ? 18 : 0),
                child: Row(
                  children: [
                    for (final key in rows[r])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: _KbKey(
                            label: _symbols
                                ? key
                                : (_shifted ? key : key.toLowerCase()),
                            onTap: () => _tapLetter(key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KbKey(
                      label: _shifted ? 'ABC' : 'Shift',
                      highlighted: _shifted && !_symbols,
                      onTap: () => setState(() {
                        if (_symbols) {
                          _symbols = false;
                          _shifted = true;
                        } else {
                          _shifted = !_shifted;
                        }
                      }),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KbKey(
                      label: _symbols ? 'ABC' : '123',
                      highlighted: _symbols,
                      onTap: () => setState(() {
                        _symbols = !_symbols;
                        _shifted = true;
                      }),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KbKey(label: 'space', onTap: widget.onSpace),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KbKey(
                      label: '⌫',
                      onTap: widget.onBackspace,
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
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? SkpColors.accent : SkpColors.raised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SkpColors.line),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlighted ? Colors.white : SkpColors.text,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

void appendToController(TextEditingController controller, String value, {int? maxLength}) {
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
