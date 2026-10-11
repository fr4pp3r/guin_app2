import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/barangay_config.dart';
import 'package:guin_app/models/user_profile.dart';

/// Minimal `users_profile` row (pre-KYC columns only).
Map<String, dynamic> legacyRow() => <String, dynamic>{
  'id': 'user-1',
  'username': 'juan',
  'email': 'juan@example.com',
  'full_name': 'Juan Dela Cruz',
  'address': '123 Barangay Street',
  'age': 30,
  'date_of_birth': '1990-05-04',
  'place_of_birth': 'Manila',
  'civil_status': 'single',
  'gender': 'male',
  'phone_number': '09171234567',
  'profile_photo_url': null,
  'valid_id_url': 'https://example.test/valid-ids/valid_id_1.jpg',
  'is_approved': false,
  'registration_status': 'pending',
  'rejection_reason': null,
  'role': 'citizen',
  'created_at': '2026-10-10T08:30:00.000',
  'updated_at': '2026-10-10T08:30:00.000',
};

/// Row after AI pre-check (advisory) — never auto-approves.
Map<String, dynamic> aiCheckedRow() => <String, dynamic>{
  ...legacyRow(),
  'kyc_method': null,
  'kyc_ai_result': <String, dynamic>{
    'id_authenticity': 'authentic',
    'id_type_guess': 'drivers_license',
    'id_type_match': true,
    'selfie_quality': 'good',
    'liveness': <String, dynamic>{
      'spoof_signal': 'live_looking',
      'notes': 'Blink challenge passed',
    },
    'field_checks': <String, dynamic>{
      'full_name': 'match',
      'date_of_birth': 'match',
      'address': 'match',
      'gender': 'match',
    },
    'recommendation': 'looks_ok',
    'reasons': ['ID appears authentic', 'Selfie quality good', 'Liveness signal live'],
    'prompt_version': 'v5',
  },
  'is_indigent': false,
  'indigency_reason': null,
  'kyc_id_type': 'drivers_license',
  'kyc_id_number': 'N17-12-345678',
  'id_issued_at': '2020-03-15',
  'id_expiry_at': '2030-03-15',
  'liveness_verified': true,
  'liveness_verified_at': '2026-10-10T08:31:00.000',
  'kyc_verified_at': null,
  'kyc_reviewed_by': null,
  'kyc_rejection_reason': null,
  'is_approved': false,
  'registration_status': 'pending',
};

/// Row after manual approval (non-indigent).
Map<String, dynamic> manualApprovedRow() => <String, dynamic>{
  ...aiCheckedRow(),
  'kyc_method': 'manual_verified',
  'kyc_verified_at': '2026-10-10T09:00:00.000',
  'kyc_reviewed_by': 'captain-1',
  'is_approved': true,
  'registration_status': 'approved',
};

/// Row after guarantor-backed approval (indigent path).
Map<String, dynamic> guarantorApprovedRow() => <String, dynamic>{
  ...legacyRow(),
  'kyc_method': 'guarantor_verified',
  'kyc_ai_result': <String, dynamic>{
    'id_authenticity': 'authentic',
    'id_type_guess': 'national_id',
    'id_type_match': true,
    'selfie_quality': 'good',
    'liveness': <String, dynamic>{
      'spoof_signal': 'live_looking',
      'notes': 'Head turn challenge passed',
    },
    'field_checks': <String, dynamic>{
      'full_name': 'match',
      'date_of_birth': 'match',
      'address': 'match',
      'gender': 'match',
    },
    'recommendation': 'looks_ok',
    'reasons': ['Guarantor ID verified', 'Liveness signal live'],
    'prompt_version': 'v5',
  },
  'is_indigent': true,
  'indigency_reason': 'Senior citizen, no valid ID issued',
  'kyc_id_type': null,
  'kyc_id_number': null,
  'id_issued_at': null,
  'id_expiry_at': null,
  'liveness_verified': true,
  'liveness_verified_at': '2026-10-10T08:31:00.000',
  'kyc_verified_at': '2026-10-10T09:00:00.000',
  'kyc_reviewed_by': 'captain-1',
  'kyc_rejection_reason': null,
  'is_approved': true,
  'registration_status': 'approved',
};

