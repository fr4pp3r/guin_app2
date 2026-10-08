/// Pure rules for issuing printable copies of released documents.
library;

class PrintCopyRules {
  static const int maxCopiesPerDocument = 5;

  static bool canIssueMore(int existingCount) =>
      existingCount < maxCopiesPerDocument;

  static int nextCopyNumber(int existingCount) => existingCount + 1;

  static String serialFor(String documentId, int copyNumber) =>
      '$documentId-C${copyNumber.toString().padLeft(2, '0')}';

  static String noticeFor({
    required int copyNumber,
    required String issuedTo,
    required DateTime issuedAt,
  }) {
    final month = issuedAt.month.toString().padLeft(2, '0');
    final day = issuedAt.day.toString().padLeft(2, '0');
    final date = '${issuedAt.year}-$month-$day';
    return 'Printable copy #$copyNumber issued to $issuedTo on $date. '
        'Verify by scanning the QR code.';
  }
}
