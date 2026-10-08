class DocumentFee {
  final String id;
  final String documentType;
  final double feeAmount;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentFee({
    required this.id,
    required this.documentType,
    required this.feeAmount,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentFee.fromJson(Map<String, dynamic> json) {
    return DocumentFee(
      id: json['id'] as String,
      documentType: json['document_type'] as String,
      feeAmount: (json['fee_amount'] as num).toDouble(),
      description: json['description'] as String?,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DocumentFee copyWith({
    String? id,
    String? documentType,
    double? feeAmount,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentFee(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      feeAmount: feeAmount ?? this.feeAmount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get documentTypeDisplay {
    switch (documentType) {
      case 'barangay_clearance':
        return 'Barangay Clearance';
      case 'indigency':
        return 'Certificate of Indigency';
      case 'barangay_id':
        return 'Barangay ID';
      case 'cedula':
        return 'Cedula';
      default:
        return documentType;
    }
  }

  bool get isFree => feeAmount == 0;
}
