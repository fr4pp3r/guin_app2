import 'package:guin_app/utils/helpers.dart';

class DocStatus {
  static const submitted = 'submitted';
  static const draftGenerated = 'draft_generated';
  static const needsRevision = 'needs_revision';
  static const verifiedForPayment = 'verified_for_payment';
  static const invoiced = 'invoiced';
  static const paymentSubmitted = 'payment_submitted';
  static const paymentRejected = 'payment_rejected';
  static const paymentConfirmed = 'payment_confirmed';
  static const forApproval = 'for_approval';
  static const approved = 'approved';
  static const released = 'released';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  // Legacy (kept for backward compat)
  static const pendingReview = 'pending_review';
  static const pendingPayment = 'pending_payment';
  static const approvedForRelease = 'approved_for_release';
}

class DocumentRequest {
  final String id;
  final String userId;
  final String documentType;
  final String purpose;
  final Map<String, dynamic> documentData;
  final String requestStatus;
  final String? rejectionReason;
  final double paymentAmount;
  final String? paymentReceiptUrl;
  final String paymentStatus;
  final DateTime? paymentVerifiedAt;
  final String? paymentVerifiedBy;
  final String? paymentRejectionReason;
  final String? documentUrl;
  final String? generatedDocumentUrl;
  final String? finalDocumentUrl;
  final String? documentId;
  final String? verificationToken;
  final String? qrUrl;
  final String? eReceiptUrl;
  final String? documentHash;
  final String? paymentMethod;
  final String? paymentReferenceNumber;
  final bool paymentRequired;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? releasedBy;
  final DateTime? releasedAt;
  final String? releaseMethod;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  // Document access control (expiry + single-use/use limits)
  final DateTime? expiresAt;
  final bool singleUse;
  final int? maxUses;
  final int useCount;
  final DateTime? usedAt;
  // New workflow fields
  final String? secretaryNotes;
  final String? draftUrl;
  final String? reviewedBySecretary;
  final DateTime? secretaryVerifiedAt;
  final String? invoiceDescription;
  final DateTime? invoiceDueDate;
  final DateTime? invoiceCreatedAt;
  final bool captainUnavailable;
  final String? approverId;
  final String? approverRole;
  final DateTime? captainApprovedAt;
  // Payment parse metadata
  final DateTime? paymentParsedAt;
  final double? paymentParsedConfidence;
  final String? paymentParseError;
  final Map<String, dynamic>? receiptParse;
  // Optional join fields
  final String? userName;
  final String? userFullName;

  DocumentRequest({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.purpose,
    required this.documentData,
    required this.requestStatus,
    this.rejectionReason,
    required this.paymentAmount,
    this.paymentReceiptUrl,
    required this.paymentStatus,
    this.paymentVerifiedAt,
    this.paymentVerifiedBy,
    this.paymentRejectionReason,
    this.documentUrl,
    this.generatedDocumentUrl,
    this.finalDocumentUrl,
    this.documentId,
    this.verificationToken,
    this.qrUrl,
    this.eReceiptUrl,
    this.documentHash,
    this.paymentMethod,
    this.paymentReferenceNumber,
    this.paymentRequired = true,
    this.approvedBy,
    this.approvedAt,
    this.releasedBy,
    this.releasedAt,
    this.releaseMethod,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.expiresAt,
    this.singleUse = false,
    this.maxUses,
    this.useCount = 0,
    this.usedAt,
    this.secretaryNotes,
    this.draftUrl,
    this.reviewedBySecretary,
    this.secretaryVerifiedAt,
    this.invoiceDescription,
    this.invoiceDueDate,
    this.invoiceCreatedAt,
    this.captainUnavailable = false,
    this.approverId,
    this.approverRole,
    this.captainApprovedAt,
    this.paymentParsedAt,
    this.paymentParsedConfidence,
    this.paymentParseError,
    this.receiptParse,
    this.userName,
    this.userFullName,
  });

