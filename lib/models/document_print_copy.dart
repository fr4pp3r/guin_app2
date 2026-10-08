class DocumentPrintCopy {
  final String id;
  final String requestId;
  final String documentId;
  final String verificationToken;
  final String serial;
  final int copyNumber;
  final String? issuedBy;
  final DateTime issuedAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  DocumentPrintCopy({
    required this.id,
    required this.requestId,
    required this.documentId,
    required this.verificationToken,
    required this.serial,
    required this.copyNumber,
    this.issuedBy,
    required this.issuedAt,
    this.lastUsedAt,
    this.createdAt,
  });

  factory DocumentPrintCopy.fromJson(Map<String, dynamic> json) {
    return DocumentPrintCopy(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      documentId: json['document_id'] as String,
      verificationToken: json['verification_token'] as String,
      serial: json['serial'] as String,
      copyNumber: json['copy_number'] as int,
      issuedBy: json['issued_by'] as String?,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'document_id': documentId,
      'verification_token': verificationToken,
      'serial': serial,
      'copy_number': copyNumber,
      'issued_by': issuedBy,
      'issued_at': issuedAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get copyLabel => 'Copy #$copyNumber';
  String get displayLabel => '$copyLabel · $serial';
}
