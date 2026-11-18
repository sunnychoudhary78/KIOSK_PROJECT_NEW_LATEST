/// Stable dotted keys for post-service star ratings.
abstract final class ServiceRatingKeys {
  static const otpPrint = 'print.otp_print';
  static const quickPrint = 'print.quick_print';
  static const digilockerPrint = 'print.digilocker_print';
  static const wellBeingPrint = 'well_being.print';
  static const wellBeingSession = 'well_being.session';
  static const astrologyPrint = 'astrology.print';
  static const astrologySession = 'astrology.session';
  static const charging = 'home.charging';

  static const familyWellBeing = 'well_being';
  static const familyAstrology = 'astrology';

  /// Maps a rating key to its one-prompt-per-session family, if any.
  static String? familyFor(String serviceKey) {
    if (serviceKey == wellBeingPrint || serviceKey == wellBeingSession) {
      return familyWellBeing;
    }
    if (serviceKey == astrologyPrint || serviceKey == astrologySession) {
      return familyAstrology;
    }
    return null;
  }
}
