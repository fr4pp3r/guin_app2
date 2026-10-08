import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:guin_app/automation/document_access_rules.dart';
import 'package:guin_app/automation/print_copy_rules.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/document_print_copy.dart';
import 'package:guin_app/models/document_verification.dart';

class DocumentAccessResult {
  final DocumentAccessDecision decision;
  final DocumentVerification? verification;
  const DocumentAccessResult({required this.decision, this.verification});
  bool get allowed => decision == DocumentAccessDecision.allowed;
}

class ResolvedDocument {
  final DocumentVerification document;
  final DocumentPrintCopy? copy;
  const ResolvedDocument({required this.document, this.copy});
  bool get isPrintCopy => copy != null;
}

class VerificationService {
  final _supabase = SupabaseConfig.client;

  String generateDocumentId({required String barangayCode, required int sequence}) {
    final year = DateTime.now().year;
    return '$barangayCode-$year-${sequence.toString().padLeft(6, '0')}';
  }

  String generateToken(String documentId, String requestId) {
    final raw = '$documentId:$requestId:${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String buildQrUrl(String baseUrl, String documentId, String token) {
    return '$baseUrl/verify/$documentId?token=$token';
  }

  static const String verificationBaseUrl = 'https://barangay-guion.app';

  String buildCopyToken(String documentId, int copyNumber) {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final raw =
        '$documentId:$copyNumber:${DateTime.now().millisecondsSinceEpoch}:${bytes.join(',')}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<int> copyCount(String documentId) async {
    final rows = await _supabase
        .from('document_print_copies')
        .select()
        .eq('document_id', documentId);
    return rows.length;
  }

  Future<DocumentPrintCopy> issuePrintCopy({
    required String requestId,
    required String documentId,
    required String? issuedBy,
  }) async {
    final existing = await copyCount(documentId);
    if (!PrintCopyRules.canIssueMore(existing)) {
      throw StateError('Print limit reached for this document.');
    }
    final copyNumber = PrintCopyRules.nextCopyNumber(existing);
    final serial = PrintCopyRules.serialFor(documentId, copyNumber);
    final token = buildCopyToken(documentId, copyNumber);
    final inserted = await _supabase
        .from('document_print_copies')
        .insert({
          'request_id': requestId,
          'document_id': documentId,
          'verification_token': token,
          'serial': serial,
          'copy_number': copyNumber,
          'issued_by': issuedBy,
          'issued_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return DocumentPrintCopy.fromJson(inserted);
  }

  Future<DocumentPrintCopy?> findCopyByToken(String token) async {
    final row = await _supabase
        .from('document_print_copies')
        .select()
        .eq('verification_token', token)
        .maybeSingle();
    if (row == null) return null;
    return DocumentPrintCopy.fromJson(row);
  }

  Future<ResolvedDocument?> resolveDocument(
    String documentId, {
    String? token,
  }) async {
    if (token != null && token.isNotEmpty) {
      final parent = await _supabase
          .from('document_verifications')
          .select()
          .eq('document_id', documentId)
          .eq('verification_token', token)
          .maybeSingle();
      if (parent != null) {
        return ResolvedDocument(
          document: DocumentVerification.fromJson(parent),
        );
      }
      final copy = await findCopyByToken(token);
      if (copy != null) {
        final copyParent = await _supabase
            .from('document_verifications')
            .select()
            .eq('document_id', copy.documentId)
            .maybeSingle();
        if (copyParent != null) {
          return ResolvedDocument(
            document: DocumentVerification.fromJson(copyParent),
            copy: copy,
          );
        }
      }
      return null;
    }
    final parent = await _supabase
        .from('document_verifications')
        .select()
        .eq('document_id', documentId)
        .maybeSingle();
    if (parent == null) return null;
    return ResolvedDocument(document: DocumentVerification.fromJson(parent));
  }

  Future<DocumentVerification?> verifyDocument(
    String documentId, {
    String? token,
  }) async {
    return (await resolveDocument(documentId, token: token))?.document;
  }

  DocumentAccessDecision evaluate(DocumentVerification v, {DateTime? now}) =>
      DocumentAccessRules.evaluate(
        DocumentAccessState(
          status: v.status,
          expiresAt: v.expiresAt,
          singleUse: v.singleUse,
          maxUses: v.maxUses,
          useCount: v.useCount,
        ),
        now: now,
      );

  /// Atomically consumes one use of a released document.
  /// Evaluates expiry/single-use/limit rules first, then performs an
  /// optimistic-locked update (guards on the observed use_count) so a
  /// double-tap / concurrent verify cannot consume the same use twice.
  Future<DocumentAccessResult> consumeDocument(
    String documentId, {
    required String token,
    DateTime? now,
  }) async {
    final resolved = await resolveDocument(documentId, token: token);
    if (resolved == null) {
      return const DocumentAccessResult(decision: DocumentAccessDecision.notFound);
    }
    final row = resolved.document;
    final clock = now ?? DateTime.now();
    final decision = evaluate(row, now: clock);
    if (decision != DocumentAccessDecision.allowed) {
      return DocumentAccessResult(decision: decision, verification: row);
    }
    final updated = await _supabase
        .from('document_verifications')
        .update({
          'use_count': row.useCount + 1,
          'used_at': clock.toIso8601String(),
          if (row.singleUse ||
              (row.maxUses != null && row.useCount + 1 >= row.maxUses!))
            'status': 'used',
        })
        .eq('document_id', documentId)
        .eq('verification_token', row.verificationToken)
        .eq('use_count', row.useCount)
        .select()
        .maybeSingle();
    if (updated == null) {
      // Lost the race: another verify consumed it first.
      return DocumentAccessResult(decision: DocumentAccessDecision.used, verification: row);
    }
    if (resolved.copy != null) {
      try {
        await _supabase
            .from('document_print_copies')
            .update({'last_used_at': clock.toIso8601String()})
            .eq('id', resolved.copy!.id);
      } catch (_) {
        // Best-effort only: never block the consume flow.
      }
    }
    return DocumentAccessResult(
      decision: DocumentAccessDecision.allowed,
      verification: DocumentVerification.fromJson(updated),
    );
  }
}
