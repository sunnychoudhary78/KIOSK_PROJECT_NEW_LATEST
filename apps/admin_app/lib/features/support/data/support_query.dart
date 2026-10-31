class SupportQuery {
  const SupportQuery({
    required this.id,
    required this.status,
    required this.message,
    required this.phone,
    required this.amountPaise,
    required this.createdAt,
    this.razorpayOrderId,
    this.failureReason,
    this.paymentReference,
    this.paymentStatus,
    this.challengeId,
    this.kioskName,
    this.printJobId,
    this.printJobStatus,
    this.pagesExpected,
    this.pagesReported,
    this.printJobError,
    this.source,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String status;
  final String message;
  final String phone;
  final int amountPaise;
  final String? razorpayOrderId;
  final String? failureReason;
  final String? paymentReference;
  final String? paymentStatus;
  final String? challengeId;
  final String? kioskName;
  final String? printJobId;
  final String? printJobStatus;
  final int? pagesExpected;
  final int? pagesReported;
  final String? printJobError;
  final String? source;
  final String? resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get canResendOtp =>
      source != 'print' && paymentStatus == 'PAID' && (challengeId?.isNotEmpty ?? false);

  factory SupportQuery.fromJson(Map<String, dynamic> json) {
    return SupportQuery(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      amountPaise: json['amountPaise'] is num ? (json['amountPaise'] as num).toInt() : 0,
      razorpayOrderId: json['razorpayOrderId'] as String?,
      failureReason: json['failureReason'] as String?,
      paymentReference: json['paymentReference'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      challengeId: json['challengeId'] as String?,
      kioskName: json['kioskName'] as String?,
      printJobId: json['printJobId'] as String?,
      printJobStatus: json['printJobStatus'] as String?,
      pagesExpected: json['pagesExpected'] is num ? (json['pagesExpected'] as num).toInt() : null,
      pagesReported: json['pagesReported'] is num ? (json['pagesReported'] as num).toInt() : null,
      printJobError: json['printJobError'] as String?,
      source: json['source'] as String?,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: DateTime.tryParse(json['resolvedAt'] as String? ?? ''),
    );
  }
}

class SupportList {
  const SupportList({required this.items, required this.openCount});

  final List<SupportQuery> items;
  final int openCount;
}
