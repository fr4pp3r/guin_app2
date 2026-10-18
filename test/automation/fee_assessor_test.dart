import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/automation/fee_assessor.dart';

void main() {
  group('FeeAssessor.assess', () {
    test('fee 0 => paymentRequired is false', () {
      final result = FeeAssessor.assess(
        documentType: 'barangay_clearance',
        feesByType: const {'barangay_clearance': 0.0},
      );
      expect(result.paymentRequired, isFalse);
      expect(result.feeAmount, 0.0);
      expect(result.isValid, isTrue);
    });

    test('fee > 0 => paymentRequired is true', () {
      final result = FeeAssessor.assess(
        documentType: 'barangay_clearance',
        feesByType: const {'barangay_clearance': 50.0},
      );
      expect(result.paymentRequired, isTrue);
      expect(result.feeAmount, 50.0);
    });
  });
}