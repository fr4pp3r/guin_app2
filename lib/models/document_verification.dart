import 'package:guin_app/utils/helpers.dart';

class DocumentVerification {
  final String id;
  final String requestId;
  final String documentId;
  final String verificationToken;
  final String documentType;
  final String citizenName;
  final String status;
  final DateTime issuedAt;
  final String? releasedBy;
  final String? documentHash;
  final DateTime? expiresAt;
  final bool singleUse;
  final int? maxUses;
  final int useCount;
  final DateTime? usedAt;

  DocumentVerification({
    required this.id,
    required this.requestId,
    required this.documentId,
    required this.verificationToken,
    required this.documentType,
    required this.citizenName,
    required this.status,
    required this.issuedAt,
    this.releasedBy,
    this.documentHash,
    this.expiresAt,
    this.singleUse = false,
    this.maxUses,
    this.useCount = 0,
    this.usedAt,
  });

  factory DocumentVerification.fromJson(Map<String, dynamic> json) {
    return DocumentVerification(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      documentId: json['document_id'] as String,
      verificationToken: json['verification_token'] as String,
      documentType: json['document_type'] as String,
      citizenName: json['citizen_name'] as String,
      status: json['status'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      releasedBy: json['released_by'] as String?,
      documentHash: json['document_hash'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      singleUse: json['single_use'] as bool? ?? false,
      maxUses: json['max_uses'] as int?,
      useCount: json['use_count'] as int? ?? 0,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'document_id': documentId,
      'verification_token': verificationToken,
      'document_type': documentType,
      'citizen_name': citizenName,
      'status': status,
      'issued_at': issuedAt.toIso8601String(),
      'released_by': releasedBy,
      'document_hash': documentHash,
      'expires_at': expiresAt?.toIso8601String(),
      'single_use': singleUse,
      'max_uses': maxUses,
      'use_count': useCount,
      'used_at': usedAt?.toIso8601String(),
    };
  }

  bool get isExpired => expiresAt != null && Helpers.now().isAfter(expiresAt!);
  int? get remainingUses {
    if (maxUses == null) return null;
    final left = maxUses! - useCount;
    return left < 0 ? 0 : left;
  }
}
