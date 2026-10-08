library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:guin_app/automation/document_access_rules.dart';

class ReleasePayload {
  ReleasePayload({
    required this.documentId,
    required this.verificationToken,
    required this.qrUrl,
    required this.documentHash,
    required this.releasedBy,
    required this.releasedAt,
    this.releaseMethod = 'ecopy',
    this.expiresAt,
    this.singleUse = false,
    this.maxUses,
  });

  final String documentId;
  final String verificationToken;
  final String qrUrl;
  final String documentHash; // SHA-256 of the PDF bytes (empty until withContentHash)
  final String releasedBy;
  final DateTime releasedAt;
  final String releaseMethod;
  final DateTime? expiresAt;
  final bool singleUse;
  final int? maxUses;

  /// Phase 1: build identity BEFORE the PDF exists. documentHash is empty.
  static ReleasePayload buildIdentity({
    required String requestId,
    required int sequence,
    required String releasedBy,
    required DateTime now,
    String barangayCode = 'BRGY-GUION',
    String verificationBaseUrl = 'https://barangay-guion.app',
    String releaseMethod = 'ecopy',
    bool singleUse = false,
    int? maxUses,
    Duration? validFor,
    bool noExpiry = false,
  }) {
    final seq = sequence % 1000000;
    final documentId = '$barangayCode-${now.year}-${seq.toString().padLeft(6, '0')}';
    final token = sha256
        .convert(utf8.encode('$documentId:$requestId:${now.toIso8601String()}'))
        .toString();
    final qrUrl = '$verificationBaseUrl?documentId=$documentId&token=$token';
    return ReleasePayload(
      documentId: documentId,
      verificationToken: token,
      qrUrl: qrUrl,
      documentHash: '',
      releasedBy: releasedBy,
      releasedAt: now,
      releaseMethod: releaseMethod,
      expiresAt: noExpiry
          ? null
          : now.add(validFor ?? DocumentAccessRules.defaultValidity),
      singleUse: singleUse,
      maxUses: maxUses,
    );
  }

  /// Phase 3: attach the real content hash computed from PDF bytes.
  ReleasePayload withContentHash(List<int> documentBytes) => ReleasePayload(
        documentId: documentId,
        verificationToken: verificationToken,
        qrUrl: qrUrl,
        documentHash: hashBytes(documentBytes),
        releasedBy: releasedBy,
        releasedAt: releasedAt,
        releaseMethod: releaseMethod,
        expiresAt: expiresAt,
        singleUse: singleUse,
        maxUses: maxUses,
      );

  static String hashBytes(List<int> bytes) => sha256.convert(bytes).toString();
}
