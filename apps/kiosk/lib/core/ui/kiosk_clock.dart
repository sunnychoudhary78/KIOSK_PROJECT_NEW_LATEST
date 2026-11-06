import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';

class KioskClock extends StatefulWidget {
  const KioskClock({
    super.key,
    this.capsule = false,
    this.showDate = false,
  });

  final bool capsule;
  final bool showDate;

  @override
  State<KioskClock> createState() => _KioskClockState();
}

class _KioskClockState extends State<KioskClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime() {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final mm = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$mm $period';
  }

  String _formatDate() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = weekdays[_now.weekday - 1];
    final monthName = months[_now.month - 1];
    final day = _now.day.toString().padLeft(2, '0');
    return '$dayName, $day $monthName ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final timeStr = _formatTime();

    if (widget.capsule) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colors.topBarPillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.topBarPillBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colors.cardGlow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: colors.textSecondary),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    if (widget.showDate) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Text(
      timeStr,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.1,
          ),
    );
  }
}
