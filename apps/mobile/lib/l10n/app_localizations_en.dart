// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Kiosk Mobile';

  @override
  String get brandName => 'Smart Kiosk';

  @override
  String get guestSubtitle =>
      'Upload documents, get a print OTP by SMS, and collect prints at any Smart Kiosk.';

  @override
  String get signInCta => 'Sign in with mobile OTP';

  @override
  String get tabHome => 'Home';

  @override
  String get tabHistory => 'History';

  @override
  String get tabNearby => 'Nearby';

  @override
  String get tabProfile => 'Profile';

  @override
  String get stepUpload => 'Upload';

  @override
  String get stepOtpSms => 'OTP SMS';

  @override
  String get stepPrint => 'Print';

  @override
  String get howItWorksTitle => 'How it works';

  @override
  String get homeHeadline => 'Print at a kiosk';

  @override
  String get homeHelper =>
      'Upload PDFs on your phone, receive an OTP by SMS, then enter it on the kiosk.';

  @override
  String get greetingReady => 'Ready to print';

  @override
  String signedInAs(String phone) {
    return 'Signed in · $phone';
  }

  @override
  String get uploadTileTitle => 'Upload & get print OTP';

  @override
  String get uploadTileSubtitle =>
      'Select documents and receive your kiosk OTP by SMS.';

  @override
  String get nearbyTileTitle => 'Find nearest kiosk';

  @override
  String get nearbyTileSubtitle =>
      'See active kiosks sorted by distance from you.';

  @override
  String get activeSessionTitle => 'Active print session';

  @override
  String get statusPayNow => 'Pay now';

  @override
  String get statusOtpSent => 'OTP sent';

  @override
  String get statusPrinted => 'Printed';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusReady => 'Ready';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get findKiosk => 'Find nearest kiosk';

  @override
  String get pay => 'Pay';

  @override
  String validFor(String time) {
    return 'Valid for $time';
  }

  @override
  String get otpExpired => 'OTP expired';

  @override
  String get expiredLabel => 'Expired';

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginHelper =>
      'Sign in with your mobile number to upload documents and print at a kiosk.';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String otpSentTo(String phone) {
    return 'We sent a one-time code to $phone';
  }

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get mobileHint => '10-digit mobile';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get verifyContinue => 'Verify & continue';

  @override
  String get changeNumber => 'Change number';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get citizenAccount => 'Citizen account';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get howItWorks => 'How it works';

  @override
  String get about => 'About Smart Kiosk';

  @override
  String get signOut => 'Sign out';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get uploadTitle => 'Upload documents';

  @override
  String get uploadHelper =>
      'After upload, free sessions get an OTP by SMS. Extra pages require payment first, then the OTP is sent.';

  @override
  String get labelOptional => 'Label (optional)';

  @override
  String get labelHint => 'e.g. School certificates';

  @override
  String get tapToAddPdfs => 'Tap to add PDF documents';

  @override
  String pdfsSelected(int count) {
    return '$count PDF(s) selected — tap to replace';
  }

  @override
  String get pdfOnlyHint => 'PDF only · page limits enforced by server';

  @override
  String get printColor => 'Print color';

  @override
  String get colorBw => 'Black & white';

  @override
  String get colorColor => 'Color';

  @override
  String get colorHelp =>
      'Color prints use a higher extra-page rate set by the operator.';

  @override
  String get bwHelp =>
      'Black & white is the default and usually costs less per extra page.';

  @override
  String get selectKiosk => 'Print kiosk';

  @override
  String get chooseKioskToContinue => 'Choose the kiosk where you will print';

  @override
  String kioskPrintPricing(int free, int charge, int max) {
    return 'First $free page(s) free, then ₹$charge each. Max $max pages.';
  }

  @override
  String printOnlyAtKiosk(String name) {
    return 'Print only at $name';
  }

  @override
  String get addPdfsToContinue => 'Add one or more PDFs to continue.';

  @override
  String get uploadContinue => 'Upload & continue';

  @override
  String get uploading => 'Uploading…';

  @override
  String get payExtraPages => 'Pay for extra pages';

  @override
  String payHelper(int count) {
    return 'The first $count page(s) are free. OTP is sent only after payment succeeds.';
  }

  @override
  String get noPaymentDue => 'No payment due.';

  @override
  String get documentsReady => 'Documents ready';

  @override
  String get printColorLabel => 'Print color';

  @override
  String get totalPages => 'Total pages';

  @override
  String get freePages => 'Free pages';

  @override
  String get extraPages => 'Extra pages';

  @override
  String get chargePerPage => 'Charge per extra page';

  @override
  String get amountDue => 'Amount due';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get processing => 'Processing…';

  @override
  String get otpSentTitle => 'OTP sent by SMS';

  @override
  String get otpSentHelper =>
      'Check your messages, then enter the OTP on the chosen kiosk to preview and print.';

  @override
  String pagesColorFiles(int pages, String color, int files) {
    return '$pages page(s) · $color · $files file(s)';
  }

  @override
  String get done => 'Done';

  @override
  String get uploadMore => 'Upload more documents';

  @override
  String get noActiveSession => 'No active print session.';

  @override
  String get noActiveSessionHelper =>
      'Upload documents first to receive a print OTP.';

  @override
  String get uploadDocuments => 'Upload documents';

  @override
  String get nearestKiosks => 'Nearest kiosks';

  @override
  String get nearestHelper => 'Sorted by distance from your current location.';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get noKiosks => 'No kiosks nearby right now.';

  @override
  String get noKiosksHelper =>
      'Pull to refresh, or try again when you are closer to a Smart Kiosk.';

  @override
  String get locationRequired =>
      'Location permission is required to find nearby kiosks.';

  @override
  String get directions => 'Directions';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String kiosksOnMap(int count, String suffix) {
    return '$count kiosk$suffix on map';
  }

  @override
  String get noKiosksOnMap => 'No kiosks to show on the map.';

  @override
  String get couldNotOpenMaps => 'Could not open Maps';

  @override
  String get historyTitle => 'Print history';

  @override
  String get historyHelper => 'Your recent OTP print sessions.';

  @override
  String get historyEmpty => 'No print sessions yet';

  @override
  String get historyEmptyHelper =>
      'Upload a PDF to get a kiosk OTP. Your sessions will appear here.';

  @override
  String get activeSection => 'Active';

  @override
  String get pastSection => 'Earlier';

  @override
  String get aboutTitle => 'About Smart Kiosk';

  @override
  String get aboutBody =>
      'Smart Kiosk Platform lets you upload documents on your phone, pay only for extra pages, and collect prints at a nearby kiosk with a one-time SMS code.\n\nYour OTP is sent to your mobile number and is never shown in this app.';

  @override
  String get howItWorksIntro =>
      'Three steps from your phone to a printed copy.';

  @override
  String get howItWorksStep1Title => 'Upload on your phone';

  @override
  String get howItWorksStep1Body =>
      'Choose one or more PDFs, pick black & white or color, and add an optional label.';

  @override
  String get howItWorksStep2Title => 'Get an OTP by SMS';

  @override
  String get howItWorksStep2Body =>
      'Free pages are issued immediately. Extra pages are paid first, then the OTP is sent to your number.';

  @override
  String get howItWorksStep3Title => 'Print at a kiosk';

  @override
  String get howItWorksStep3Body =>
      'Find a nearby Smart Kiosk, enter the OTP on the screen, preview, and collect your prints.';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';
}
