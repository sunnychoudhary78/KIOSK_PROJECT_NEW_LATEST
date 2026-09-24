class OtpDocumentRef {
  const OtpDocumentRef({
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

class OtpRedeemResult {
  const OtpRedeemResult({
    required this.challengeId,
    required this.printJobId,
    required this.title,
    required this.documents,
    this.payloadUrl,
    this.printColorMode = 'bw',
  });

  final String challengeId;
  final String printJobId;
  final String title;
  final String? payloadUrl;
  final String printColorMode;
  final List<OtpDocumentRef> documents;

  String get printColorLabel => printColorMode == 'color' ? 'Color' : 'B/W';
}
