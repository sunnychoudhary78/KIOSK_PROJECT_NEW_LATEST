/// Shared PATCH payload for print-job status (Phase 1 API).
typedef PrintJobStatusReporter = Future<void> Function({
  required String jobId,
  required String status,
  String? errorMessage,
  int? pagesReported,
  String? spoolerJobId,
  int? pageCounterBefore,
  int? pageCounterAfter,
  String? reconcileStatus,
  String? reconcileDetail,
  bool? needsAdminReview,
});
