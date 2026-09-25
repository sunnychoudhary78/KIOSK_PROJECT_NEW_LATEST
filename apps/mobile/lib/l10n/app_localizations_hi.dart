// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'स्मार्ट कियोस्क मोबाइल';

  @override
  String get brandName => 'स्मार्ट कियोस्क';

  @override
  String get guestSubtitle =>
      'दस्तावेज़ अपलोड करें, एसएमएस पर प्रिंट ओटीपी पाएँ, और किसी भी स्मार्ट कियोस्क से प्रिंट लें।';

  @override
  String get signInCta => 'मोबाइल ओटीपी से साइन इन करें';

  @override
  String get tabHome => 'होम';

  @override
  String get tabHistory => 'इतिहास';

  @override
  String get tabNearby => 'नज़दीक';

  @override
  String get tabProfile => 'प्रोफ़ाइल';

  @override
  String get stepUpload => 'अपलोड';

  @override
  String get stepOtpSms => 'ओटीपी एसएमएस';

  @override
  String get stepPrint => 'प्रिंट';

  @override
  String get howItWorksTitle => 'यह कैसे काम करता है';

  @override
  String get homeHeadline => 'कियोस्क पर प्रिंट करें';

  @override
  String get homeHelper =>
      'फ़ोन पर पीडीएफ अपलोड करें, एसएमएस पर ओटीपी पाएँ, फिर कियोस्क पर दर्ज करें।';

  @override
  String get greetingReady => 'प्रिंट के लिए तैयार';

  @override
  String signedInAs(String phone) {
    return 'साइन इन · $phone';
  }

  @override
  String get uploadTileTitle => 'अपलोड करें और प्रिंट ओटीपी पाएँ';

  @override
  String get uploadTileSubtitle =>
      'दस्तावेज़ चुनें और कियोस्क ओटीपी एसएमएस पर पाएँ।';

  @override
  String get nearbyTileTitle => 'नज़दीकी कियोस्क खोजें';

  @override
  String get nearbyTileSubtitle => 'आपसे दूरी के अनुसार सक्रिय कियोस्क देखें।';

  @override
  String get activeSessionTitle => 'सक्रिय प्रिंट सत्र';

  @override
  String get statusPayNow => 'अभी भुगतान करें';

  @override
  String get statusOtpSent => 'ओटीपी भेजा गया';

  @override
  String get statusPrinted => 'प्रिंट हो गया';

  @override
  String get statusExpired => 'समाप्त';

  @override
  String get statusCancelled => 'रद्द';

  @override
  String get statusReady => 'तैयार';

  @override
  String get resendOtp => 'ओटीपी फिर भेजें';

  @override
  String get findKiosk => 'नज़दीकी कियोस्क खोजें';

  @override
  String get pay => 'भुगतान करें';

  @override
  String validFor(String time) {
    return '$time तक मान्य';
  }

  @override
  String get otpExpired => 'ओटीपी समाप्त हो गया';

  @override
  String get expiredLabel => 'समाप्त';

  @override
  String get loginWelcome => 'स्वागत है';

  @override
  String get loginHelper =>
      'दस्तावेज़ अपलोड करने और कियोस्क पर प्रिंट करने के लिए अपने मोबाइल नंबर से साइन इन करें।';

  @override
  String get enterOtp => 'ओटीपी दर्ज करें';

  @override
  String otpSentTo(String phone) {
    return 'हमने $phone पर एक बार का कोड भेजा है';
  }

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get mobileHint => '10 अंकों का मोबाइल';

  @override
  String get sendOtp => 'ओटीपी भेजें';

  @override
  String get verifyContinue => 'सत्यापित करें और आगे बढ़ें';

  @override
  String get changeNumber => 'नंबर बदलें';

  @override
  String resendIn(int seconds) {
    return '$seconds सेकंड में फिर भेजें';
  }

  @override
  String stepOf(int current, int total) {
    return 'चरण $current / $total';
  }

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get citizenAccount => 'नागरिक खाता';

  @override
  String get language => 'भाषा';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get howItWorks => 'यह कैसे काम करता है';

  @override
  String get about => 'स्मार्ट कियोस्क के बारे में';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get chooseLanguage => 'भाषा चुनें';

  @override
  String get uploadTitle => 'दस्तावेज़ अपलोड करें';

  @override
  String get uploadHelper =>
      'अपलोड के बाद मुफ़्त सत्रों पर एसएमएस से ओटीपी मिलता है। अतिरिक्त पन्नों का भुगतान पहले होता है, फिर ओटीपी भेजा जाता है।';

  @override
  String get labelOptional => 'लेबल (वैकल्पिक)';

  @override
  String get labelHint => 'जैसे स्कूल प्रमाणपत्र';

  @override
  String get tapToAddPdfs => 'पीडीएफ जोड़ने के लिए टैप करें';

  @override
  String pdfsSelected(int count) {
    return '$count पीडीएफ चुने गए — बदलने के लिए टैप करें';
  }

  @override
  String get pdfOnlyHint => 'केवल पीडीएफ · पेज सीमा सर्वर तय करता है';

  @override
  String get printColor => 'प्रिंट रंग';

  @override
  String get colorBw => 'काले और सफेद';

  @override
  String get colorColor => 'रंगीन';

  @override
  String get colorHelp => 'रंगीन प्रिंट पर अतिरिक्त पेज की दर अधिक होती है।';

  @override
  String get bwHelp => 'काले-सफेद डिफ़ॉल्ट है और आमतौर पर सस्ता पड़ता है।';

  @override
  String get selectKiosk => 'प्रिंट कियोस्क';

  @override
  String get chooseKioskToContinue => 'जिस कियोस्क पर प्रिंट लेंगे, उसे चुनें';

  @override
  String kioskPrintPricing(int free, int charge, int max) {
    return 'पहले $free पन्ने मुफ़्त, फिर प्रत्येक ₹$charge। अधिकतम $max पन्ने।';
  }

  @override
  String printOnlyAtKiosk(String name) {
    return 'केवल $name पर प्रिंट करें';
  }

  @override
  String get addPdfsToContinue => 'आगे बढ़ने के लिए एक या अधिक पीडीएफ जोड़ें।';

  @override
  String get uploadContinue => 'अपलोड करें और आगे बढ़ें';

  @override
  String get uploading => 'अपलोड हो रहा है…';

  @override
  String get payExtraPages => 'अतिरिक्त पन्नों का भुगतान';

  @override
  String payHelper(int count) {
    return 'पहले $count पन्ने मुफ़्त हैं। भुगतान सफल होने के बाद ही ओटीपी भेजा जाता है।';
  }

  @override
  String get noPaymentDue => 'कोई भुगतान नहीं है।';

  @override
  String get documentsReady => 'दस्तावेज़ तैयार';

  @override
  String get printColorLabel => 'प्रिंट रंग';

  @override
  String get totalPages => 'कुल पन्ने';

  @override
  String get freePages => 'मुफ़्त पन्ने';

  @override
  String get extraPages => 'अतिरिक्त पन्ने';

  @override
  String get chargePerPage => 'प्रति अतिरिक्त पन्ना शुल्क';

  @override
  String get amountDue => 'देय राशि';

  @override
  String payAmount(String amount) {
    return '$amount भुगतान करें';
  }

  @override
  String get processing => 'प्रोसेस हो रहा है…';

  @override
  String get otpSentTitle => 'ओटीपी एसएमएस से भेजा गया';

  @override
  String get otpSentHelper =>
      'अपने संदेश देखें, फिर चुने हुए कियोस्क पर ओटीपी दर्ज करके प्रिंट लें।';

  @override
  String pagesColorFiles(int pages, String color, int files) {
    return '$pages पन्ना · $color · $files फ़ाइल';
  }

  @override
  String get done => 'हो गया';

  @override
  String get uploadMore => 'और दस्तावेज़ अपलोड करें';

  @override
  String get noActiveSession => 'कोई सक्रिय प्रिंट सत्र नहीं है।';

  @override
  String get noActiveSessionHelper =>
      'प्रिंट ओटीपी पाने के लिए पहले दस्तावेज़ अपलोड करें।';

  @override
  String get uploadDocuments => 'दस्तावेज़ अपलोड करें';

  @override
  String get nearestKiosks => 'नज़दीकी कियोस्क';

  @override
  String get nearestHelper => 'आपकी वर्तमान लोकेशन से दूरी के अनुसार क्रमबद्ध।';

  @override
  String get viewOnMap => 'मानचित्र पर देखें';

  @override
  String get noKiosks => 'अभी आसपास कोई कियोस्क नहीं है।';

  @override
  String get noKiosksHelper =>
      'रीफ़्रेश करें, या किसी स्मार्ट कियोस्क के पास आने पर फिर कोशिश करें।';

  @override
  String get locationRequired =>
      'नज़दीकी कियोस्क खोजने के लिए लोकेशन अनुमति चाहिए।';

  @override
  String get directions => 'दिशा';

  @override
  String get refresh => 'रीफ़्रेश';

  @override
  String get retry => 'फिर कोशिश करें';

  @override
  String get tryAgain => 'फिर कोशिश करें';

  @override
  String kiosksOnMap(int count, String suffix) {
    return 'मानचित्र पर $count कियोस्क$suffix';
  }

  @override
  String get noKiosksOnMap => 'मानचित्र पर दिखाने के लिए कोई कियोस्क नहीं है।';

  @override
  String get couldNotOpenMaps => 'मानचित्र नहीं खुल सका';

  @override
  String get historyTitle => 'प्रिंट इतिहास';

  @override
  String get historyHelper => 'आपके हाल के ओटीपी प्रिंट सत्र।';

  @override
  String get historyEmpty => 'अभी कोई प्रिंट सत्र नहीं';

  @override
  String get historyEmptyHelper =>
      'कियोस्क ओटीपी पाने के लिए पीडीएफ अपलोड करें। सत्र यहाँ दिखेंगे।';

  @override
  String get activeSection => 'सक्रिय';

  @override
  String get pastSection => 'पहले के';

  @override
  String get aboutTitle => 'स्मार्ट कियोस्क के बारे में';

  @override
  String get aboutBody =>
      'स्मार्ट कियोस्क प्लेटफ़ॉर्म से आप फ़ोन पर दस्तावेज़ अपलोड कर सकते हैं, केवल अतिरिक्त पन्नों का भुगतान कर सकते हैं, और नज़दीकी कियोस्क पर एसएमएस कोड से प्रिंट ले सकते हैं।\n\nआपका ओटीपी आपके मोबाइल नंबर पर जाता है और इस ऐप में नहीं दिखता।';

  @override
  String get howItWorksIntro => 'फ़ोन से प्रिंट तक तीन चरण।';

  @override
  String get howItWorksStep1Title => 'फ़ोन पर अपलोड करें';

  @override
  String get howItWorksStep1Body =>
      'एक या अधिक पीडीएफ चुनें, काले-सफेद या रंगीन चुनें, और चाहें तो लेबल जोड़ें।';

  @override
  String get howItWorksStep2Title => 'एसएमएस पर ओटीपी पाएँ';

  @override
  String get howItWorksStep2Body =>
      'मुफ़्त पन्ने तुरंत जारी होते हैं। अतिरिक्त पन्नों का भुगतान पहले होता है, फिर ओटीपी आपके नंबर पर जाता है।';

  @override
  String get howItWorksStep3Title => 'कियोस्क पर प्रिंट करें';

  @override
  String get howItWorksStep3Body =>
      'नज़दीकी स्मार्ट कियोस्क खोजें, स्क्रीन पर ओटीपी दर्ज करें, पूर्वावलोकन करें और प्रिंट लें।';

  @override
  String get sessionExpired => 'सत्र समाप्त हो गया। कृपया फिर साइन इन करें।';
}
