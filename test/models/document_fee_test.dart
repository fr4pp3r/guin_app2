import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/document_fee.dart';

Map<String, dynamic> _json(String id, double fee, {bool? isFree}) => {
      'id': id,
      'document_type': 'barangay_clearance',
      'fee_amount': fee,
      'is_free': isFree,
      'created_at': '2026-10-01T00:00:00.000Z',
      'updated_at': '2026-10-01T00:00:00.000Z',
    };

void main() {
  test('fromJson: is_free true wins even with nonzero fee_amount', () {
    final fee = DocumentFee.fromJson(_json('a', 50.0, isFree: true));
    expect(fee.isFree, isTrue);
  });

  test('fromJson: missing is_free + fee 0 => free', () {
    final fee = DocumentFee.fromJson(_json('b', 0.0));
    expect(fee.isFree, isTrue);
  });

  test('fromJson: missing is_free + fee 50 => not free', () {
    final fee = DocumentFee.fromJson(_json('c', 50.0));
    expect(fee.isFree, isFalse);
  });

  test('toJson round-trips is_free', () {
    final fee = DocumentFee.fromJson(_json('d', 0.0, isFree: true));
    expect(fee.toJson()['is_free'], isTrue);
    final roundTrip = DocumentFee.fromJson(fee.toJson());
    expect(roundTrip.isFree, isTrue);
  });
}
