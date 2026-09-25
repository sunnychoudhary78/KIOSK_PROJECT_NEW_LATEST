class QuickPrintDocumentRef {
  const QuickPrintDocumentRef({
    required this.id,
    required this.fileName,
    required this.pageCount,
    required this.contentPath,
  });

  final String id;
  final String fileName;
  final int pageCount;
  final String contentPath;
}

class QuickPrintSession {
  const QuickPrintSession({
    required this.id,
    required this.status,
    required this.expiresAt,
    required this.publicUrl,
    this.deviceName,
    this.documentLabel = '',
    this.pageCount = 0,
  });

  final String id;
  final String status;
  final DateTime expiresAt;
  final String publicUrl;
  final String? deviceName;
  final String documentLabel;
  final int pageCount;

  bool get isReady => status == 'ready';
  bool get isTerminal =>
      status == 'expired' || status == 'cancelled' || status == 'consumed';
}

class QuickPrintClaim {
  const QuickPrintClaim({
    required this.sessionId,
    required this.printJobId,
    required this.title,
    required this.documents,
    this.printColorMode = 'bw',
  });

  final String sessionId;
  final String printJobId;
  final String title;
  final String printColorMode;
  final List<QuickPrintDocumentRef> documents;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'B/W';
}
