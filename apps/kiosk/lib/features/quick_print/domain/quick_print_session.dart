class QuickPrintDocumentRef {
  const QuickPrintDocumentRef({
    required this.id,
    required this.fileName,
    required this.pageCount,
    required this.contentPath,
    this.printJobId,
    this.printed = false,
  });

  final String id;
  final String fileName;
  final int pageCount;
  final String contentPath;
  final String? printJobId;
  final bool printed;

  QuickPrintDocumentRef copyWith({
    String? printJobId,
    bool? printed,
  }) {
    return QuickPrintDocumentRef(
      id: id,
      fileName: fileName,
      pageCount: pageCount,
      contentPath: contentPath,
      printJobId: printJobId ?? this.printJobId,
      printed: printed ?? this.printed,
    );
  }
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
    required this.title,
    required this.documents,
    this.printColorMode = 'bw',
  });

  final String sessionId;
  final String title;
  final String printColorMode;
  final List<QuickPrintDocumentRef> documents;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'B/W';

  bool get hasUnprinted => documents.any((d) => !d.printed);

  QuickPrintClaim withDocumentPrinted(String documentId, {String? printJobId}) {
    return QuickPrintClaim(
      sessionId: sessionId,
      title: title,
      printColorMode: printColorMode,
      documents: [
        for (final doc in documents)
          if (doc.id == documentId)
            doc.copyWith(printed: true, printJobId: printJobId ?? doc.printJobId)
          else
            doc,
      ],
    );
  }
}