  factory DocumentRequest.fromJson(Map<String, dynamic> json) {
    return DocumentRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentType: json['document_type'] as String,
      purpose: json['purpose'] as String,
      documentData: json['document_data'] as Map<String, dynamic>? ?? {},
      requestStatus: json['request_status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      paymentAmount: (json['payment_amount'] as num).toDouble(),
      paymentReceiptUrl: json['payment_receipt_url'] as String?,
      paymentStatus: json['payment_status'] as String,
      paymentVerifiedAt: json['payment_verified_at'] != null
          ? DateTime.parse(json['payment_verified_at'] as String)
          : null,
      paymentVerifiedBy: json['payment_verified_by'] as String?,
      paymentRejectionReason: json['payment_rejection_reason'] as String?,
      documentUrl: json['document_url'] as String?,
      generatedDocumentUrl: json['generated_document_url'] as String?,
      finalDocumentUrl: json['final_document_url'] as String?,
      documentId: json['document_id'] as String?,
      verificationToken: json['verification_token'] as String?,
      qrUrl: json['qr_url'] as String?,
      eReceiptUrl: json['e_receipt_url'] as String?,
      documentHash: json['document_hash'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentReferenceNumber: json['payment_reference_number'] as String?,
      paymentRequired:
          json['payment_required'] as bool? ??
          ((json['payment_amount'] as num?)?.toDouble() ?? 0) > 0,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      releasedBy: json['released_by'] as String?,
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : null,
      releaseMethod: json['release_method'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      singleUse: json['single_use'] as bool? ?? false,
      maxUses: json['max_uses'] as int?,
      useCount: json['use_count'] as int? ?? 0,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
      secretaryNotes: json['secretary_notes'] as String?,
      draftUrl: json['draft_url'] as String?,
      reviewedBySecretary: json['reviewed_by_secretary'] as String?,
      secretaryVerifiedAt: json['secretary_verified_at'] != null
          ? DateTime.parse(json['secretary_verified_at'] as String)
          : null,
      invoiceDescription: json['invoice_description'] as String?,
      invoiceDueDate: json['invoice_due_date'] != null
          ? DateTime.parse(json['invoice_due_date'] as String)
          : null,
      invoiceCreatedAt: json['invoice_created_at'] != null
          ? DateTime.parse(json['invoice_created_at'] as String)
          : null,
      captainUnavailable: json['captain_unavailable'] as bool? ?? false,
      approverId: json['approver_id'] as String?,
      approverRole: json['approver_role'] as String?,
      captainApprovedAt: json['captain_approved_at'] != null
          ? DateTime.parse(json['captain_approved_at'] as String)
          : null,
      userName: json['username'] as String?,
      userFullName: json['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'document_type': documentType,
      'purpose': purpose,
      'document_data': documentData,
      'request_status': requestStatus,
      'rejection_reason': rejectionReason,
      'payment_amount': paymentAmount,
      'payment_receipt_url': paymentReceiptUrl,
      'payment_status': paymentStatus,
      'payment_verified_at': paymentVerifiedAt?.toIso8601String(),
      'payment_verified_by': paymentVerifiedBy,
      'payment_rejection_reason': paymentRejectionReason,
      'document_url': documentUrl,
      'generated_document_url': generatedDocumentUrl,
      'final_document_url': finalDocumentUrl,
      'document_id': documentId,
      'verification_token': verificationToken,
      'qr_url': qrUrl,
      'e_receipt_url': eReceiptUrl,
      'document_hash': documentHash,
      'payment_method': paymentMethod,
      'payment_reference_number': paymentReferenceNumber,
      'payment_required': paymentRequired,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'released_by': releasedBy,
      'released_at': releasedAt?.toIso8601String(),
      'release_method': releaseMethod,
      'requested_at': requestedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'expires_at': expiresAt?.toIso8601String(),
      'single_use': singleUse,
      'max_uses': maxUses,
      'use_count': useCount,
      'used_at': usedAt?.toIso8601String(),
    };
  }

  DocumentRequest copyWith({
    String? id,
    String? userId,
    String? documentType,
    String? purpose,
    Map<String, dynamic>? documentData,
    String? requestStatus,
    String? rejectionReason,
    double? paymentAmount,
    String? paymentReceiptUrl,
    String? paymentStatus,
    DateTime? paymentVerifiedAt,
    String? paymentVerifiedBy,
    String? paymentRejectionReason,
    String? documentUrl,
    String? generatedDocumentUrl,
    String? finalDocumentUrl,
    String? documentId,
    String? verificationToken,
    String? qrUrl,
    String? eReceiptUrl,
    String? documentHash,
    String? paymentMethod,
    String? paymentReferenceNumber,
    bool? paymentRequired,
    String? approvedBy,
    DateTime? approvedAt,
    String? releasedBy,
    DateTime? releasedAt,
    String? releaseMethod,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    DateTime? expiresAt,
    bool? singleUse,
    int? maxUses,
    int? useCount,
    DateTime? usedAt,
    String? userName,
    String? userFullName,
  }) {
    return DocumentRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      documentType: documentType ?? this.documentType,
      purpose: purpose ?? this.purpose,
      documentData: documentData ?? this.documentData,
      requestStatus: requestStatus ?? this.requestStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentReceiptUrl: paymentReceiptUrl ?? this.paymentReceiptUrl,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentVerifiedAt: paymentVerifiedAt ?? this.paymentVerifiedAt,
      paymentVerifiedBy: paymentVerifiedBy ?? this.paymentVerifiedBy,
      paymentRejectionReason:
          paymentRejectionReason ?? this.paymentRejectionReason,
      documentUrl: documentUrl ?? this.documentUrl,
      generatedDocumentUrl: generatedDocumentUrl ?? this.generatedDocumentUrl,
      finalDocumentUrl: finalDocumentUrl ?? this.finalDocumentUrl,
      documentId: documentId ?? this.documentId,
      verificationToken: verificationToken ?? this.verificationToken,
      qrUrl: qrUrl ?? this.qrUrl,
      eReceiptUrl: eReceiptUrl ?? this.eReceiptUrl,
      documentHash: documentHash ?? this.documentHash,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReferenceNumber:
          paymentReferenceNumber ?? this.paymentReferenceNumber,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      releasedBy: releasedBy ?? this.releasedBy,
      releasedAt: releasedAt ?? this.releasedAt,
      releaseMethod: releaseMethod ?? this.releaseMethod,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      expiresAt: expiresAt ?? this.expiresAt,
      singleUse: singleUse ?? this.singleUse,
      maxUses: maxUses ?? this.maxUses,
      useCount: useCount ?? this.useCount,
      usedAt: usedAt ?? this.usedAt,
      paymentParsedAt: paymentParsedAt ?? this.paymentParsedAt,
      paymentParsedConfidence: paymentParsedConfidence ?? this.paymentParsedConfidence,
      paymentParseError: paymentParseError ?? this.paymentParseError,
      receiptParse: receiptParse ?? this.receiptParse,
      userName: userName ?? this.userName,
      userFullName: userFullName ?? this.userFullName,
    );
  }

  bool get isSubmitted => requestStatus == DocStatus.submitted;
  bool get isDraftGenerated => requestStatus == DocStatus.draftGenerated;
  bool get isNeedsRevision => requestStatus == DocStatus.needsRevision;
  bool get isVerifiedForPayment =>
      requestStatus == DocStatus.verifiedForPayment;
  bool get isInvoiced => requestStatus == DocStatus.invoiced;
  bool get isPaymentSubmitted => requestStatus == DocStatus.paymentSubmitted;
  bool get isPaymentConfirmed => requestStatus == DocStatus.paymentConfirmed;
  bool get isForApproval => requestStatus == DocStatus.forApproval;
  bool get isApproved =>
      requestStatus == DocStatus.approved ||
      requestStatus == DocStatus.approvedForRelease;
  bool get isReleased => requestStatus == DocStatus.released;
  bool get isRejected => requestStatus == DocStatus.rejected;
  bool get isCancelled => requestStatus == DocStatus.cancelled;
  // Legacy compat
  bool get isPendingPayment =>
      requestStatus == DocStatus.pendingPayment ||
      requestStatus == DocStatus.invoiced;
  bool get isPendingReview =>
      requestStatus == DocStatus.pendingReview ||
      requestStatus == DocStatus.submitted;
  bool get isGenerated => isDraftGenerated;
  bool get isPending => isPendingPayment || isPendingReview;

  /// Still moving through the pipeline (not yet released, rejected, or
  /// cancelled). This is the canonical "pending" for the citizen views — the
  /// narrow legacy [isPending] misses draft/invoice/payment/approval stages.
  bool get isInProgress => !isReleased && !isRejected && !isCancelled;

  /// Finished successfully: approved (incl. awaiting release) or released.
  /// The live captain flow ends at `released`, so a plain [isApproved] check
  /// never counts completed documents.
  bool get isApprovedOrReleased => isApproved || isReleased;

  bool get isPaymentPending => paymentStatus == 'pending';
  bool get isPaymentVerified => paymentStatus == 'verified';
  bool get isPaymentRejected => paymentStatus == 'rejected';

  bool get hasExpiry => expiresAt != null;
  bool get isExpired => expiresAt != null && Helpers.now().isAfter(expiresAt!);
  int? get remainingUses {
    if (maxUses == null) return null;
    final left = maxUses! - useCount;
    return left < 0 ? 0 : left;
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

  String get statusDisplay {
    switch (requestStatus) {
      case DocStatus.submitted:
        return 'Submitted';
      case DocStatus.draftGenerated:
        return 'Draft Generated';
      case DocStatus.needsRevision:
        return 'Needs Revision';
      case DocStatus.verifiedForPayment:
        return 'Verified for Payment';
      case DocStatus.invoiced:
        return 'Invoiced / Awaiting Payment';
      case DocStatus.paymentSubmitted:
        return 'Payment Submitted';
      case DocStatus.paymentRejected:
        return 'Payment Rejected';
      case DocStatus.paymentConfirmed:
        return 'Payment Confirmed';
      case DocStatus.forApproval:
        return 'For Approval';
      case DocStatus.approved:
        return 'Approved';
      case DocStatus.released:
        return 'Released';
      case DocStatus.rejected:
        return 'Rejected';
      case DocStatus.cancelled:
        return 'Cancelled';
      case DocStatus.pendingReview:
        return 'Pending Review';
      case DocStatus.pendingPayment:
        return 'Pending Payment';
      case DocStatus.approvedForRelease:
        return 'Approved';
      default:
        return requestStatus;
    }
  }

  String get statusColor {
    switch (requestStatus) {
      case DocStatus.submitted:
      case DocStatus.draftGenerated:
      case DocStatus.verifiedForPayment:
      case DocStatus.paymentSubmitted:
      case DocStatus.forApproval:
        return 'blue';
      case DocStatus.needsRevision:
      case DocStatus.invoiced:
        return 'orange';
      case DocStatus.paymentConfirmed:
      case DocStatus.approved:
      case DocStatus.approvedForRelease:
        return 'green';
      case DocStatus.released:
        return 'teal';
      case DocStatus.paymentRejected:
      case DocStatus.rejected:
      case DocStatus.cancelled:
        return 'red';
      default:
        return 'grey';
    }
  }
}