void main() {
  group('UserProfile KYC round-trip (new design)', () {
    test('parses every KYC column from an AI-checked registration', () {
      final profile = UserProfile.fromJson(aiCheckedRow());

      expect(profile.kycMethod, isNull);
      expect(profile.kycAiResult, <String, dynamic>{
        'id_authenticity': 'authentic',
        'id_type_guess': 'drivers_license',
        'id_type_match': true,
        'selfie_quality': 'good',
        'liveness': <String, dynamic>{
          'spoof_signal': 'live_looking',
          'notes': 'Blink challenge passed',
        },
        'field_checks': <String, dynamic>{
          'full_name': 'match',
          'date_of_birth': 'match',
          'address': 'match',
          'gender': 'match',
        },
        'recommendation': 'looks_ok',
        'reasons': ['ID appears authentic', 'Selfie quality good', 'Liveness signal live'],
        'prompt_version': 'v5',
      });
      expect(profile.isIndigent, isFalse);
      expect(profile.indigencyReason, isNull);
      expect(profile.kycIdType, 'drivers_license');
      expect(profile.kycIdNumber, 'N17-12-345678');
      expect(profile.idIssuedAt, DateTime.parse('2020-03-15'));
      expect(profile.idExpiryAt, DateTime.parse('2030-03-15'));
      expect(profile.livenessVerified, isTrue);
      expect(profile.livenessVerifiedAt, DateTime.parse('2026-10-10T08:31:00.000'));
      expect(profile.kycVerifiedAt, isNull);
      expect(profile.kycReviewedBy, isNull);
      expect(profile.kycRejectionReason, isNull);
      expect(profile.isKycVerified, isFalse);
      expect(profile.isApproved, isFalse);
      expect(profile.registrationStatus, 'pending');
      expect(profile.hasOwnId, isTrue);
    });

    test('toJson writes the KYC columns back verbatim', () {
      final json = UserProfile.fromJson(aiCheckedRow()).toJson();

      expect(json['kyc_method'], isNull);
      expect(json['kyc_ai_result'], <String, dynamic>{
        'id_authenticity': 'authentic',
        'id_type_guess': 'drivers_license',
        'id_type_match': true,
        'selfie_quality': 'good',
        'liveness': <String, dynamic>{
          'spoof_signal': 'live_looking',
          'notes': 'Blink challenge passed',
        },
        'field_checks': <String, dynamic>{
          'full_name': 'match',
          'date_of_birth': 'match',
          'address': 'match',
          'gender': 'match',
        },
        'recommendation': 'looks_ok',
        'reasons': ['ID appears authentic', 'Selfie quality good', 'Liveness signal live'],
        'prompt_version': 'v5',
      });
      expect(json['is_indigent'], isFalse);
      expect(json['indigency_reason'], isNull);
      expect(json['kyc_id_type'], 'drivers_license');
      expect(json['kyc_id_number'], 'N17-12-345678');
      expect(json['id_issued_at'], '2020-03-15');
      expect(json['id_expiry_at'], '2030-03-15');
      expect(json['liveness_verified'], isTrue);
      expect(json['liveness_verified_at'], '2026-10-10T08:31:00.000');
      expect(json['kyc_verified_at'], isNull);
      expect(json['kyc_reviewed_by'], isNull);
      expect(json['kyc_rejection_reason'], isNull);
    });

    test('fromJson(toJson()) is stable', () {
      final first = UserProfile.fromJson(aiCheckedRow()).toJson();
      final second = UserProfile.fromJson(first).toJson();

      expect(second, first);
    });

    test('rows without the KYC columns parse safely', () {
      final profile = UserProfile.fromJson(legacyRow());

      expect(profile.kycMethod, isNull);
      expect(profile.kycAiResult, isNull);
      expect(profile.isIndigent, isFalse);
      expect(profile.indigencyReason, isNull);
      expect(profile.kycIdType, isNull);
      expect(profile.kycIdNumber, isNull);
      expect(profile.idIssuedAt, isNull);
      expect(profile.idExpiryAt, isNull);
      expect(profile.livenessVerified, isFalse);
      expect(profile.livenessVerifiedAt, isNull);
      expect(profile.kycVerifiedAt, isNull);
      expect(profile.kycReviewedBy, isNull);
      expect(profile.kycRejectionReason, isNull);
      expect(profile.isKycVerified, isFalse);
      expect(profile.isApproved, isFalse);
      expect(profile.registrationStatus, 'pending');
      expect(profile.hasOwnId, isFalse);
    });

    test('an indigent registration (no own ID) round-trips', () {
      final row = <String, dynamic>{
        ...legacyRow(),
        'kyc_method': 'indigent_bypass',
        'is_indigent': true,
        'indigency_reason': 'Senior citizen, no valid ID issued yet',
        'registration_status': 'pending',
      };

      final profile = UserProfile.fromJson(row);
      final json = profile.toJson();

      expect(json['kyc_method'], 'indigent_bypass');
      expect(json['is_indigent'], isTrue);
      expect(
        json['indigency_reason'],
        'Senior citizen, no valid ID issued yet',
      );
      expect(json['kyc_id_type'], isNull);
      expect(json['kyc_id_number'], isNull);
      expect(json['kyc_verified_at'], isNull);
      expect(profile.hasOwnId, isFalse);
    });

    test('a guarantor-backed approval round-trips', () {
      final profile = UserProfile.fromJson(guarantorApprovedRow());

      expect(profile.kycMethod, 'guarantor_verified');
      expect(profile.isIndigent, isTrue);
      expect(profile.indigencyReason, 'Senior citizen, no valid ID issued');
      expect(profile.kycIdType, isNull);
      expect(profile.kycIdNumber, isNull);
      expect(profile.hasOwnId, isFalse);
      expect(profile.isKycVerified, isTrue);
      expect(profile.isApproved, isTrue);
      expect(profile.registrationStatus, 'approved');
    });

    test('a manual approval round-trips', () {
      final profile = UserProfile.fromJson(manualApprovedRow());

      expect(profile.kycMethod, 'manual_verified');
      expect(profile.isIndigent, isFalse);
      expect(profile.kycIdType, 'drivers_license');
      expect(profile.hasOwnId, isTrue);
      expect(profile.isKycVerified, isTrue);
      expect(profile.isApproved, isTrue);
      expect(profile.registrationStatus, 'approved');
    });

    test('a jsonb result handed back as a plain Map is normalized', () {
      final row = <String, dynamic>{
        ...aiCheckedRow(),
        'kyc_ai_result': <dynamic, dynamic>{'recommendation': 'needs_review'},
      };

      final profile = UserProfile.fromJson(row);

      expect(profile.kycAiResult, <String, dynamic>{
        'recommendation': 'needs_review',
      });
    });

    test('an unusable liveness_verified_at value parses as null', () {
      final row = <String, dynamic>{...aiCheckedRow(), 'liveness_verified_at': 'soon'};

      expect(UserProfile.fromJson(row).livenessVerifiedAt, isNull);
    });

    test('copyWith updates the KYC fields only when passed', () {
      final profile = UserProfile.fromJson(aiCheckedRow());
      final reviewed = profile.copyWith(
        kycMethod: 'manual_verified',
        kycReviewedBy: 'captain-1',
        kycVerifiedAt: DateTime.parse('2026-10-10T09:00:00.000'),
        isApproved: true,
        registrationStatus: 'approved',
      );

      expect(reviewed.kycMethod, 'manual_verified');
      expect(reviewed.kycReviewedBy, 'captain-1');
      expect(reviewed.kycVerifiedAt, DateTime.parse('2026-10-10T09:00:00.000'));
      expect(reviewed.isApproved, isTrue);
      expect(reviewed.registrationStatus, 'approved');
      // Untouched fields are preserved.
      expect(reviewed.kycAiResult, profile.kycAiResult);
      expect(reviewed.isIndigent, profile.isIndigent);
      expect(reviewed.kycIdType, profile.kycIdType);
      expect(reviewed.livenessVerified, profile.livenessVerified);

      final indigent = profile.copyWith(isIndigent: true);
      expect(indigent.isIndigent, isTrue);
      expect(indigent.kycMethod, profile.kycMethod);
    });

    test('copyWith cannot clear a KYC field back to null via ??', () {
      final profile = UserProfile.fromJson(aiCheckedRow());

      // Same ?? semantics as every other field in this model.
      expect(profile.copyWith(kycMethod: null).kycMethod, isNull);
      expect(
        profile.copyWith(kycAiResult: null).kycAiResult,
        profile.kycAiResult,
      );
      expect(profile.copyWith(kycIdType: null).kycIdType, 'drivers_license');
      expect(profile.copyWith(kycIdNumber: null).kycIdNumber, 'N17-12-345678');
    });
  });

  group('BarangayConfig (no sample ID fields)', () {
    Map<String, dynamic> configRow() => <String, dynamic>{
      'id': 'config-1',
      'gcash_name': 'Juan Dela Cruz',
      'gcash_number': '09171234567',
      'barangay_name': 'Barangay Guinestangan',
      'barangay_address': 'Barangay Hall, Guinestangan',
      'barangay_captain': 'Juan Dela Cruz',
      'contact_number': '09171234568',
      'email': 'brgy@example.test',
      'logo_url': 'https://example.test/logo.png',
      'created_at': '2026-10-10T08:00:00.000',
      'updated_at': '2026-10-10T08:00:00.000',
    };

    test('round-trips without sample Barangay ID fields', () {
      final config = BarangayConfig.fromJson(configRow());

      expect(config.gcashName, 'Juan Dela Cruz');
      expect(config.barangayName, 'Barangay Guinestangan');
      expect(config.logoUrl, 'https://example.test/logo.png');
      expect(
        BarangayConfig.fromJson(config.toJson()).gcashName,
        'Juan Dela Cruz',
      );
    });

    test('copyWith works on all fields', () {
      final config = BarangayConfig.fromJson(configRow());
      final updated = config.copyWith(
        gcashName: 'Someone Else',
        gcashNumber: '09178888888',
        barangayCaptain: 'New Captain',
      );

      expect(updated.gcashName, 'Someone Else');
      expect(updated.gcashNumber, '09178888888');
      expect(updated.barangayCaptain, 'New Captain');
      expect(updated.barangayName, config.barangayName);
    });
  });

  group('KycIdTypes enum', () {
    test('values list matches the canonical 11 types', () {
      expect(KycIdTypes.values, [
        'barangay_id',
        'drivers_license',
        'passport',
        'national_id',
        'umid',
        'prc',
        'sss',
        'philhealth',
        'postal_id',
        'voters_id',
        'other',
      ]);
    });

    test('labels are defined for every value', () {
      for (final v in KycIdTypes.values) {
        expect(KycIdTypes.labels.containsKey(v), isTrue,
            reason: 'Missing label for $v');
        expect(KycIdTypes.labels[v]!.isNotEmpty, isTrue);
      }
    });

    test('isValid rejects unknown and accepts canonical', () {
      expect(KycIdTypes.isValid('drivers_license'), isTrue);
      expect(KycIdTypes.isValid('national_id'), isTrue);
      expect(KycIdTypes.isValid('not_a_real_id'), isFalse);
      expect(KycIdTypes.isValid(null), isFalse);
      expect(KycIdTypes.isValid(''), isFalse);
    });

    test('label falls back to raw value for unknown', () {
      expect(KycIdTypes.label('drivers_license'), "Driver's License");
      expect(KycIdTypes.label('national_id'), 'National ID');
      expect(KycIdTypes.label('unknown_type'), 'unknown_type');
      expect(KycIdTypes.label(null), 'Not provided');
    });
  });
}