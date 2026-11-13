import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_print_choice.dart';
import 'package:skp_kiosk/core/ui/kiosk_status.dart';

/// Combined B&W/Color + phone/pay (or free Continue) on one print screen.
class KioskPrintOptionsBody extends StatelessWidget {
  const KioskPrintOptionsBody({
    super.key,
    required this.colorMode,
    required this.bwChargeRupees,
    required this.colorChargeRupees,
    required this.onColorModeChanged,
    required this.onChoosePhone,
    required this.onChoosePay,
    required this.onContinueFree,
    this.headline = 'Print options',
    this.documentHint,
    this.error,
    this.busy = false,
  });

  final String colorMode;
  final int bwChargeRupees;
  final int colorChargeRupees;
  final ValueChanged<String> onColorModeChanged;
  final VoidCallback? onChoosePhone;
  final VoidCallback? onChoosePay;
  final VoidCallback? onContinueFree;
  final String headline;
  final String? documentHint;
  final String? error;
  final bool busy;

  bool get _isColor => colorMode == 'color';

  int get _selectedCharge =>
      _isColor ? colorChargeRupees : bwChargeRupees;

  bool get _isFree => _selectedCharge <= 0;

  String get _modeLabel => _isColor ? 'Color' : 'B&W';

  String get _subtitle {
    final hint = documentHint?.trim();
    final price = _isFree
        ? '$_modeLabel print is free on this kiosk.'
        : '$_modeLabel print is ₹$_selectedCharge per page. Society members can use free $_modeLabel pages when available.';
    if (hint == null || hint.isEmpty) return price;
    return '$hint $price';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Print mode',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PrintModeTile(
                  selected: !_isColor,
                  icon: Icons.filter_b_and_w,
                  title: 'Black & white',
                  subtitle: bwChargeRupees <= 0
                      ? 'Free on this kiosk'
                      : '₹$bwChargeRupees per page',
                  accent: KioskPrintChoiceAccents.bw,
                  onPressed: busy ? null : () => onColorModeChanged('bw'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PrintModeTile(
                  selected: _isColor,
                  icon: Icons.palette_outlined,
                  title: 'Color',
                  subtitle: colorChargeRupees <= 0
                      ? 'Free on this kiosk'
                      : '₹$colorChargeRupees per page',
                  accent: KioskPrintChoiceAccents.color,
                  onPressed: busy ? null : () => onColorModeChanged('color'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _isFree ? 'Ready to print' : 'How would you like to continue?',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isFree
                ? Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: KioskPrimaryButton(
                        label: busy ? 'Preparing…' : 'Continue',
                        icon: Icons.print_outlined,
                        expand: true,
                        loading: busy,
                        onPressed: busy ? null : onContinueFree,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: KioskPrintChoiceCard(
                          icon: Icons.phone_android,
                          title: 'Use phone number',
                          accent: KioskPrintChoiceAccents.phone,
                          subtitle:
                              'Check your society free $_modeLabel quota first.',
                          onPressed: busy ? null : onChoosePhone,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: KioskPrintChoiceCard(
                          icon: Icons.qr_code_2,
                          title: 'Pay without phone',
                          accent: KioskPrintChoiceAccents.pay,
                          subtitle:
                              'Scan UPI and pay ₹$_selectedCharge per page.',
                          onPressed: busy ? null : onChoosePay,
                        ),
                      ),
                    ],
                  ),
          ),
          if (error != null && error!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrintModeTile extends StatefulWidget {
  const _PrintModeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  State<_PrintModeTile> createState() => _PrintModeTileState();
}

class _PrintModeTileState extends State<_PrintModeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;
    final selected = widget.selected;
    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor =
        isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);

    final decoration = isDark
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [accent.withValues(alpha: 0.28), const Color(0xFF17102F)]
                  : const [Color(0xFF211747), Color(0xFF17102F)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.85 : 0.35),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.28 : 0.08),
                blurRadius: 16,
              ),
            ],
          )
        : BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.55 : 0.18),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.12 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            borderRadius: BorderRadius.circular(20),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.05),
            child: Ink(
              decoration: decoration,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.9),
                            accent,
                          ],
                        ),
                      ),
                      child: Icon(widget.icon, size: 26, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
