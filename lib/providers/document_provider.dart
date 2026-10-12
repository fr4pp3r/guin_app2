import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:guin_app/automation/release_payload.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/services/document_automation_service.dart';
import 'package:guin_app/services/document_cache_service.dart';
import 'package:guin_app/services/document_service.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';

class DocumentProvider with ChangeNotifier {
  final DocumentService _documentService = DocumentService();
  final DocumentCacheService _cache = DocumentCacheService();
  late final DocumentAutomationService _automation =
      DocumentAutomationService(documentService: _documentService);
  RealtimeChannel? _documentsChannel;

  List<DocumentRequest> _myRequests = [];
  bool _isFromCache = false;
  DateTime? _cacheTimestamp;
  List<DocumentRequest> _allRequests = [];
  List<DocumentRequest> _pendingPayments = [];
  List<DocumentRequest> _pendingReviews = [];
  List<DocumentRequest> _forApproval = [];

  bool _isLoading = false;
  String? _error;

  List<DocumentRequest> get myRequests => _myRequests;
  List<DocumentRequest> get allRequests => _allRequests;
  List<DocumentRequest> get pendingPayments => _pendingPayments;
  List<DocumentRequest> get pendingReviews => _pendingReviews;
  List<DocumentRequest> get forApproval => _forApproval;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when [myRequests] currently came from the offline cache, i.e. the
  /// last network fetch failed and we fell back to saved data.
  bool get isFromCache => _isFromCache;

  /// When the cached data currently being shown was saved (null when live).
  DateTime? get cacheTimestamp => _cacheTimestamp;

