import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/automation/release_payload.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/utils/helpers.dart';

class DocumentService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<DocumentRequest> createRequest({
    required String userId,
    required String documentType,
    required String purpose,
    required Map<String, dynamic> documentData,
    required double paymentAmount,
  }) async {
    try {
      final paymentRequired = paymentAmount > 0;
      final response = await _supabase
          .from('document_requests')
          .insert({
            'user_id': userId,
            'document_type': documentType,
            'purpose': purpose,
            'document_data': documentData,
            'payment_amount': paymentAmount,
            'payment_required': paymentRequired,
            'request_status': DocStatus.submitted,
            'payment_status': 'pending',
          })
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // ── Secretary actions ────────────────────────────────────────────────────

  Future<DocumentRequest> recordDraftGenerated({
    required String requestId,
    required String? secretaryId,
    required String draftUrl,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': DocStatus.draftGenerated,
          'draft_url': draftUrl,
          'reviewed_at': Helpers.now().toIso8601String(),
          'reviewed_by_secretary': secretaryId,
        })
        .eq('id', requestId)
        .select()
        .single();
    await _audit(
      requestId,
      secretaryId ?? 'system',
      secretaryId != null ? 'secretary' : 'system',
      'generate_draft',
      null,
      DocStatus.draftGenerated,
    );
    return DocumentRequest.fromJson(response);
  }

  Future<DocumentRequest> markVerifiedForPayment({
    required String requestId,
    required String? secretaryId,
    required bool paymentRequired,
  }) async {
    final now = Helpers.now();
    final nextStatus = paymentRequired
        ? DocStatus.invoiced
        : DocStatus.forApproval;
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': nextStatus,
          'secretary_verified_at': now.toIso8601String(),
          'reviewed_by_secretary': secretaryId,
          if (paymentRequired) ...{
            'invoice_created_at': now.toIso8601String(),
            'invoice_due_date': now
                .add(const Duration(days: 7))
                .toIso8601String(),
          },
        })
        .eq('id', requestId)
        .select()
        .single();
    await _audit(
      requestId,
      secretaryId ?? 'system',
      secretaryId != null ? 'secretary' : 'system',
      'verified_for_payment',
      DocStatus.draftGenerated,
      nextStatus,
    );
    return DocumentRequest.fromJson(response);
  }

  // ── Treasurer actions ────────────────────────────────────────────────────

  Future<DocumentRequest> treasurerConfirmPayment({
    required String requestId,
    required String treasurerId,
    String? method,
    String? referenceNumber,
    String? officialReceiptUrl,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': DocStatus.forApproval,
          'payment_status': 'verified',
          'payment_method': method,
          'payment_reference_number': referenceNumber,
          'payment_verified_at': Helpers.now().toIso8601String(),
          'payment_verified_by': treasurerId,
          // Written in the same UPDATE as the status change so the receipt
          // and the confirmation land atomically (null = no receipt passed).
          'official_receipt_url': officialReceiptUrl,
        })
        .eq('id', requestId)
        .select()
        .single();
    await _audit(
      requestId,
      treasurerId,
      'treasurer',
      'confirm_payment',
      DocStatus.invoiced,
      DocStatus.forApproval,
    );
    return DocumentRequest.fromJson(response);
  }

  Future<DocumentRequest> treasurerRejectPayment({
    required String requestId,
    required String treasurerId,
    required String reason,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': DocStatus.paymentRejected,
          'payment_status': 'rejected',
          'payment_rejection_reason': reason,
          'payment_verified_by': treasurerId,
        })
        .eq('id', requestId)
        .select()
        .single();
    await _audit(
      requestId,
      treasurerId,
      'treasurer',
      'reject_payment',
      DocStatus.invoiced,
      DocStatus.paymentRejected,
      notes: reason,
    );
    return DocumentRequest.fromJson(response);
  }

  // ── Captain / Kagawad actions ────────────────────────────────────────────

  Future<DocumentRequest> captainReject({
    required String requestId,
    required String approverId,
    required String approverRole,
    required String reason,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': DocStatus.rejected,
          'rejection_reason': reason,
          'approver_id': approverId,
          'approver_role': approverRole,
          'captain_approved_at': Helpers.now().toIso8601String(),
        })
        .eq('id', requestId)
        .select()
        .single();
    await _audit(
      requestId,
      approverId,
      approverRole,
      'reject',
      DocStatus.forApproval,
      DocStatus.rejected,
      notes: reason,
    );
    return DocumentRequest.fromJson(response);
  }

  Future<String> uploadPaymentReceipt(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '$userId/receipt_${Helpers.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage
          .from('payment-receipts')
          .upload(fileName, imageFile);
      return _supabase.storage.from('payment-receipts').getPublicUrl(fileName);
    } catch (e) {
      rethrow;
    }
  }

  /// Storage path for the treasurer's official receipt image. Request-scoped
  /// (`<request_id>/official_<ts>.<ext>`) so it is visibly distinct from the
  /// citizen's user-scoped GCash screenshot (`<user_id>/receipt_<ts>.<ext>`).
  static String officialReceiptPath(String requestId, String fileExt) =>
      '$requestId/official_${Helpers.now().millisecondsSinceEpoch}.$fileExt';

  /// Uploads the treasurer's official receipt image to the `payment-receipts`
  /// bucket and returns its public URL. Mirrors [uploadPaymentReceipt].
  Future<String> uploadOfficialReceipt({
    required String requestId,
    required File imageFile,
  }) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = officialReceiptPath(requestId, fileExt);

    await _supabase.storage.from('payment-receipts').upload(fileName, imageFile);
    return _supabase.storage.from('payment-receipts').getPublicUrl(fileName);
  }

  Future<DocumentRequest> submitPaymentReceipt({
    required String requestId,
    required String receiptUrl,
    String paymentMethod = 'gcash',
    String? referenceNumber,
  }) async {
    try {
      final update = {
        'payment_receipt_url': receiptUrl,
        'payment_method': paymentMethod,
      };
      if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
        update['payment_reference_number'] = referenceNumber.trim();
      }
      final response = await _supabase
          .from('document_requests')
          .update(update)
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> updatePaymentParsedFields({
    required String requestId,
    String? referenceNumber,
    double? amount,
    String? date,
    double? confidence,
    String? parseError,
  }) async {
    try {
      final Map<String, dynamic> update = {
        'payment_parsed_at': Helpers.now().toIso8601String(),
      };
      if (confidence != null) update['payment_parsed_confidence'] = confidence;
      if (parseError != null && parseError.isNotEmpty) {
        update['payment_parse_error'] = parseError;
      } else {
        update['payment_parse_error'] = null;
      }
      // Never overwrite existing human-entered ref
      final check = await _supabase
          .from('document_requests')
          .select('payment_reference_number')
          .eq('id', requestId)
          .maybeSingle();
      if (check != null) {
        final existing = check['payment_reference_number'];
        if (existing == null || (existing as String).trim().isEmpty) {
          if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
            update['payment_reference_number'] = referenceNumber.trim();
          }
        }
      } else if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
        update['payment_reference_number'] = referenceNumber.trim();
      }
      // store receipt_parse as JSON if available
      final Map<String, dynamic> receiptParse = {};
      if (referenceNumber != null) receiptParse['referenceNumber'] = referenceNumber;
      if (amount != null) receiptParse['amount'] = amount;
      if (date != null) receiptParse['paidAt'] = date;
      if (confidence != null) receiptParse['confidence'] = confidence;
      receiptParse['parsedAt'] = Helpers.now().toIso8601String();
      update['receipt_parse'] = receiptParse;
      final response = await _supabase
          .from('document_requests')
          .update(update)
          .eq('id', requestId)
          .select()
          .single();
      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Canonical status transition for a newly uploaded receipt.
  Future<DocumentRequest> markPaymentSubmitted({
    required String requestId,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({'request_status': DocStatus.paymentSubmitted})
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> verifyPayment({
    required String requestId,
    required String adminId,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'payment_status': 'verified',
            'payment_verified_at': Helpers.now().toIso8601String(),
            'payment_verified_by': adminId,
            'request_status': DocStatus.forApproval,
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> rejectPayment({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'payment_status': 'rejected',
            'payment_verified_by': adminId,
            'payment_rejection_reason': reason,
            'request_status': 'pending_payment',
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> approveRequest({
    required String requestId,
    required String adminId,
    required String documentUrl,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'request_status': 'approved_for_release',
            'reviewed_at': Helpers.now().toIso8601String(),
            'reviewed_by': adminId,
            'document_url': documentUrl,
            'generated_document_url': documentUrl,
            'approved_by': adminId,
            'approved_at': Helpers.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> rejectRequest({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'request_status': 'rejected',
            'reviewed_at': Helpers.now().toIso8601String(),
            'reviewed_by': adminId,
            'rejection_reason': reason,
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a request (for users who want to cancel)
  Future<void> deleteRequest(String requestId) async {
    try {
      // 1. Fetch the request row first to get all storage URLs
      final request = await getRequestById(requestId);
      if (request == null) {
        debugPrint('deleteRequest: request $requestId not found');
        return;
      }

      // 2. Delete the row from document_requests (triggers DB cascades)
      await _supabase.from('document_requests').delete().eq('id', requestId);

      // 3. Purge all non-null storage objects from the two buckets
      // Collect paths to delete
      final List<String> paymentReceiptPaths = [];
      final List<String> documentPaths = [];

      // Helper to extract object path from public URL
      String? extractPath(String? publicUrl, String bucket) {
        if (publicUrl == null || publicUrl.isEmpty) return null;
        final uri = Uri.tryParse(publicUrl);
        if (uri == null) return null;
        // Public URL format: https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf(bucket);
        if (bucketIndex >= 0 && bucketIndex + 1 < segments.length) {
          return segments.sublist(bucketIndex + 1).join('/');
        }
        return null;
      }

      // payment-receipts bucket
      if (request.paymentReceiptUrl != null) {
        final path = extractPath(request.paymentReceiptUrl, 'payment-receipts');
        if (path != null) paymentReceiptPaths.add(path);
      }

      // documents bucket
      if (request.documentUrl != null) {
        final path = extractPath(request.documentUrl, 'documents');
        if (path != null) documentPaths.add(path);
      }
      if (request.generatedDocumentUrl != null) {
        final path = extractPath(request.generatedDocumentUrl, 'documents');
        if (path != null) documentPaths.add(path);
      }
      if (request.finalDocumentUrl != null) {
        final path = extractPath(request.finalDocumentUrl, 'documents');
        if (path != null) documentPaths.add(path);
      }
      if (request.draftUrl != null) {
        final path = extractPath(request.draftUrl, 'documents');
        if (path != null) documentPaths.add(path);
      }
      if (request.qrUrl != null) {
        final path = extractPath(request.qrUrl, 'documents');
        if (path != null) documentPaths.add(path);
      }

      // Best-effort removal: swallow individual failures
      if (paymentReceiptPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('payment-receipts').remove(paymentReceiptPaths);
        } catch (e) {
          debugPrint('deleteRequest: failed to remove payment receipts: $e');
        }
      }
      if (documentPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('documents').remove(documentPaths);
        } catch (e) {
          debugPrint('deleteRequest: failed to remove documents: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DocumentRequest>> getUserRequests(String userId) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false);

      return (response as List)
          .map((json) => DocumentRequest.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DocumentRequest>> getAllRequests() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!document_requests_user_id_fkey(username, full_name)
          ''')
          .order('requested_at', ascending: false);

      return _parseRequestsWithUser(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest?> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select()
          .eq('id', requestId)
          .single();
      return DocumentRequest.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  // Treasurer: requests waiting for payment verification
  Future<List<DocumentRequest>> getPendingPayments() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!document_requests_user_id_fkey(username, full_name)
          ''')
          .inFilter('request_status', [
            DocStatus.invoiced,
            DocStatus.paymentSubmitted,
            DocStatus.pendingPayment,
          ])
          .order('requested_at', ascending: false);

      return _parseRequestsWithUser(response);
    } catch (e) {
      rethrow;
    }
  }

  // Secretary: requests to review / generate drafts
  Future<List<DocumentRequest>> getPendingReviews() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!document_requests_user_id_fkey(username, full_name)
          ''')
          .inFilter('request_status', [
            DocStatus.submitted,
            DocStatus.draftGenerated,
            DocStatus.needsRevision,
            DocStatus.pendingReview,
            DocStatus.approvedForRelease,
          ])
          .order('requested_at', ascending: false);

      return _parseRequestsWithUser(response);
    } catch (e) {
      rethrow;
    }
  }

  // Captain / Kagawad: requests awaiting final approval
  Future<List<DocumentRequest>> getForApproval() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!document_requests_user_id_fkey(username, full_name)
          ''')
          .eq('request_status', DocStatus.forApproval)
          .order('requested_at', ascending: false);

      return _parseRequestsWithUser(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadGeneratedDocument(
    String requestId,
    File documentFile,
  ) async {
    try {
      final fileExt = documentFile.path.split('.').last;
      final fileName =
          '$requestId/document_${Helpers.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('documents').upload(fileName, documentFile);
      return _supabase.storage.from('documents').getPublicUrl(fileName);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadERecceipt(
    String requestId,
    File receiptFile,
  ) async {
    try {
      final fileExt = receiptFile.path.split('.').last;
      final fileName =
          '$requestId/e-receipt_${Helpers.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('documents').upload(fileName, receiptFile);
      return _supabase.storage.from('documents').getPublicUrl(fileName);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> updateERecceiptUrl({
    required String requestId,
    required String eReceiptUrl,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({'e_receipt_url': eReceiptUrl})
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> getStatistics() async {
    try {
      // Buckets mirror the live queue queries (getPendingPayments /
      // getPendingReviews) and the canonical 16-status pipeline — NOT the
      // legacy `pending_payment` / `pending_review` / `approved` values that
      // the workflow no longer writes (documented in DOCUMENTATION §13.5).
      final response = await _supabase
          .from('document_requests')
          .select('request_status');

      final rows = response as List;
      int countWhere(bool Function(String status) test) => rows
          .where(
            (r) => test(
              (r as Map<String, dynamic>)['request_status'] as String? ?? '',
            ),
          )
          .length;

      final pendingPayment = countWhere(
        (s) =>
            s == DocStatus.invoiced ||
            s == DocStatus.paymentSubmitted ||
            s == DocStatus.pendingPayment,
      );
      final pendingReview = countWhere(
        (s) =>
            s == DocStatus.submitted ||
            s == DocStatus.draftGenerated ||
            s == DocStatus.needsRevision ||
            s == DocStatus.pendingReview ||
            s == DocStatus.approvedForRelease,
      );
      final approved = countWhere(
        (s) =>
            s == DocStatus.approved ||
            s == DocStatus.approvedForRelease ||
            s == DocStatus.released,
      );
      final rejected = countWhere((s) => s == DocStatus.rejected);

      return {
        'pending_payment': pendingPayment,
        'pending_review': pendingReview,
        'approved': approved,
        'rejected': rejected,
        'total': rows.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentRequest> encodeCashPayment({
    required String requestId,
    required String treasurerId,
    required String method,
    String? referenceNumber,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'payment_status': 'verified',
          'payment_method': method,
          'payment_reference_number': referenceNumber,
          'payment_verified_at': Helpers.now().toIso8601String(),
          'payment_verified_by': treasurerId,
          'request_status': DocStatus.forApproval,
        })
        .eq('id', requestId)
        .select()
        .single();
    return DocumentRequest.fromJson(response);
  }

  Future<DocumentRequest> releaseDocument({
    required String requestId,
    required String releasedBy,
    required String finalDocumentUrl,
    required String citizenName,
    required ReleasePayload payload,
  }) async {
    final response = await _supabase
        .from('document_requests')
        .update({
          'request_status': 'released',
          'final_document_url': finalDocumentUrl,
          'document_url': finalDocumentUrl,
          'document_id': payload.documentId,
          'verification_token': payload.verificationToken,
          'qr_url': payload.qrUrl,
          'document_hash': payload.documentHash,
          'expires_at': payload.expiresAt?.toIso8601String(),
          'single_use': payload.singleUse,
          'max_uses': payload.maxUses,
          'use_count': 0,
          'released_by': releasedBy,
          'released_at': Helpers.now().toIso8601String(),
          'release_method': payload.releaseMethod,
        })
        .eq('id', requestId)
        .select()
        .single();

    await _supabase.from('document_verifications').insert({
      'request_id': requestId,
      'document_id': payload.documentId,
      'verification_token': payload.verificationToken,
      'document_type': response['document_type'],
      'citizen_name': citizenName,
      'status': 'valid',
      'released_by': releasedBy,
      'document_hash': payload.documentHash,
      'expires_at': payload.expiresAt?.toIso8601String(),
      'single_use': payload.singleUse,
      'max_uses': payload.maxUses,
      'use_count': 0,
    });

    return DocumentRequest.fromJson(response);
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _audit(
    String requestId,
    String actorId,
    String actorRole,
    String action,
    String? fromStatus,
    String? toStatus, {
    String? notes,
  }) async {
    try {
      await _supabase.from('audit_logs').insert({
        'request_id': requestId,
        'actor_id': actorId,
        'actor_role': actorRole,
        'action': action,
        'from_status': fromStatus,
        'to_status': toStatus,
        'notes': notes,
      });
    } catch (_) {
      // Audit failures are non-fatal
    }
  }

  List<DocumentRequest> _parseRequestsWithUser(dynamic response) {
    return (response as List).map((json) {
      final flatJson = Map<String, dynamic>.from(json);
      if (json['users_profile'] != null) {
        flatJson['username'] = json['users_profile']['username'];
        flatJson['full_name'] = json['users_profile']['full_name'];
      }
      flatJson.remove('users_profile');
      return DocumentRequest.fromJson(flatJson);
    }).toList();
  }
}
