import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/home/domain/kiosk_home_service.dart';

void main() {
  group('KioskHomeService.isEnabled', () {
    test('treats a null catalog as enabled', () {
      for (final service in KioskHomeService.values) {
        expect(service.isEnabled(null), isTrue);
      }
    });

    test('print requires all three print codes', () {
      expect(
        KioskHomeService.printDocuments.isEnabled({
          'otp_print': true,
          'quick_print': true,
          'digilocker_print': true,
        }),
        isTrue,
      );
      expect(
        KioskHomeService.printDocuments.isEnabled({
          'otp_print': true,
          'quick_print': false,
          'digilocker_print': true,
        }),
        isFalse,
      );
      expect(
        KioskHomeService.printDocuments.isEnabled({
          'otp_print': true,
          'quick_print': true,
        }),
        isFalse,
      );
    });

    test('single-code tiles require their platform code', () {
      expect(
        KioskHomeService.wellBeing.isEnabled({'well_being': true}),
        isTrue,
      );
      expect(
        KioskHomeService.wellBeing.isEnabled({'well_being': false}),
        isFalse,
      );
      expect(
        KioskHomeService.phoneCharging.isEnabled({}),
        isFalse,
      );
      expect(
        KioskHomeService.localServices.isEnabled({'local_services': true}),
        isTrue,
      );
    });
  });
}
