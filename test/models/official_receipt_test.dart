import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/services/document_service.dart';

/// Minimal `document_requests` row for official-receipt tests.
Map<String, dynamic> row() => <String, dynamic>{
      'id': 'req-1',
      'user_id': 'user-1',
      'document_type': 'barangay_clearance',
      'purpose': 'employment',
      'document_data': <String, dynamic>{},
      'request_status': 'for_approval',
      'payment_amount': 25,
      'payment_status': 'verified',
      'requested_at': '2026-10-10T08:30:00.000',
    };

/// Base row plus an `official_receipt_url` value.
Map<String, dynamic> rowWithReceipt(String url) =>
    row()..['official_receipt_url'] = url;

void main() {
  group('DocumentRequest.officialReceiptUrl', () {
    test('parses the treasurer-uploaded receipt URL', () {
      final request = DocumentRequest.fromJson(
        rowWithReceipt(
          'https://x.supabase.co/storage/v1/object/public/payment-receipts/'
          'req-1/official_1760000000000.jpg',
        ),
      );
      expect(request.officialReceiptUrl, isNotNull);
      expect(request.officialReceiptUrl, contains('req-1/official_'));
    });

    test('is null when the row has no official receipt (pre-migration safe)',
        () {
      // Old rows and rows confirmed before this feature exist without the
      // key entirely; parsing must not throw.
      expect(DocumentRequest.fromJson(row()).officialReceiptUrl, isNull);
      expect(
        DocumentRequest.fromJson(row()..['official_receipt_url'] = null)
            .officialReceiptUrl,
        isNull,
      );
    });

    test('survives a toJson round-trip (payment fields are not dropped)',
        () {
      // Guards against the known §13.6 gap shape: toJson silently dropping
      // payment fields newer than the original implementation.
      final request = DocumentRequest.fromJson(
        rowWithReceipt('https://x.example/receipt.png'),
      );
      expect(request.toJson()['official_receipt_url'],
          request.officialReceiptUrl);
      expect(request.toJson()['payment_receipt_url'], request.paymentReceiptUrl);
    });
  });

  group('DocumentService.officialReceiptPath', () {
    test('is request-scoped with the official_ prefix and file extension', () {
      final path = DocumentService.officialReceiptPath('req-1', 'jpg');
      expect(path, startsWith('req-1/official_'));
      expect(path, endsWith('.jpg'));
      // Distinct from the citizen's user-scoped GCash screenshot path
      // (<user_id>/receipt_<ts>.<ext>).
      expect(path, isNot(contains('/receipt_')));
    });
  });
}
