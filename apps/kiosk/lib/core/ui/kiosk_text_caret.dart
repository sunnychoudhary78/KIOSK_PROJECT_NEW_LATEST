import 'package:flutter/material.dart';

/// Blinking insertion mark for kiosk fields that are not real [TextField]s.
class KioskTextCaret extends StatefulWidget {
  const KioskTextCaret({
    super.key,
    this.height = 20,
    this.color,
  });

  final double height;
  final Color? color;

  @override
  State<KioskTextCaret> createState() => _KioskTextCaretState();
}

class _KioskTextCaretState extends State<KioskTextCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    return FadeTransition(
      opacity: _blink,
      child: Container(
        width: 2,
        height: widget.height,
        margin: const EdgeInsets.only(left: 1),
        color: color,
      ),
    );
  }
}

/// Value text with a caret at the insertion point when [showCaret] is set.
/// An empty value shows [hint] after the caret.
class KioskCaretText extends StatelessWidget {
  const KioskCaretText({
    super.key,
    required this.text,
    required this.showCaret,
    this.hint,
    this.style,
    this.hintStyle,
    this.caretHeight = 20,
    this.caretColor,
    this.maxLines,
  });

  final String text;
  final bool showCaret;
  final String? hint;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final double caretHeight;
  final Color? caretColor;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final empty = text.isEmpty;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (empty && showCaret)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: KioskTextCaret(height: caretHeight, color: caretColor),
            ),
          TextSpan(
            text: empty ? (hint ?? '') : text,
            style: empty ? hintStyle : null,
          ),
          if (!empty && showCaret)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: KioskTextCaret(height: caretHeight, color: caretColor),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
