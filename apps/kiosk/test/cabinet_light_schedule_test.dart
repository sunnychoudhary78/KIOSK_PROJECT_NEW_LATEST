import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/cabinet_light/application/cabinet_light_schedule.dart';

void main() {
  test('overnight window is on after the start time and before the off time', () {
    const config = CabinetLightConfig(
      enabled: true,
      mode: 'schedule',
      onTime: '18:00',
      offTime: '06:00',
    );
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 18, 0)), isTrue);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 23, 30)), isTrue);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 5, 59)), isTrue);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 6, 0)), isFalse);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 12, 0)), isFalse);
  });

  test('same-day window stays off outside the times', () {
    const config = CabinetLightConfig(
      enabled: true,
      mode: 'schedule',
      onTime: '09:00',
      offTime: '17:00',
    );
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 8, 59)), isFalse);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 9, 0)), isTrue);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 16, 59)), isTrue);
    expect(config.shouldBeOn(DateTime(2026, 11, 6, 17, 0)), isFalse);
  });

  test('instant on and off ignore the clock', () {
    const on = CabinetLightConfig(
      enabled: false,
      mode: 'on',
      onTime: '18:00',
      offTime: '06:00',
    );
    const off = CabinetLightConfig(
      enabled: true,
      mode: 'off',
      onTime: '00:00',
      offTime: '23:59',
    );
    expect(on.shouldBeOn(DateTime(2026, 11, 6, 3)), isTrue);
    expect(off.shouldBeOn(DateTime(2026, 11, 6, 12)), isFalse);
  });
}
