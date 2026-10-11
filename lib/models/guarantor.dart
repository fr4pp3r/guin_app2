class GuarantorRegistration {
  final String id;
  final String indigentUserId;
  final String guarantorUserId;
  final String guarantorFullName;
  final String? guarantorIdType;
  final String? guarantorIdNumber;
  final String relationship;
  final String status; // 'pending', 'approved', 'rejected'
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  GuarantorRegistration({
    required this.id,
    required this.indigentUserId,
    required this.guarantorUserId,
    required this.guarantorFullName,
    this.guarantorIdType,
    this.guarantorIdNumber,
    required this.relationship,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuarantorRegistration.fromJson(Map<String, dynamic> json) {
    return GuarantorRegistration(
      id: json['id'] as String,
      indigentUserId: json['indigent_user_id'] as String,
      guarantorUserId: json['guarantor_user_id'] as String,
      guarantorFullName: json['guarantor_full_name'] as String,
      guarantorIdType: json['guarantor_id_type'] as String?,
      guarantorIdNumber: json['guarantor_id_number'] as String?,
      relationship: json['relationship'] as String,
      status: json['status'] as String,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: _timestampFromDynamic(json['reviewed_at']),
      reviewNotes: json['review_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'indigent_user_id': indigentUserId,
      'guarantor_user_id': guarantorUserId,
      'guarantor_full_name': guarantorFullName,
      'guarantor_id_type': guarantorIdType,
      'guarantor_id_number': guarantorIdNumber,
      'relationship': relationship,
      'status': status,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  static DateTime? _timestampFromDynamic(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}