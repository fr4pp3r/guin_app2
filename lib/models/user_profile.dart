import 'package:guin_app/utils/role_access.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String givenName;
  final String middleName;
  final String lastName;
  final String address;
  final int age;
  final DateTime dateOfBirth;
  final String placeOfBirth;
  final String civilStatus;
  final String gender;
  final String phoneNumber;
  final String? profilePhotoUrl;
  final String? validIdUrl;
  final String? validIdBackUrl;
  // KYC / registration verification -----------------------------------------
  /// How identity was settled: 'ai_verified', 'manual_verified',
  /// 'indigent_bypass', or 'guarantor_verified' (an indigent registrant vouched
  /// for by an approved citizen). Always null at registration — no
  /// registration auto-approves; an officer stamps this on approval.
  final String? kycMethod;

  /// Which government ID the registrant presented (see `KycIdTypes.values`)
  /// and its number. Both stay null on the indigent/guarantor path, where the
  /// guarantor's ID is recorded on `kyc_guarantors` instead.
  final String? kycIdType;
  final String? kycIdNumber;

  /// Issue/expiry dates printed on the presented ID.
  final DateTime? idIssuedAt;
  final DateTime? idExpiryAt;

  /// True once the registrant cleared the liveness selfie step. The selfie is
  /// only an anti-spoof signal — it never approves a registration by itself.
  final bool livenessVerified;
  final DateTime? livenessVerifiedAt;

  /// PII-safe subset of the `id-verifier` verdict
  /// (see `IdVerificationSuggestion.toStoredJson`); never holds OCR text.
  /// Advisory only — a reviewer still has to look at the ID.
  final Map<String, dynamic>? kycAiResult;

  /// On-device 1:1 face match (registration selfie vs. ID portrait), as a
  /// cosine similarity in [-1, 1]. Null means "not evaluated" (unsupported
  /// platform, no usable face, or any detector error); it is advisory only —
  /// it never gates approval.
  final double? kycFaceMatchScore;
  final DateTime? kycFaceMatchAt;
  final bool isIndigent;
  final String? indigencyReason;

  final DateTime? kycVerifiedAt;
  final String? kycReviewedBy;
  final String? kycRejectionReason;
  final bool isApproved;
  // Poblacion residency: null = unverified, true = confirmed resident,
  // false = confirmed not a resident. Nullable so AI "unverifiable" verdicts
  // leave the user in a self-service retry state instead of permanently
  // blocking them.
  final bool? isPoblacionResident;
  final String registrationStatus; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final String role; // 'admin', 'citizen'
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Computed full name from the three parts (for backward compatibility).
  String get fullName =>
      [givenName, if (middleName.isNotEmpty) middleName, lastName].join(' ');

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.givenName,
    required this.middleName,
    required this.lastName,
    required this.address,
    required this.age,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.civilStatus,
    required this.gender,
    required this.phoneNumber,
    this.profilePhotoUrl,
    this.validIdUrl,
    this.validIdBackUrl,
    this.kycMethod,
    this.kycIdType,
    this.kycIdNumber,
    this.idIssuedAt,
    this.idExpiryAt,
    this.livenessVerified = false,
    this.livenessVerifiedAt,
    this.kycAiResult,
    this.kycFaceMatchScore,
    this.kycFaceMatchAt,
    this.isIndigent = false,
    this.indigencyReason,
    this.kycVerifiedAt,
    this.kycReviewedBy,
    this.kycRejectionReason,
    required this.isApproved,
    this.isPoblacionResident,
    required this.registrationStatus,
    this.rejectionReason,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Support both new columns (given_name, middle_name, last_name) and legacy full_name.
    final given = json['given_name'] as String?;
    final middle = json['middle_name'] as String?;
    final last = json['last_name'] as String?;
    final legacyFull = json['full_name'] as String?;

    String givenName, middleName, lastName;
    if (given != null && last != null) {
      givenName = given;
      middleName = middle ?? '';
      lastName = last;
    } else if (legacyFull != null && legacyFull.isNotEmpty) {
      // Fallback: split legacy full_name into parts.
      final parts = legacyFull.trim().split(' ');
      if (parts.length >= 2) {
        givenName = parts.first;
        middleName = parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : '';
        lastName = parts.last;
      } else {
        givenName = legacyFull;
        middleName = '';
        lastName = '';
      }
    } else {
      // Should not happen for valid rows, but keep non-null.
      givenName = '';
      middleName = '';
      lastName = '';
    }

    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      givenName: givenName,
      middleName: middleName,
      lastName: lastName,
      address: json['address'] as String,
      age: json['age'] as int,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      placeOfBirth: json['place_of_birth'] as String,
      civilStatus: json['civil_status'] as String,
      gender: json['gender'] as String,
      phoneNumber: json['phone_number'] as String,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      validIdUrl: json['valid_id_url'] as String?,
      validIdBackUrl: json['valid_id_back_url'] as String?,
      kycMethod: json['kyc_method'] as String?,
      kycIdType: json['kyc_id_type'] as String?,
      kycIdNumber: json['kyc_id_number'] as String?,
      idIssuedAt: _timestampFromDynamic(json['id_issued_at']),
      idExpiryAt: _timestampFromDynamic(json['id_expiry_at']),
      livenessVerified: json['liveness_verified'] as bool? ?? false,
      livenessVerifiedAt: _timestampFromDynamic(json['liveness_verified_at']),
      kycAiResult: _mapFromDynamic(json['kyc_ai_result']),
      kycFaceMatchScore:
          json['kyc_face_match_score'] is num
              ? (json['kyc_face_match_score'] as num).toDouble()
              : null,
      kycFaceMatchAt: _timestampFromDynamic(json['kyc_face_match_at']),
      isIndigent: json['is_indigent'] as bool? ?? false,
      indigencyReason: json['indigency_reason'] as String?,
      kycVerifiedAt: _timestampFromDynamic(json['kyc_verified_at']),
      kycReviewedBy: json['kyc_reviewed_by'] as String?,
      kycRejectionReason: json['kyc_rejection_reason'] as String?,
      isApproved: json['is_approved'] as bool,
      isPoblacionResident: json['is_poblacion_resident'] as bool?,
      registrationStatus: json['registration_status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'given_name': givenName,
      'middle_name': middleName.isEmpty ? null : middleName,
      'last_name': lastName,
      'full_name': fullName, // Kept for backward compatibility / read paths
      'address': address,
      'age': age,
      'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      'place_of_birth': placeOfBirth,
      'civil_status': civilStatus,
      'gender': gender,
      'phone_number': phoneNumber,
      'profile_photo_url': profilePhotoUrl,
      'valid_id_url': validIdUrl,
      'valid_id_back_url': validIdBackUrl,
      'kyc_method': kycMethod,
      'kyc_id_type': kycIdType,
      'kyc_id_number': kycIdNumber,
      'id_issued_at': idIssuedAt?.toIso8601String().split('T')[0],
      'id_expiry_at': idExpiryAt?.toIso8601String().split('T')[0],
      'liveness_verified': livenessVerified,
      'liveness_verified_at': livenessVerifiedAt?.toIso8601String(),
      'kyc_ai_result': kycAiResult,
      'kyc_face_match_score': kycFaceMatchScore,
      'kyc_face_match_at': kycFaceMatchAt?.toIso8601String(),
      'is_indigent': isIndigent,
      'indigency_reason': indigencyReason,
      'kyc_verified_at': kycVerifiedAt?.toIso8601String(),
      'kyc_reviewed_by': kycReviewedBy,
      'kyc_rejection_reason': kycRejectionReason,
      'is_approved': isApproved,
      'is_poblacion_resident': isPoblacionResident,
      'registration_status': registrationStatus,
      'rejection_reason': rejectionReason,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? givenName,
    String? middleName,
    String? lastName,
    String? address,
    int? age,
    DateTime? dateOfBirth,
    String? placeOfBirth,
    String? civilStatus,
    String? gender,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? validIdUrl,
    String? validIdBackUrl,
    String? kycMethod,
    String? kycIdType,
    String? kycIdNumber,
    DateTime? idIssuedAt,
    DateTime? idExpiryAt,
    bool? livenessVerified,
    DateTime? livenessVerifiedAt,
    Map<String, dynamic>? kycAiResult,
    double? kycFaceMatchScore,
    DateTime? kycFaceMatchAt,
    bool? isIndigent,
    String? indigencyReason,
    DateTime? kycVerifiedAt,
    String? kycReviewedBy,
    String? kycRejectionReason,
    bool? isApproved,
    bool? isPoblacionResident,
    String? registrationStatus,
    String? rejectionReason,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      givenName: givenName ?? this.givenName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      civilStatus: civilStatus ?? this.civilStatus,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      validIdUrl: validIdUrl ?? this.validIdUrl,
      validIdBackUrl: validIdBackUrl ?? this.validIdBackUrl,
      kycMethod: kycMethod ?? this.kycMethod,
      kycIdType: kycIdType ?? this.kycIdType,
      kycIdNumber: kycIdNumber ?? this.kycIdNumber,
      idIssuedAt: idIssuedAt ?? this.idIssuedAt,
      idExpiryAt: idExpiryAt ?? this.idExpiryAt,
      livenessVerified: livenessVerified ?? this.livenessVerified,
      livenessVerifiedAt: livenessVerifiedAt ?? this.livenessVerifiedAt,
      kycAiResult: kycAiResult ?? this.kycAiResult,
      kycFaceMatchScore: kycFaceMatchScore ?? this.kycFaceMatchScore,
      kycFaceMatchAt: kycFaceMatchAt ?? this.kycFaceMatchAt,
      isIndigent: isIndigent ?? this.isIndigent,
      indigencyReason: indigencyReason ?? this.indigencyReason,
      kycVerifiedAt: kycVerifiedAt ?? this.kycVerifiedAt,
      kycReviewedBy: kycReviewedBy ?? this.kycReviewedBy,
      kycRejectionReason: kycRejectionReason ?? this.kycRejectionReason,
      isApproved: isApproved ?? this.isApproved,
      isPoblacionResident: isPoblacionResident ?? this.isPoblacionResident,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => registrationStatus == 'pending';
  bool get isRejected => registrationStatus == 'rejected';
  bool get isKycVerified => kycVerifiedAt != null;

  /// True once an officer or the AI lane has committed this user to being a
  /// Poblacion resident. Null (unverified) and false both return false here —
  /// only an explicit `true` opens the document-request gate.
  bool get isResidentConfirmed => isPoblacionResident == true;

  /// True when the registrant presented an ID of their own (the indigent /
  /// guarantor path leaves `kycIdType` null).
  bool get hasOwnId => kycIdType != null && (kycIdNumber ?? '').isNotEmpty;
  bool get isAdmin => AppRoles.isOfficial(role);
  bool get isCaptain =>
      role == AppRoles.captain || role == AppRoles.legacyAdmin;
  bool get isSecretary => role == AppRoles.secretary;
  bool get isTreasurer => role == AppRoles.treasurer;
  bool get isKagawadRepresentative => role == AppRoles.kagawadRepresentative;
  bool get isBarangayTanod => role == AppRoles.barangayTanod;
  bool get isCitizen => role == 'citizen';
}

