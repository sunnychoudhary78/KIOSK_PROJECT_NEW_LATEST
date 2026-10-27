Map<String, dynamic> printStatusBody({
  required String status,
  String? errorMessage,
  int? pagesReported,
  String? spoolerJobId,
  int? pageCounterBefore,
  int? pageCounterAfter,
  String? reconcileStatus,
  String? reconcileDetail,
  bool? needsAdminReview,
  bool? holdForRetry,
}) {
  return {
    'status': status,
    'errorMessage': ?errorMessage,
    'pagesReported': ?pagesReported,
    'spoolerJobId': ?spoolerJobId,
    'pageCounterBefore': ?pageCounterBefore,
    'pageCounterAfter': ?pageCounterAfter,
    'reconcileStatus': ?reconcileStatus,
    'reconcileDetail': ?reconcileDetail,
    'needsAdminReview': ?needsAdminReview,
    'holdForRetry': ?holdForRetry,
  };
}
