import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Kiosk Mobile'**
  String get appTitle;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Smart Kiosk'**
  String get brandName;

  /// No description provided for @guestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload documents, get a print OTP by SMS, and collect prints at any Smart Kiosk.'**
  String get guestSubtitle;

  /// No description provided for @signInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in with mobile OTP'**
  String get signInCta;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get tabNearby;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @stepUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get stepUpload;

  /// No description provided for @stepOtpSms.
  ///
  /// In en, this message translates to:
  /// **'OTP SMS'**
  String get stepOtpSms;

  /// No description provided for @stepPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get stepPrint;

  /// No description provided for @howItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorksTitle;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Print at a kiosk'**
  String get homeHeadline;

  /// No description provided for @homeHelper.
  ///
  /// In en, this message translates to:
  /// **'Upload PDFs on your phone, receive an OTP by SMS, then enter it on the kiosk.'**
  String get homeHelper;

  /// No description provided for @greetingReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to print'**
  String get greetingReady;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in · {phone}'**
  String signedInAs(String phone);

  /// No description provided for @uploadTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload & get print OTP'**
  String get uploadTileTitle;

  /// No description provided for @uploadTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select documents and receive your kiosk OTP by SMS.'**
  String get uploadTileSubtitle;

  /// No description provided for @nearbyTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Find nearest kiosk'**
  String get nearbyTileTitle;

  /// No description provided for @nearbyTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See active kiosks sorted by distance from you.'**
  String get nearbyTileSubtitle;

  /// No description provided for @activeSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Active print session'**
  String get activeSessionTitle;

  /// No description provided for @statusPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get statusPayNow;

  /// No description provided for @statusOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent'**
  String get statusOtpSent;

  /// No description provided for @statusPrinted.
  ///
  /// In en, this message translates to:
  /// **'Printed'**
  String get statusPrinted;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @findKiosk.
  ///
  /// In en, this message translates to:
  /// **'Find nearest kiosk'**
  String get findKiosk;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @validFor.
  ///
  /// In en, this message translates to:
  /// **'Valid for {time}'**
  String validFor(String time);

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'OTP expired'**
  String get otpExpired;

  /// No description provided for @expiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredLabel;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get loginWelcome;

  /// No description provided for @loginHelper.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your mobile number to upload documents and print at a kiosk.'**
  String get loginHelper;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a one-time code to {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @mobileHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile'**
  String get mobileHint;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @verifyContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get verifyContinue;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @citizenAccount.
  ///
  /// In en, this message translates to:
  /// **'Citizen account'**
  String get citizenAccount;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get languageHindi;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About Smart Kiosk'**
  String get about;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @uploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload documents'**
  String get uploadTitle;

  /// No description provided for @uploadHelper.
  ///
  /// In en, this message translates to:
  /// **'After upload, free sessions get an OTP by SMS. Extra pages require payment first, then the OTP is sent.'**
  String get uploadHelper;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get labelOptional;

  /// No description provided for @labelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. School certificates'**
  String get labelHint;

  /// No description provided for @tapToAddPdfs.
  ///
  /// In en, this message translates to:
  /// **'Tap to add PDF documents'**
  String get tapToAddPdfs;

  /// No description provided for @pdfsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} PDF(s) selected — tap to replace'**
  String pdfsSelected(int count);

  /// No description provided for @pdfOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'PDF only · page limits enforced by server'**
  String get pdfOnlyHint;

  /// No description provided for @printColor.
  ///
  /// In en, this message translates to:
  /// **'Print color'**
  String get printColor;

  /// No description provided for @colorBw.
  ///
  /// In en, this message translates to:
  /// **'Black & white'**
  String get colorBw;

  /// No description provided for @colorColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorColor;

  /// No description provided for @colorHelp.
  ///
  /// In en, this message translates to:
  /// **'Color prints use a higher extra-page rate set by the operator.'**
  String get colorHelp;

  /// No description provided for @bwHelp.
  ///
  /// In en, this message translates to:
  /// **'Black & white is the default and usually costs less per extra page.'**
  String get bwHelp;

  /// No description provided for @addPdfsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add one or more PDFs to continue.'**
  String get addPdfsToContinue;

  /// No description provided for @uploadContinue.
  ///
  /// In en, this message translates to:
  /// **'Upload & continue'**
  String get uploadContinue;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @payExtraPages.
  ///
  /// In en, this message translates to:
  /// **'Pay for extra pages'**
  String get payExtraPages;

  /// No description provided for @payHelper.
  ///
  /// In en, this message translates to:
  /// **'The first {count} page(s) are free. OTP is sent only after payment succeeds.'**
  String payHelper(int count);

  /// No description provided for @noPaymentDue.
  ///
  /// In en, this message translates to:
  /// **'No payment due.'**
  String get noPaymentDue;

  /// No description provided for @documentsReady.
  ///
  /// In en, this message translates to:
  /// **'Documents ready'**
  String get documentsReady;

  /// No description provided for @printColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Print color'**
  String get printColorLabel;

  /// No description provided for @totalPages.
  ///
  /// In en, this message translates to:
  /// **'Total pages'**
  String get totalPages;

  /// No description provided for @freePages.
  ///
  /// In en, this message translates to:
  /// **'Free pages'**
  String get freePages;

  /// No description provided for @extraPages.
  ///
  /// In en, this message translates to:
  /// **'Extra pages'**
  String get extraPages;

  /// No description provided for @chargePerPage.
  ///
  /// In en, this message translates to:
  /// **'Charge per extra page'**
  String get chargePerPage;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get amountDue;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get processing;

  /// No description provided for @otpSentTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP sent by SMS'**
  String get otpSentTitle;

  /// No description provided for @otpSentHelper.
  ///
  /// In en, this message translates to:
  /// **'Check your messages, then enter the OTP on the kiosk to preview and print.'**
  String get otpSentHelper;

  /// No description provided for @pagesColorFiles.
  ///
  /// In en, this message translates to:
  /// **'{pages} page(s) · {color} · {files} file(s)'**
  String pagesColorFiles(int pages, String color, int files);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @uploadMore.
  ///
  /// In en, this message translates to:
  /// **'Upload more documents'**
  String get uploadMore;

  /// No description provided for @noActiveSession.
  ///
  /// In en, this message translates to:
  /// **'No active print session.'**
  String get noActiveSession;

  /// No description provided for @noActiveSessionHelper.
  ///
  /// In en, this message translates to:
  /// **'Upload documents first to receive a print OTP.'**
  String get noActiveSessionHelper;

  /// No description provided for @uploadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload documents'**
  String get uploadDocuments;

  /// No description provided for @nearestKiosks.
  ///
  /// In en, this message translates to:
  /// **'Nearest kiosks'**
  String get nearestKiosks;

  /// No description provided for @nearestHelper.
  ///
  /// In en, this message translates to:
  /// **'Sorted by distance from your current location.'**
  String get nearestHelper;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @noKiosks.
  ///
  /// In en, this message translates to:
  /// **'No kiosks nearby right now.'**
  String get noKiosks;

  /// No description provided for @noKiosksHelper.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh, or try again when you are closer to a Smart Kiosk.'**
  String get noKiosksHelper;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to find nearby kiosks.'**
  String get locationRequired;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @kiosksOnMap.
  ///
  /// In en, this message translates to:
  /// **'{count} kiosk{suffix} on map'**
  String kiosksOnMap(int count, String suffix);

  /// No description provided for @noKiosksOnMap.
  ///
  /// In en, this message translates to:
  /// **'No kiosks to show on the map.'**
  String get noKiosksOnMap;

  /// No description provided for @couldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open Maps'**
  String get couldNotOpenMaps;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Print history'**
  String get historyTitle;

  /// No description provided for @historyHelper.
  ///
  /// In en, this message translates to:
  /// **'Your recent OTP print sessions.'**
  String get historyHelper;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No print sessions yet'**
  String get historyEmpty;

  /// No description provided for @historyEmptyHelper.
  ///
  /// In en, this message translates to:
  /// **'Upload a PDF to get a kiosk OTP. Your sessions will appear here.'**
  String get historyEmptyHelper;

  /// No description provided for @activeSection.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeSection;

  /// No description provided for @pastSection.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get pastSection;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Smart Kiosk'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Smart Kiosk Platform lets you upload documents on your phone, pay only for extra pages, and collect prints at a nearby kiosk with a one-time SMS code.\n\nYour OTP is sent to your mobile number and is never shown in this app.'**
  String get aboutBody;

  /// No description provided for @howItWorksIntro.
  ///
  /// In en, this message translates to:
  /// **'Three steps from your phone to a printed copy.'**
  String get howItWorksIntro;

  /// No description provided for @howItWorksStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Upload on your phone'**
  String get howItWorksStep1Title;

  /// No description provided for @howItWorksStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more PDFs, pick black & white or color, and add an optional label.'**
  String get howItWorksStep1Body;

  /// No description provided for @howItWorksStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Get an OTP by SMS'**
  String get howItWorksStep2Title;

  /// No description provided for @howItWorksStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Free pages are issued immediately. Extra pages are paid first, then the OTP is sent to your number.'**
  String get howItWorksStep2Body;

  /// No description provided for @howItWorksStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Print at a kiosk'**
  String get howItWorksStep3Title;

  /// No description provided for @howItWorksStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Find a nearby Smart Kiosk, enter the OTP on the screen, preview, and collect your prints.'**
  String get howItWorksStep3Body;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
