import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/document_request.dart';

/// Minimal `document_requests` row for status-predicate tests.
Map<String, dynamic> row(String status) => <String, dynamic>{
  'id': 'req-1',
  'user_id': 'user-1',
  'document_type': 'barangay_clearance',
  'purpose': 'employment',
  'document_data': <String, dynamic>{},
  'request_status': status,
  'payment_amount': 0,
  'payment_status': 'pending',
  'requested_at': '2026-10-10T08:30:00.000',
};

void main() {
  group('DocumentRequest status predicates', () {
    test('isApprovedOrReleased counts completed documents', () {
      // The live captain flow ends at `released`, so a plain `isApproved`
      // check would report 0 approved documents for finished requests.
      expect(DocumentRequest.fromJson(row('released')).isApprovedOrReleased,
          isTrue);
      expect(DocumentRequest.fromJson(row('approved')).isApprovedOrReleased,
          isTrue);
      expect(
          DocumentRequest.fromJson(row('approved_for_release'))
              .isApprovedOrReleased,
          isTrue);

      for (final status in ['submitted', 'for_approval', 'rejected']) {
        expect(DocumentRequest.fromJson(row(status)).isApprovedOrReleased,
            isFalse,
            reason: '$status is not approved');
      }
    });

    test('isInProgress covers every non-terminal pipeline status', () {
      final inProgress = [
        DocStatus.submitted,
        DocStatus.draftGenerated,
        DocStatus.needsRevision,
        DocStatus.verifiedForPayment,
        DocStatus.invoiced,
        DocStatus.paymentSubmitted,
        DocStatus.paymentRejected,
        DocStatus.paymentConfirmed,
        DocStatus.forApproval,
        DocStatus.approvedForRelease,
      ];
      for (final status in inProgress) {
        expect(DocumentRequest.fromJson(row(status)).isInProgress, isTrue,
            reason: '$status should be pending');
      }

      for (final status in [
        DocStatus.released,
        DocStatus.rejected,
        DocStatus.cancelled,
      ]) {
        expect(DocumentRequest.fromJson(row(status)).isInProgress, isFalse,
            reason: '$status is terminal');
      }
    });
  });
}
