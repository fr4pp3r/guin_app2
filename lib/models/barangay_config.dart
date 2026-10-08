class BarangayConfig {
  final String id;
  final String gcashName;
  final String gcashNumber;
  final String barangayName;
  final String barangayAddress;
  final String? barangayCaptain;
  final String? contactNumber;
  final String? email;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  BarangayConfig({
    required this.id,
    required this.gcashName,
    required this.gcashNumber,
    required this.barangayName,
    required this.barangayAddress,
    this.barangayCaptain,
    this.contactNumber,
    this.email,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BarangayConfig.fromJson(Map<String, dynamic> json) {
    return BarangayConfig(
      id: json['id'] as String,
      gcashName: json['gcash_name'] as String,
      gcashNumber: json['gcash_number'] as String,
      barangayName: json['barangay_name'] as String,
      barangayAddress: json['barangay_address'] as String,
      barangayCaptain: json['barangay_captain'] as String?,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      logoUrl: json['logo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gcash_name': gcashName,
      'gcash_number': gcashNumber,
      'barangay_name': barangayName,
      'barangay_address': barangayAddress,
      'barangay_captain': barangayCaptain,
      'contact_number': contactNumber,
      'email': email,
      'logo_url': logoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BarangayConfig copyWith({
    String? id,
    String? gcashName,
    String? gcashNumber,
    String? barangayName,
    String? barangayAddress,
    String? barangayCaptain,
    String? contactNumber,
    String? email,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BarangayConfig(
      id: id ?? this.id,
      gcashName: gcashName ?? this.gcashName,
      gcashNumber: gcashNumber ?? this.gcashNumber,
      barangayName: barangayName ?? this.barangayName,
      barangayAddress: barangayAddress ?? this.barangayAddress,
      barangayCaptain: barangayCaptain ?? this.barangayCaptain,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
