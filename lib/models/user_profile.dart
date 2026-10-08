import 'package:guin_app/utils/role_access.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String address;
  final int age;
  final DateTime dateOfBirth;
  final String placeOfBirth;
  final String civilStatus;
  final String gender;
  final String phoneNumber;
  final String? profilePhotoUrl;
  final String? validIdUrl;
  final bool isApproved;
  final String registrationStatus; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final String role; // 'admin', 'citizen'
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.address,
    required this.age,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.civilStatus,
    required this.gender,
    required this.phoneNumber,
    this.profilePhotoUrl,
    this.validIdUrl,
    required this.isApproved,
    required this.registrationStatus,
    this.rejectionReason,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      address: json['address'] as String,
      age: json['age'] as int,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      placeOfBirth: json['place_of_birth'] as String,
      civilStatus: json['civil_status'] as String,
      gender: json['gender'] as String,
      phoneNumber: json['phone_number'] as String,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      validIdUrl: json['valid_id_url'] as String?,
      isApproved: json['is_approved'] as bool,
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
      'full_name': fullName,
      'address': address,
      'age': age,
      'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      'place_of_birth': placeOfBirth,
      'civil_status': civilStatus,
      'gender': gender,
      'phone_number': phoneNumber,
      'profile_photo_url': profilePhotoUrl,
      'valid_id_url': validIdUrl,
      'is_approved': isApproved,
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
    String? fullName,
    String? address,
    int? age,
    DateTime? dateOfBirth,
    String? placeOfBirth,
    String? civilStatus,
    String? gender,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? validIdUrl,
    bool? isApproved,
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
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      civilStatus: civilStatus ?? this.civilStatus,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      validIdUrl: validIdUrl ?? this.validIdUrl,
      isApproved: isApproved ?? this.isApproved,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => registrationStatus == 'pending';
  bool get isRejected => registrationStatus == 'rejected';
  bool get isAdmin => AppRoles.isOfficial(role);
  bool get isCaptain =>
      role == AppRoles.captain || role == AppRoles.legacyAdmin;
  bool get isSecretary => role == AppRoles.secretary;
  bool get isTreasurer => role == AppRoles.treasurer;
  bool get isKagawadRepresentative => role == AppRoles.kagawadRepresentative;
  bool get isBarangayTanod => role == AppRoles.barangayTanod;
  bool get isCitizen => role == 'citizen';
}
