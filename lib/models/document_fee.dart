class DocumentFee {
  final String id;
  final String documentType;
  final double feeAmount;
  final String? description;
  final bool isFree;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentFee({
    required this.id,
    required this.documentType,
    required this.feeAmount,
    this.description,
    bool? isFree,
    required this.createdAt,
    required this.updatedAt,
  }) : isFree = isFree ?? feeAmount == 0;

  factory DocumentFee.fromJson(Map<String, dynamic> json) {
    return DocumentFee(
      id: json['id'] as String,
      documentType: json['document_type'] as String,
      feeAmount: (json['fee_amount'] as num).toDouble(),
      description: json['description'] as String?,
      isFree: json['is_free'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_type': documentType,
      'fee_amount': feeAmount,
      'description': description,
      'is_free': isFree,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DocumentFee copyWith({
    String? id,
    String? documentType,
    double? feeAmount,
    String? description,
    bool? isFree,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentFee(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      feeAmount: feeAmount ?? this.feeAmount,
      description: description ?? this.description,
      isFree: isFree ?? this.isFree,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get documentTypeDisplay {
    switch (documentType) {
      case 'barangay_clearance':
        return 'Barangay Clearance';
      case 'business_clearance':
        return 'Barangay Business Clearance';
      case 'certification':
        return 'Barangay Certification';
      case 'oath_undertaking':
        return 'Oath of Undertaking';
      case 'indigency':
        return 'Certificate of Indigency';
      case 'good_moral':
        return 'Certificate of Good Moral Character';
      case 'residency':
        return 'Certificate of Residency';
      case 'cedula':
        return 'Cedula';
      case 'barangay_id':
        return 'Barangay ID';
      default:
        return documentType;
    }
  }
}
