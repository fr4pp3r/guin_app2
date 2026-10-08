/// Parses the QR payload printed inside a released barangay document.
/// The QR encodes a URL like:
///   https://barangay-guion.app/verify-document/BRGY-GUION-2026-000123?token=<64hex>
/// but a bare document id is also accepted for manual entry.
library;

class VerificationQr {
  final String documentId;
  final String? token;
  const VerificationQr({required this.documentId, this.token});
}

class VerificationQrParser {
  /// Returns null when [raw] is empty or an unrecognisable URL.
  static VerificationQr? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    final looksLikeUrl = value.contains('://') || value.startsWith('http');

    if (uri != null && looksLikeUrl) {
      // Support query-param format: ?documentId=...&token=...
      final queryDocumentId = uri.queryParameters['documentId'];
      if (queryDocumentId != null && queryDocumentId.isNotEmpty) {
        final token = uri.queryParameters['token'];
        return VerificationQr(
          documentId: queryDocumentId,
          token: (token == null || token.isEmpty) ? null : token,
        );
      }
      // Support path format: /verify-document/:documentId?token=...
      final segments = uri.pathSegments;
      final verifyDocIndex = segments.indexOf('verify-document');
      if (verifyDocIndex != -1 && verifyDocIndex < segments.length - 1) {
        final documentId = segments[verifyDocIndex + 1];
        if (documentId.isNotEmpty) {
          final token = uri.queryParameters['token'];
          return VerificationQr(
            documentId: documentId,
            token: (token == null || token.isEmpty) ? null : token,
          );
        }
      }
      return null; // URL that is not a verification URL
    }

    // Bare document id (manual entry)
    return VerificationQr(documentId: value);
  }
}
