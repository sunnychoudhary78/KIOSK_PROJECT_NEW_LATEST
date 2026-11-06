import 'package:flutter/material.dart';

class KioskDateStepper extends StatelessWidget {
  const KioskDateStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstYear = 1920,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final int firstYear;

  DateTime get _last => DateTime.now();

  int get _maxDay {
    final lastDay = DateTime(value.year, value.month + 1, 0).day;
    return lastDay;
  }

  void _set({int? year, int? month, int? day}) {
    var y = year ?? value.year;
    var m = month ?? value.month;
    var d = day ?? value.day;
    y = y.clamp(firstYear, _last.year);
    m = m.clamp(1, 12);
    final maxD = DateTime(y, m + 1, 0).day;
    d = d.clamp(1, maxD);
    var next = DateTime(y, m, d);
    if (next.isAfter(_last)) {
      next = _last;
    }
    onChanged(next);
  }

  static DateTime stepColumn(
    DateTime value, {
    required int column,
    required int delta,
    int firstYear = 1920,
  }) {
    final last = DateTime.now();
    final maxDay = DateTime(value.year, value.month + 1, 0).day;
    var year = value.year;
    var month = value.month;
    var day = value.day;
    switch (column) {
      case 1:
        month = ((month - 1 + delta) % 12 + 12) % 12 + 1;
      case 2:
        year = (year + delta).clamp(firstYear, last.year);
      default:
        day = ((day - 1 + delta) % maxDay + maxDay) % maxDay + 1;
    }
    final maxD = DateTime(year, month + 1, 0).day;
    day = day.clamp(1, maxD);
    var next = DateTime(year, month, day);
    if (next.isAfter(last)) {
      next = last;
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepperColumn(
            label: 'Day',
            display: value.day.toString().padLeft(2, '0'),
            onUp: () => _set(day: value.day + 1 > _maxDay ? 1 : value.day + 1),
            onDown: () => _set(day: value.day - 1 < 1 ? _maxDay : value.day - 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StepperColumn(
            label: 'Month',
            display: value.month.toString().padLeft(2, '0'),
            onUp: () => _set(month: value.month == 12 ? 1 : value.month + 1),
            onDown: () => _set(month: value.month == 1 ? 12 : value.month - 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StepperColumn(
            label: 'Year',
            display: value.year.toString(),
            onUp: () => _set(year: value.year + 1),
            onDown: () => _set(year: value.year - 1),
          ),
        ),
      ],
    );
  }
}

class KioskTimeStepper extends StatelessWidget {
  const KioskTimeStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepperColumn(
            label: 'Hour',
            display: value.hour.toString().padLeft(2, '0'),
            onUp: () => onChanged(TimeOfDay(hour: (value.hour + 1) % 24, minute: value.minute)),
            onDown: () => onChanged(TimeOfDay(hour: (value.hour + 23) % 24, minute: value.minute)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StepperColumn(
            label: 'Minute',
            display: value.minute.toString().padLeft(2, '0'),
            onUp: () => onChanged(TimeOfDay(hour: value.hour, minute: (value.minute + 1) % 60)),
            onDown: () => onChanged(TimeOfDay(hour: value.hour, minute: (value.minute + 59) % 60)),
          ),
        ),
      ],
    );
  }

  static TimeOfDay stepColumn(TimeOfDay value, {required int column, required int delta}) {
    int wrap(int current, int mod) => ((current + delta) % mod + mod) % mod;
    if (column == 1) {
      return TimeOfDay(hour: value.hour, minute: wrap(value.minute, 60));
    }
    return TimeOfDay(hour: wrap(value.hour, 24), minute: value.minute);
  }
}

class _StepperColumn extends StatelessWidget {
  const _StepperColumn({
    required this.label,
    required this.display,
    required this.onUp,
    required this.onDown,
  });

  final String label;
  final String display;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF382F50) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepHit(icon: Icons.keyboard_arrow_up_rounded, onTap: onUp),
          Text(
            display,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          _StepHit(icon: Icons.keyboard_arrow_down_rounded, onTap: onDown),
        ],
      ),
    );
  }
}

class _StepHit extends StatelessWidget {
  const _StepHit({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: 32,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          ),
        ),
      ),
    );
  }
}
