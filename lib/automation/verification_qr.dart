/// Parses the QR payload printed inside a released barangay document.
/// The QR encodes a URL like:
///   https://barangay-guion.app/verify/BRGY-GUION-2026-000123?token=<64hex>
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
      final segments = uri.pathSegments;
      final verifyIndex = segments.indexOf('verify');
      if (verifyIndex == -1 || verifyIndex >= segments.length - 1) {
        return null; // URL that is not a verification URL
      }
      final documentId = segments[verifyIndex + 1];
      if (documentId.isEmpty) return null;
      final token = uri.queryParameters['token'];
      return VerificationQr(
        documentId: documentId,
        token: (token == null || token.isEmpty) ? null : token,
      );
    }

    // Bare document id (manual entry)
    return VerificationQr(documentId: value);
  }
}
