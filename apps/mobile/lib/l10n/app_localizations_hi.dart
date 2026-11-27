// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'IMT-Print';

  @override
  String get brandName => 'ATHENAA';

  @override
  String get guestSubtitle =>
      'दस्तावेज़ अपलोड करें, एसएमएस पर प्रिंट ओटीपी पाएँ, और किसी भी IMT-Print कियोस्क से प्रिंट लें।';

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
  String get findServicesTileTitle => 'सेवाएँ खोजें';

  @override
  String get findServicesTileSubtitle =>
      'मैकेनिक, दर्ज़ी, प्लंबर और अन्य स्थानीय सेवाएँ।';

  @override
  String get findServicesTitle => 'सेवाएँ खोजें';

  @override
  String get findServicesHelper =>
      'नाम और फ़ोन नंबर देखने के लिए कोई सेवा चुनें।';

  @override
  String get findServicesEmpty => 'कोई सेवा उपलब्ध नहीं';

  @override
  String get findServicesEmptyHelper =>
      'रिफ़्रेश करें, या बाद में फिर कोशिश करें।';

  @override
  String get findServicesContactsHelper =>
      'पहले पिन · फिर ऊँची रेटिंग। फ़ोन के लिए टैप करें।';

  @override
  String get findServicesNoContacts => 'इस सूची में कोई नंबर नहीं है।';

  @override
  String findServicesContactCount(int count) {
    return '$count संपर्क';
  }

  @override
  String get findServicesMoreInfo => 'और जानकारी';

  @override
  String get findServicesContactHint =>
      'इस व्यक्ति से संपर्क करने के लिए आप सीधे कॉल कर सकते हैं।';

  @override
  String get findServicesCall => 'कॉल करें';

  @override
  String get couldNotPlaceCall => 'कॉल नहीं हो सकी।';

  @override
  String get fuelStationsTileTitle => 'ईंधन स्टेशन';

  @override
  String get fuelStationsTileSubtitle =>
      'आपके पास पेट्रोल, डीज़ल, सीएनजी और ईवी स्टेशन।';

  @override
  String get fuelStationsTitle => 'ईंधन स्टेशन';

  @override
  String get fuelStationsHelper => '5 किमी के अंदर स्टेशन, दूरी के अनुसार।';

  @override
  String get fuelStationsEmpty => 'आसपास कोई स्टेशन नहीं';

  @override
  String get fuelStationsEmptyHelper =>
      'दूसरा फ़िल्टर आज़माएँ, या स्टेशन के करीब जाएँ।';

  @override
  String get fuelKindAll => 'सभी';

  @override
  String get fuelKindPetrolDiesel => 'पेट्रोल/डीज़ल';

  @override
  String get fuelKindCng => 'सीएनजी';

  @override
  String get fuelKindEv => 'ईवी';

  @override
  String get astrologyPanditTileTitle => 'पंडित से संपर्क';

  @override
  String get astrologyPanditTileSubtitle =>
      'नाम, रेटिंग और फ़ोन — जब पंडित जी की ज़रूरत हो।';

  @override
  String get astrologyAstrologerTileTitle => 'ज्योतिषी से संपर्क';

  @override
  String get astrologyAstrologerTileSubtitle =>
      'ज्योतिष सलाह के लिए नाम, रेटिंग और फ़ोन।';

  @override
  String get astrologyNumerologyTileTitle => 'अंक ज्योतिष से संपर्क';

  @override
  String get astrologyNumerologyTileSubtitle =>
      'अंक ज्योतिष सलाह के लिए नाम, रेटिंग और फ़ोन।';

  @override
  String get astrologyPanditTitle => 'पंडित से संपर्क';

  @override
  String get astrologyAstrologerTitle => 'ज्योतिषी से संपर्क';

  @override
  String get astrologyNumerologyTitle => 'अंक ज्योतिष से संपर्क';

  @override
  String get astrologyPanditHelper => 'फ़ोन देखने के लिए Show number टैप करें।';

  @override
  String get astrologyAstrologerHelper =>
      'फ़ोन देखने के लिए Show number टैप करें।';

  @override
  String get astrologyNumerologyHelper =>
      'फ़ोन देखने के लिए Show number टैप करें।';

  @override
  String get astrologyShowNumber => 'नंबर दिखाएँ';

  @override
  String get astrologyContactHint =>
      'इस व्यक्ति से संपर्क करने के लिए आप सीधे कॉल कर सकते हैं।';

  @override
  String get astrologyContactsEmpty => 'अभी कोई संपर्क उपलब्ध नहीं है।';

  @override
  String get astrologyComingSoon => 'जल्द आ रहा है';

  @override
  String get astrologyComingSoonHelper =>
      'एडमिन पैनल से पंडित जोड़ने के बाद यहाँ संपर्क दिखेंगे।';

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
  String get about => 'IMT-Print के बारे में';

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
  String get tapToAddPdfs => 'पीडीएफ, JPG/PNG या Word (.docx) जोड़ें';

  @override
  String pdfsSelected(int count) {
    return '$count फ़ाइल चुनी गईं — बदलने के लिए टैप करें';
  }

  @override
  String get pdfOnlyHint =>
      'पीडीएफ, JPG/PNG या Word (.docx) · पेज सीमा सर्वर तय करता है';

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
  String get kioskFreeDisabledNow =>
      'इस कियोस्क पर अभी मुफ़्त पन्ने उपलब्ध नहीं हैं। अतिरिक्त पन्नों का शुल्क सामान्य रहेगा।';

  @override
  String kioskPrintPricing(int free, int charge, int max) {
    return 'प्रति विज़िट अधिकतम $free मुफ़्त पन्ने (फ़ोन कोटा के भीतर), फिर प्रत्येक ₹$charge। अधिकतम $max पन्ने।';
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
    return 'यह भुगतान कियोस्क पर छपने वाले अतिरिक्त पन्नों के लिए है। पहले $count पन्ने मुफ़्त हैं। भुगतान सफल होने के बाद ही ओटीपी भेजा जाता है।';
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
      'रीफ़्रेश करें, या किसी IMT-Print कियोस्क के पास आने पर फिर कोशिश करें।';

  @override
  String get locationRequired =>
      'नज़दीकी कियोस्क खोजने के लिए लोकेशन अनुमति चाहिए।';

  @override
  String get locationServicesOff =>
      'लोकेशन सेवाएँ बंद हैं। नज़दीकी कियोस्क खोजने के लिए उन्हें चालू करें।';

  @override
  String get openSettings => 'सेटिंग खोलें';

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
  String get aboutTitle => 'IMT-Print के बारे में';

  @override
  String get aboutBody =>
      'IMT-Print से आप फ़ोन पर दस्तावेज़ अपलोड कर सकते हैं, केवल अतिरिक्त पन्नों का भुगतान कर सकते हैं, और नज़दीकी कियोस्क पर एसएमएस कोड से प्रिंट ले सकते हैं।\n\nआपका ओटीपी आपके मोबाइल नंबर पर जाता है और इस ऐप में नहीं दिखता।';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get couldNotOpenPrivacyPolicy => 'गोपनीयता नीति नहीं खुल सकी।';

  @override
  String get deleteAccount => 'खाता हटाएँ';

  @override
  String get deleteAccountTitle => 'अपना खाता हटाएँ?';

  @override
  String get deleteAccountBody =>
      'अपलोड की गई पीडीएफ और प्रिंट इतिहास हटा दिए जाएँगे। भुगतान रिकॉर्ड आपके फ़ोन नंबर के बिना रखे जाते हैं। इसे वापस नहीं किया जा सकता।';

  @override
  String get deleteAccountConfirm => 'खाता हटाएँ';

  @override
  String get deleteAccountFailed => 'खाता नहीं हट सका। फिर कोशिश करें।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get selectedPaymentApp => 'चुने गए ऐप';

  @override
  String finishInWallet(String wallet) {
    return 'भुगतान $wallet में पूरा करें, फिर इस ऐप पर लौटें।';
  }

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
      'नज़दीकी IMT-Print कियोस्क खोजें, स्क्रीन पर ओटीपी दर्ज करें, पूर्वावलोकन करें और प्रिंट लें।';

  @override
  String get sessionExpired => 'सत्र समाप्त हो गया। कृपया फिर साइन इन करें।';
}
