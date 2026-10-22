enum PrintReconcileOutcome {
  verified,
  reconciliationRequired,
  unknown,
  failed,
  busy,
}

class PrintReconcileResult {
  const PrintReconcileResult({
    required this.outcome,
    required this.userMessage,
    this.pagesReported,
    this.pageCounterBefore,
    this.pageCounterAfter,
    this.reconcileDetail,
  });

  final PrintReconcileOutcome outcome;
  final String userMessage;
  final int? pagesReported;
  final int? pageCounterBefore;
  final int? pageCounterAfter;
  final String? reconcileDetail;

  bool get isSuccess => outcome == PrintReconcileOutcome.verified;

  /// Soft success for UX: print was accepted but not physically confirmed.
  bool get isUncertain =>
      outcome == PrintReconcileOutcome.reconciliationRequired ||
      outcome == PrintReconcileOutcome.unknown;
}
