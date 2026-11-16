class OtpDocumentRef {
  const OtpDocumentRef({
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

  OtpDocumentRef copyWith({
    String? printJobId,
    bool? printed,
  }) {
    return OtpDocumentRef(
      id: id,
      fileName: fileName,
      pageCount: pageCount,
      contentPath: contentPath,
      printJobId: printJobId ?? this.printJobId,
      printed: printed ?? this.printed,
    );
  }
}

class OtpRedeemResult {
  const OtpRedeemResult({
    required this.challengeId,
    required this.title,
    required this.documents,
    this.printColorMode = 'bw',
  });

  final String challengeId;
  final String title;
  final String printColorMode;
  final List<OtpDocumentRef> documents;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'B/W';

  bool get hasUnprinted => documents.any((d) => !d.printed);

  OtpRedeemResult withDocumentPrinted(String documentId, {String? printJobId}) {
    return OtpRedeemResult(
      challengeId: challengeId,
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