/// Every government ID type accepted at registration, in the order the
/// registration form lists them. Frozen: these are the exact strings stored in
/// `users_profile.kyc_id_type` / `kyc_guarantors.guarantor_id_type` and checked
/// by the column CHECK constraints, so screens, services and the AI lanes all
/// agree on them.
class KycIdTypes {
  const KycIdTypes._();

  static const List<String> values = [
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
  ];

  static const Map<String, String> labels = {
    'barangay_id': 'Barangay ID',
    'drivers_license': "Driver's License",
    'passport': 'Passport',
    'national_id': 'National ID',
    'umid': 'UMID',
    'prc': 'PRC ID',
    'sss': 'SSS ID',
    'philhealth': 'PhilHealth ID',
    'postal_id': 'Postal ID',
    'voters_id': "Voter's ID",
    'other': 'Other',
  };

  static bool isValid(String? value) =>
      value != null && values.contains(value);

  /// Human-readable name for an ID type, falling back to the raw value for an
  /// unknown/legacy one rather than throwing.
  static String label(String? value) {
    if (value == null) return 'Not provided';
    return labels[value] ?? value;
  }
}

/// Defensive JSONB reader: PostgREST hands back `Map<String, dynamic>` for a
/// jsonb column, but a json-text column or an unexpected shape must not crash
/// the whole parse.
Map<String, dynamic>? _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    final copy = <String, dynamic>{};
    value.forEach((dynamic key, dynamic item) {
      copy[key.toString()] = item;
    });
    return copy;
  }
  return null;
}

/// Defensive timestamp reader for the nullable KYC timestamps — rows created
/// before the KYC columns existed simply return null here.
DateTime? _timestampFromDynamic(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