  // Citizen: Load their own requests (network-first, offline cache fallback)
  Future<void> loadMyRequests(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myRequests = await _documentService.getUserRequests(userId);
      _isFromCache = false;
      _cacheTimestamp = null;
      _isLoading = false;
      notifyListeners();

      // Write-through: keep the offline copy fresh. Must never break the load.
      try {
        await _cache.saveMyRequests(userId, _myRequests);
      } catch (e) {
        debugPrint('Caching my requests failed: $e');
      }
    } catch (e) {
      // Network/Supabase fetch failed — fall back to the last cached copy.
      final cached = await _cache.loadMyRequests(userId);
      if (cached != null) {
        _myRequests = cached.requests;
        _isFromCache = true;
        _cacheTimestamp = cached.cachedAt;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Load all requests
  Future<void> loadAllRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allRequests = await _documentService.getAllRequests();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Load requests pending payment verification
  Future<void> loadPendingPayments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pendingPayments = await _documentService.getPendingPayments();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Load requests pending final review
  Future<void> loadPendingReviews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pendingReviews = await _documentService.getPendingReviews();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Citizen: Create new document request
  Future<void> createRequest({
    required String userId,
    required String documentType,
    required String purpose,
    required Map<String, dynamic> documentData,
    required double paymentAmount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _documentService.createRequest(
        userId: userId,
        documentType: documentType,
        purpose: purpose,
        documentData: documentData,
        paymentAmount: paymentAmount,
      );

      // Run the automation pipeline; it must never break submission.
      try {
        await _automation.afterSubmission(request: created);
      } catch (e) {
        debugPrint('afterSubmission failed: $e');
      }

      // Reload user's requests
      await loadMyRequests(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Citizen: Upload payment receipt
  Future<void> uploadReceipt({
    required String requestId,
    required File receiptImage,
    required String userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload receipt to storage
      final receiptUrl = await _documentService.uploadPaymentReceipt(
        userId,
        receiptImage,
      );

      // Run the automation pipeline (canonical status + notify); it must
      // never break the citizen's upload, so fall back to recording the
      // receipt URL directly if automation is unavailable.
      try {
        final request = await _documentService.getRequestById(requestId);
        if (request != null) {
          await _automation.afterPaymentReceipt(
            request: request,
            receiptUrl: receiptUrl,
          );
        } else {
          debugPrint('afterPaymentReceipt: request $requestId not found');
          await _documentService.submitPaymentReceipt(
            requestId: requestId,
            receiptUrl: receiptUrl,
          );
        }
      } catch (e) {
        debugPrint('afterPaymentReceipt failed: $e');
        try {
          await _documentService.submitPaymentReceipt(
            requestId: requestId,
            receiptUrl: receiptUrl,
          );
        } catch (e2) {
          debugPrint('submitPaymentReceipt fallback failed: $e2');
        }
      }

      // Reload user's requests
      await loadMyRequests(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Cancel/delete a request
  Future<void> cancelRequest({
    required String requestId,
    required String userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.deleteRequest(requestId);

      // Reload user's requests
      await loadMyRequests(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Verify payment
  Future<void> verifyPayment({
    required String requestId,
    required String adminId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.verifyPayment(
        requestId: requestId,
        adminId: adminId,
      );

      // Reload pending payments list
      await loadPendingPayments();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> encodeCashPayment({
    required String requestId,
    required String treasurerId,
    required String method,
    String? referenceNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.encodeCashPayment(
        requestId: requestId,
        treasurerId: treasurerId,
        method: method,
        referenceNumber: referenceNumber,
      );
      await loadPendingPayments();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Reject payment
  Future<void> rejectPayment({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.rejectPayment(
        requestId: requestId,
        adminId: adminId,
        reason: reason,
      );

      // Reload pending payments list
      await loadPendingPayments();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Approve request with document
  Future<void> approveRequest({
    required String requestId,
    required String adminId,
    required File generatedDocument,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload generated document
      final documentUrl = await _documentService.uploadGeneratedDocument(
        requestId,
        generatedDocument,
      );

      // Approve request with document URL
      await _documentService.approveRequest(
        requestId: requestId,
        adminId: adminId,
        documentUrl: documentUrl,
      );

      // Reload pending reviews list
      await loadPendingReviews();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Reject request
  Future<void> rejectRequest({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.rejectRequest(
        requestId: requestId,
        adminId: adminId,
        reason: reason,
      );

      // Reload pending reviews list
      await loadPendingReviews();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> releaseDocument({
    required String requestId,
    required String releasedBy,
    required String finalDocumentUrl,
    required String citizenName,
    required ReleasePayload payload,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentService.releaseDocument(
        requestId: requestId,
        releasedBy: releasedBy,
        finalDocumentUrl: finalDocumentUrl,
        citizenName: citizenName,
        payload: payload,
      );
      await loadAllRequests();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Captain: Load requests awaiting final approval
  Future<void> loadForApproval() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _forApproval = await _documentService.getForApproval();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Secretary workflow actions ──────────────────────────────────────────

  Future<void> recordDraftGenerated({
    required String requestId,
    required String secretaryId,
    required File draftDocument,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final draftUrl = await _documentService.uploadGeneratedDocument(
        requestId,
        draftDocument,
      );
      await _documentService.recordDraftGenerated(
        requestId: requestId,
        secretaryId: secretaryId,
        draftUrl: draftUrl,
      );
      await loadPendingReviews();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> requestRevision({
    required String requestId,
    required String secretaryId,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _documentService.requestRevision(
        requestId: requestId,
        secretaryId: secretaryId,
        notes: notes,
      );
      await loadPendingReviews();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markVerifiedForPayment({
    required String requestId,
    required String secretaryId,
    required bool paymentRequired,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _documentService.markVerifiedForPayment(
        requestId: requestId,
        secretaryId: secretaryId,
        paymentRequired: paymentRequired,
      );
      await loadPendingReviews();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Treasurer workflow actions ─────────────────────────────────────────

  Future<void> treasurerConfirmPayment({
    required String requestId,
    required String treasurerId,
    String? method,
    String? referenceNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Delegate write + notify to automation (sole status writer).
      final request = await _documentService.getRequestById(requestId);
      if (request != null) {
        await _automation.afterPaymentConfirmed(
          request: request,
          treasurerId: treasurerId,
          method: method,
          referenceNumber: referenceNumber,
        );
      } else {
        debugPrint('treasurerConfirmPayment: request $requestId not found');
        await _documentService.treasurerConfirmPayment(
          requestId: requestId,
          treasurerId: treasurerId,
          method: method,
          referenceNumber: referenceNumber,
        );
      }
      await loadPendingPayments();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> treasurerRejectPayment({
    required String requestId,
    required String treasurerId,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Delegate write + notify to automation (sole status writer).
      final request = await _documentService.getRequestById(requestId);
      if (request != null) {
        await _automation.afterPaymentRejected(
          request: request,
          treasurerId: treasurerId,
          reason: reason,
        );
      } else {
        debugPrint('treasurerRejectPayment: request $requestId not found');
        await _documentService.treasurerRejectPayment(
          requestId: requestId,
          treasurerId: treasurerId,
          reason: reason,
        );
      }
      await loadPendingPayments();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Captain / Kagawad workflow actions ──────────────────────────────────

  Future<void> captainApproveAndRelease({
    required String requestId,
    required String approverId,
    required String approverRole,
    required File finalDocument,
    required String citizenName,
    required ReleasePayload payload,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final docUrl = await _documentService.uploadGeneratedDocument(
        requestId,
        finalDocument,
      );
      await _documentService.releaseDocument(
        requestId: requestId,
        releasedBy: approverId,
        finalDocumentUrl: docUrl,
        citizenName: citizenName,
        payload: payload,
      );
      await loadForApproval();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> captainReject({
    required String requestId,
    required String approverId,
    required String approverRole,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _documentService.captainReject(
        requestId: requestId,
        approverId: approverId,
        approverRole: approverRole,
        reason: reason,
      );
      await loadForApproval();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Admin: Delete a document request (captain / legacyAdmin only)
  Future<void> deleteRequestAdmin({
    required String requestId,
    String? currentUserRole,
  }) async {
    if (currentUserRole == null) {
      _error = 'Permission check requires currentUserRole parameter.';
      notifyListeners();
      throw Exception('currentUserRole is required for admin document deletion permission check.');
    }
    if (!AppRoles.canDeleteDocuments(currentUserRole)) {
      _error = 'You do not have permission to delete documents.';
      notifyListeners();
      throw Exception('Insufficient permissions: only Captain or Administrator can delete documents.');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _documentService.deleteRequest(requestId);
      await loadAllRequests();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      return await _documentService.getStatistics();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Subscribe to real-time updates for document_requests table
  void subscribeToDocuments() {
    _documentsChannel = SupabaseConfig.client
        .channel('document_requests_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_requests',
          callback: (payload) {
            // Reload data when any change occurs
            loadPendingReviews();
            loadPendingPayments();
          },
        )
        .subscribe();
  }

  // Subscribe to real-time updates for specific user's documents
  void subscribeToUserDocuments(String userId) {
    _documentsChannel = SupabaseConfig.client
        .channel('user_documents_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Reload user's documents when changes occur
            loadMyRequests(userId);
          },
        )
        .subscribe();
  }

  // Unsubscribe from real-time updates
  void unsubscribeFromDocuments() {
    if (_documentsChannel != null) {
      SupabaseConfig.client.removeChannel(_documentsChannel!);
      _documentsChannel = null;
    }
  }

  @override
  void dispose() {
    unsubscribeFromDocuments();
    super.dispose();
  }
}
