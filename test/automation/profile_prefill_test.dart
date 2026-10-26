import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/automation/document_data_validator.dart';
import 'package:guin_app/automation/profile_prefill.dart';
import 'package:guin_app/models/user_profile.dart';

UserProfile _profile() => UserProfile(
      id: 'u1',
      username: 'juan',
      email: 'juan@example.com',
      givenName: 'Juan',
      middleName: 'Santos',
      lastName: 'Dela Cruz',
      address: 'Purok 2, Barangay Guin',
      age: 34,
      dateOfBirth: DateTime(1992, 5, 17),
      placeOfBirth: 'Guin, Albay',
      civilStatus: 'Married',
      gender: 'Male',
      phoneNumber: '09171234567',
      isApproved: true,
      registrationStatus: 'approved',
      role: 'citizen',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('profileDocumentData', () {
    test('satisfies DocumentDataValidator for every supported type', () {
      for (final type in DocumentDataValidator.supportedTypes) {
        final data = {
          ...profileDocumentData(_profile(), type),
          'purpose': 'Valid purpose for the request',
        };
        final result = DocumentDataValidator.validate(
          documentType: type,
          purpose: data['purpose'] as String,
          documentData: data,
        );
        expect(result.errors, isEmpty, reason: '$type: ${result.summary}');
      }
    });

    test('maps profile values onto the exact keys the form writes', () {
      final cedula = profileDocumentData(_profile(), 'cedula');
      expect(cedula['first_name'], 'Juan');
      expect(cedula['middle_name'], 'Santos');
      expect(cedula['last_name'], 'Dela Cruz');
      expect(DateTime.parse(cedula['birth_date'] as String),
          DateTime(1992, 5, 17));
      expect(cedula['citizenship'], 'Filipino');

      final barangayId = profileDocumentData(_profile(), 'barangay_id');
      expect(barangayId['contact_number'], '09171234567');

      final indigency = profileDocumentData(_profile(), 'indigency');
      expect(indigency['age'], '34');
      expect(indigency['requester'], 'Juan Santos Dela Cruz');
    });

    test('returns nothing for an unknown type', () {
      expect(profileDocumentData(_profile(), 'letter_of_intent'), isEmpty);
    });
  });
}
