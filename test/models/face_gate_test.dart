import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/face_gate.dart';
import 'package:guin_app/services/face_gate_service.dart';

/// Offline tests for the face-gate client: pure parsing + name normalization.
/// No Supabase init, no detector — the service's network paths are exercised
/// only against the deployed `face-match` function.
void main() {
  group('FaceGateResult.fromJson', () {
    test('parses a match response', () {
      final result = FaceGateResult.fromJson(<String, dynamic>{
        'ok': true,
        'matched': true,
        'score': 0.87,
        'enrollmentId': 'e1',
      });

      expect(result.matched, isTrue);
      expect(result.score, 0.87);
      expect(result.reason, isNull);
      expect(result.enrollmentId, 'e1');
    });

    test('parses a not_enrolled response', () {
      final result = FaceGateResult.fromJson(<String, dynamic>{
        'ok': true,
        'matched': false,
        'score': 0,
        'reason': 'not_enrolled',
      });

      expect(result.matched, isFalse);
      expect(result.score, 0.0);
      expect(result.reason, 'not_enrolled');
      expect(result.enrollmentId, isNull);
    });

    test('missing score falls back to 0.0 and matched to false', () {
      final result = FaceGateResult.fromJson(<String, dynamic>{});

      expect(result.matched, isFalse);
      expect(result.score, 0.0);
      expect(result.reason, isNull);
      expect(result.enrollmentId, isNull);
    });
  });

  group('FaceEnrollment.fromJson', () {
    test('parses a list row with a photoUrl', () {
      final enrollment = FaceEnrollment.fromJson(<String, dynamic>{
        'id': 'enr-1',
        'fullName': 'Juan dela Cruz',
        'dob': '1990-05-04',
        'createdAt': '2026-11-24T08:30:00.000Z',
        'photoUrl': 'https://example.test/signed/photo.png',
      });

      expect(enrollment.id, 'enr-1');
      expect(enrollment.fullName, 'Juan dela Cruz');
      expect(enrollment.dob, '1990-05-04');
      expect(enrollment.createdAt, '2026-11-24T08:30:00.000Z');
      expect(enrollment.photoUrl, 'https://example.test/signed/photo.png');
    });

    test('parses a list row with a null photoUrl', () {
      final enrollment = FaceEnrollment.fromJson(<String, dynamic>{
        'id': 'enr-2',
        'fullName': 'Juana dela Cruz',
        'dob': '1992-01-15',
        'createdAt': '2026-11-24T09:00:00.000Z',
        'photoUrl': null,
      });

      expect(enrollment.id, 'enr-2');
      expect(enrollment.fullName, 'Juana dela Cruz');
      expect(enrollment.dob, '1992-01-15');
      expect(enrollment.createdAt, '2026-11-24T09:00:00.000Z');
      expect(enrollment.photoUrl, isNull);
    });
  });

  group('FaceGateService.normalizeName', () {
    test('trims, lowercases and joins all three parts', () {
      expect(
        FaceGateService.normalizeName(' Juan ', ' de la ', 'CRUZ '),
        'juan de la cruz',
      );
    });

    test('drops empty parts instead of leaving double spaces', () {
      expect(FaceGateService.normalizeName('Juan', '', 'Cruz'), 'juan cruz');
    });
  });
}
