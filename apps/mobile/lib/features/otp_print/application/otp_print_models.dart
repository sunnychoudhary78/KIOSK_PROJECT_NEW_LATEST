class PrintQuote {
  const PrintQuote({
    required this.printColorMode,
    required this.pageCount,
    required this.freePages,
    required this.extraPages,
    required this.chargePerPageRupees,
    required this.amountPaise,
    required this.currency,
    required this.paymentRequired,
  });

  final String printColorMode;
  final int pageCount;
  final int freePages;
  final int extraPages;
  final int chargePerPageRupees;
  final int amountPaise;
  final String currency;
  final bool paymentRequired;

  double get amountRupees => amountPaise / 100;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'Black & white';

  factory PrintQuote.fromJson(Map<String, dynamic> json) {
    return PrintQuote(
      printColorMode: _asPrintColorMode(json['printColorMode']),
      pageCount: _asInt(json['pageCount']),
      freePages: _asInt(json['freePages']),
      extraPages: _asInt(json['extraPages']),
      chargePerPageRupees: _asInt(json['chargePerPageRupees']),
      amountPaise: _asInt(json['amountPaise']),
      currency: json['currency'] as String? ?? 'INR',
      paymentRequired: json['paymentRequired'] as bool? ?? false,
    );
  }
}

class OtpDocumentInfo {
  const OtpDocumentInfo({
    required this.id,
    required this.fileName,
    required this.pageCount,
    required this.byteSize,
  });

  final String id;
  final String fileName;
  final int pageCount;
  final int byteSize;

  factory OtpDocumentInfo.fromJson(Map<String, dynamic> json) {
    return OtpDocumentInfo(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      pageCount: _asInt(json['pageCount'], 1),
      byteSize: _asInt(json['byteSize']),
    );
  }
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.status,
    required this.paymentRequired,
    required this.otpSent,
    required this.expiresAt,
    required this.documentLabel,
    required this.pageCount,
    required this.printColorMode,
    required this.documents,
    this.quote,
  });

  final String id;
  final String status;
  final bool paymentRequired;
  final bool otpSent;
  final String expiresAt;
  final String documentLabel;
  final int pageCount;
  final String printColorMode;
  final List<OtpDocumentInfo> documents;
  final PrintQuote? quote;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'Black & white';

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] as List<dynamic>? ?? [])
        .map((raw) => OtpDocumentInfo.fromJson(raw as Map<String, dynamic>))
        .toList();
    final quoteRaw = json['quote'];
    return OtpChallenge(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      paymentRequired: json['paymentRequired'] as bool? ?? false,
      otpSent: json['otpSent'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String,
      documentLabel: json['documentLabel'] as String? ?? '',
      pageCount: _asInt(json['pageCount'], 1),
      printColorMode: _asPrintColorMode(json['printColorMode']),
      documents: docs,
      quote: quoteRaw is Map<String, dynamic> ? PrintQuote.fromJson(quoteRaw) : null,
    );
  }
}

class RazorpayOrder {
  const RazorpayOrder({
    required this.alreadyPaid,
    required this.otpSent,
    required this.keyId,
    required this.amountPaise,
    required this.currency,
    this.orderId,
  });

  final bool alreadyPaid;
  final bool otpSent;
  final String keyId;
  final int amountPaise;
  final String currency;
  final String? orderId;

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>? ?? const {};
    return RazorpayOrder(
      alreadyPaid: json['alreadyPaid'] as bool? ?? false,
      otpSent: json['otpSent'] as bool? ?? false,
      keyId: json['razorpay_key_id'] as String? ?? '',
      amountPaise: _asInt(payment['amountPaise']),
      currency: payment['currency'] as String? ?? 'INR',
      orderId: json['razorpay_order_id'] as String?,
    );
  }
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

String _asPrintColorMode(dynamic value) => value == 'color' ? 'color' : 'bw';
