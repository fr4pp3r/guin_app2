/// Profile-backed `document_data` for the citizen document request form, so a
/// citizen only picks a type and writes the purpose.
library;

import 'package:guin_app/models/user_profile.dart';

/// The subset of `document_data` the profile already answers, keyed exactly as
/// `request_document_screen.dart` writes it and `DocumentDataValidator` reads
/// it. Keys with no profile source (cedula height/weight/TIN/occupation/annual
/// income, indigency requester for someone else) are deliberately absent — the
/// request form keeps those as optional extras.
Map<String, dynamic> profileDocumentData(
  UserProfile profile,
  String documentType,
) {
  switch (documentType) {
    case 'barangay_id':
      return {
        'full_name': profile.fullName,
        'address': profile.address,
        'contact_number': profile.phoneNumber,
      };
    case 'oath_undertaking':
    case 'indigency':
    case 'good_moral':
      return {
        'full_name': profile.fullName,
        'address': profile.address,
        'age': profile.age.toString(),
        'civil_status': profile.civilStatus,
        // The requester defaults to the account holder; still editable for
        // someone requesting on another person's behalf.
        'requester': profile.fullName,
        'requester_address': profile.address,
      };
    case 'business_clearance':
    case 'certification':
    case 'barangay_clearance':
    case 'residency':
    case 'cedula':
      return {
        'last_name': profile.lastName,
        'first_name': profile.givenName,
        'middle_name': profile.middleName,
        'address': profile.address,
        'gender': profile.gender,
        'civil_status': profile.civilStatus,
        'birth_place': profile.placeOfBirth,
        'birth_date': profile.dateOfBirth.toIso8601String(),
        'citizenship': 'Filipino',
      };
    default:
      return {};
  }
}
