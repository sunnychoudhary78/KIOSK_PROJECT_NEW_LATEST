import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/bmi_calculator.dart';

class BmiInputView extends StatelessWidget {
  const BmiInputView({
    super.key,
    required this.state,
    required this.controller,
  });

  final WellBeingUiState state;
  final WellBeingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF7C3AED);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 55,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1A1030), Color(0xFF2E1065)]
                    : const [Color(0xFFFAF5FF), Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
              ),
              border: Border.all(
                color: isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.28 : 0.12),
                      ),
                      child: const Icon(
                        Icons.monitor_weight_outlined,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMI Calculator',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Adult screening · metric units',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFFC4B5FD)
                                  : const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap a field, then enter values on the keypad.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FieldCard(
                        label: 'Height',
                        hint: '100–230',
                        unit: 'cm',
                        icon: Icons.height_rounded,
                        value: state.bmiHeightDigits.isEmpty
                            ? '—'
                            : state.bmiHeightDigits,
                        selected: state.bmiInputField == BmiInputField.height,
                        isDark: isDark,
                        onTap: () =>
                            controller.setBmiInputField(BmiInputField.height),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldCard(
                        label: 'Weight',
                        hint: '25–250',
                        unit: 'kg',
                        icon: Icons.fitness_center_rounded,
                        value: state.bmiWeightDigits.isEmpty
                            ? '—'
                            : state.bmiWeightDigits,
                        selected: state.bmiInputField == BmiInputField.weight,
                        isDark: isDark,
                        onTap: () =>
                            controller.setBmiInputField(BmiInputField.weight),
                      ),
                    ),
                  ],
                ),
                if (state.bmiInputError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626)
                          .withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.bmiInputError!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const _BmiRangeLegend(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: KioskPrimaryButton(
                    label: 'Calculate BMI',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: controller.submitBmi,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 45,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: isDark ? const Color(0xFF12081F) : Colors.white,
              border: Border.all(
                color: isDark ? const Color(0xFF6D28D9) : const Color(0xFFE9D5FF),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  state.bmiInputField == BmiInputField.height
                      ? 'Enter height'
                      : 'Enter weight',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.bmiInputField == BmiInputField.height
                      ? 'Centimetres'
                      : 'Kilograms',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFFC4B5FD)
                        : const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: KioskNumericKeypad(
                    onDigit: controller.appendBmiDigit,
                    onBackspace: controller.backspaceBmiDigit,
                    onClear: controller.clearBmiDigits,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BmiCompleteView extends StatelessWidget {
  const BmiCompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final result = state.bmiResult;
    if (result == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (result.category) {
      BmiCategory.underweight => const Color(0xFF2563EB),
      BmiCategory.normal => const Color(0xFF059669),
      BmiCategory.overweight => const Color(0xFFD97706),
      BmiCategory.obese => const Color(0xFFDC2626),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.28 : 0.12),
                      isDark ? const Color(0xFF0F172A) : Colors.white,
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        result.categoryLabel.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.bmiLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Body Mass Index · ${result.categoryRangeLabel}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _BmiScaleBar(result: result, accent: accent, isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Height',
                      value: '${result.heightCm.round()}',
                      unit: 'cm',
                      isDark: isDark,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Weight',
                      value: '${result.weightKg.round()}',
                      unit: 'kg',
                      isDark: isDark,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Healthy range',
                      value: result.idealWeightLabel,
                      unit: '',
                      isDark: isDark,
                      accent: accent,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                result.summary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.advice,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiScaleBar extends StatelessWidget {
  const _BmiScaleBar({
    required this.result,
    required this.accent,
    required this.isDark,
  });

  final BmiResult result;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final markerX = result.scalePosition * width;
            return SizedBox(
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 14,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: const [
                            Expanded(flex: 65, child: ColoredBox(color: Color(0xFF3B82F6))),
                            Expanded(flex: 64, child: ColoredBox(color: Color(0xFF22C55E))),
                            Expanded(flex: 49, child: ColoredBox(color: Color(0xFFF59E0B))),
                            Expanded(flex: 100, child: ColoredBox(color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (markerX - 9).clamp(0.0, width - 18),
                    top: 6,
                    child: Container(
                      width: 18,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _scaleLabel('Under', isDark),
            _scaleLabel('Normal', isDark),
            _scaleLabel('Over', isDark),
            _scaleLabel('Obese', isDark),
          ],
        ),
      ],
    );
  }

  Widget _scaleLabel(String text, bool isDark) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.isDark,
    required this.accent,
    this.compact = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool isDark;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF1E1738) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: compact ? 18 : 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BmiRangeLegend extends StatelessWidget {
  const _BmiRangeLegend();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const items = [
      (Color(0xFF3B82F6), 'Under <18.5'),
      (Color(0xFF22C55E), 'Normal 18.5–24.9'),
      (Color(0xFFF59E0B), 'Over 25–29.9'),
      (Color(0xFFEF4444), 'Obese ≥30'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF12081F) : Colors.white,
              border: Border.all(
                color: isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.$1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.hint,
    required this.unit,
    required this.icon,
    required this.value,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String unit;
  final IconData icon;
  final String value;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C3AED);
    return Material(
      color: isDark ? const Color(0xFF12081F) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF)),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFC4B5FD)
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hint,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
