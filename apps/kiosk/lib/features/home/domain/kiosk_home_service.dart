/// Home-screen services that can be enabled/disabled per kiosk.
enum KioskHomeService {
  printDocuments,
  localServices,
  wellBeing,
  phoneCharging,
  astrology,
  fuelStations,
}

extension KioskHomeServiceX on KioskHomeService {
  String get displayName {
    switch (this) {
      case KioskHomeService.printDocuments:
        return 'Print Documents';
      case KioskHomeService.localServices:
        return 'Find Services';
      case KioskHomeService.wellBeing:
        return 'Well Being';
      case KioskHomeService.phoneCharging:
        return 'Phone Charging';
      case KioskHomeService.astrology:
        return 'Astrology';
      case KioskHomeService.fuelStations:
        return 'Fuel Stations';
    }
  }

  /// Platform service codes that must all be enabled for this home tile.
  List<String> get platformCodes {
    switch (this) {
      case KioskHomeService.printDocuments:
        // Prefer umbrella `print` when present; else all print channels.
        return const ['print', 'otp_print', 'quick_print', 'digilocker_print'];
      case KioskHomeService.localServices:
        return const ['local_services'];
      case KioskHomeService.wellBeing:
        return const ['well_being'];
      case KioskHomeService.phoneCharging:
        return const ['phone_charging'];
      case KioskHomeService.astrology:
        return const ['astrology'];
      case KioskHomeService.fuelStations:
        return const ['fuel_stations'];
    }
  }

  /// True when every required platform code is enabled.
  /// If [byCode] is null (catalog never loaded), treat as enabled.
  /// Print: if umbrella `print` exists in the map, that alone decides; otherwise
  /// require otp/quick/digilocker.
  bool isEnabled(Map<String, bool>? byCode) {
    if (byCode == null) {
      return true;
    }
    if (this == KioskHomeService.printDocuments && byCode.containsKey('print')) {
      return byCode['print'] == true;
    }
    final codes = this == KioskHomeService.printDocuments
        ? const ['otp_print', 'quick_print', 'digilocker_print']
        : platformCodes;
    return codes.every((code) => byCode[code] == true);
  }
}
