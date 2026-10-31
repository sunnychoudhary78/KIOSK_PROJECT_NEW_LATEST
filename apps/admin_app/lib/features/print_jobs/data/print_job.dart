class PrintJob {
  const PrintJob({
    required this.id,
    required this.status,
    required this.source,
    required this.title,
    required this.createdAt,
    required this.pagesExpected,
    required this.reconcileStatus,
    required this.needsAdminReview,
    this.printColorMode,
    this.deviceId,
    this.pagesReported,
  });

  final String id;
  final String status;
  final String source;
  final String title;
  final String? printColorMode;
  final String? deviceId;
  final DateTime createdAt;
  final int pagesExpected;
  final int? pagesReported;
  final String reconcileStatus;
  final bool needsAdminReview;

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      printColorMode: json['printColorMode'] as String?,
      deviceId: json['deviceId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      pagesExpected: json['pagesExpected'] is num ? (json['pagesExpected'] as num).toInt() : 0,
      pagesReported: json['pagesReported'] is num ? (json['pagesReported'] as num).toInt() : null,
      reconcileStatus: json['reconcileStatus'] as String? ?? '',
      needsAdminReview: json['needsAdminReview'] == true,
    );
  }
}
