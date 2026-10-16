import 'dart:io';

import 'package:intl/intl.dart';
import 'package:guin_app/automation/automation_constants.dart';
import 'package:guin_app/automation/document_data_validator.dart';
import 'package:guin_app/automation/fee_assessor.dart';
import 'package:guin_app/automation/pipeline_rules.dart';
import 'package:guin_app/automation/release_payload.dart';
import 'package:guin_app/models/barangay_config.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/services/barangay_service.dart';
import 'package:guin_app/services/document_service.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/services/pdf_service.dart';
import 'package:guin_app/services/user_service.dart';

/// Outcome of an automated pipeline step.
class AutomationOutcome {
  AutomationOutcome({
    required this.processed,
    this.finalStatus,
    this.message,
    this.errors = const [],
    this.pdfGenerated = false,
  });

  final bool processed;
  final String? finalStatus;
  final String? message;
  final List<String> errors;
  final bool pdfGenerated;

  bool get hasErrors => errors.isNotEmpty;
}

/// Orchestrates mechanical document-processing steps.
///
/// Human decisions remain required for:
/// - captain / kagawad final approval and rejection
/// - treasurer payment confirmation / rejection
/// - secretary content revision
/// - registration, fees, settings, incident triage
class DocumentAutomationService {
  DocumentAutomationService({
    DocumentService? documentService,
    NotificationService? notificationService,
    BarangayService? barangayService,
    UserService? userService,
  })  : _documentService = documentService ?? DocumentService(),
        _notificationService = notificationService ?? NotificationService(),
        _barangayService = barangayService ?? BarangayService(),
        _userService = userService ?? UserService();

  final DocumentService _documentService;
  final NotificationService _notificationService;
  final BarangayService _barangayService;
  final UserService _userService;

  /// Validate intake data using pure rules (no backend).
  static ValidationResult validateIntake({
    required String documentType,
    required String purpose,
    required Map<String, dynamic> documentData,
  }) {
    return DocumentDataValidator.validate(
      documentType: documentType,
      purpose: purpose,
      documentData: documentData,
    );
  }

  /// Assess fee from a fee map (pure).
  static FeeAssessment assessFee(
    String documentType,
    Map<String, double> feesByType,
  ) {
    return FeeAssessor.assess(
      documentType: documentType,
      feesByType: feesByType,
    );
  }

  /// Convert a fee list into the map shape FeeAssessor expects.
  static Map<String, double> feeMapFromList(
    List<({String documentType, double feeAmount})> fees,
  ) {
    return {
      for (final f in fees) f.documentType: f.feeAmount,
    };
  }

  /// After a request is created: auto-draft when possible, then route free
  /// docs to for_approval and paid docs to invoiced.
  Future<AutomationOutcome> afterSubmission({
    required DocumentRequest request,
    bool allowAutoDraft = true,
  }) async {
    final validation = DocumentDataValidator.validate(
      documentType: request.documentType,
      purpose: request.purpose,
      documentData: request.documentData,
    );

    if (!validation.isValid) {
      await _safeNotify(
        userId: request.userId,
        title: 'Request needs revision',
        message:
            'Your ${AutomationConstants.labelFor(request.documentType)} request is missing required information: ${validation.summary}',
        type: 'system',
      );
      return AutomationOutcome(
        processed: false,
        finalStatus: request.requestStatus,
        message: validation.summary,
        errors: validation.errors,
      );
    }

    if (!allowAutoDraft) {
      return AutomationOutcome(
        processed: false,
        finalStatus: request.requestStatus,
        message: 'Auto-draft disabled; secretary queue retained',
      );
    }

    // Attempt auto draft generation. PDF generation may be unavailable on web.
    var draftUrl = request.draftUrl;
    var pdfGenerated = false;
    try {
      draftUrl = await _generateAndUploadDraft(request);
      pdfGenerated = draftUrl != null;
    } catch (_) {
      draftUrl = null;
      pdfGenerated = false;
    }

    if (draftUrl != null) {
      await _documentService.recordDraftGenerated(
        requestId: request.id,
        secretaryId: null, // automation acts as system, not as the citizen
        draftUrl: draftUrl,
      );
    }

    final feeRequired = request.paymentRequired || request.paymentAmount > 0;
    final nextStatus = PipelineRules.nextStatusAfterDraft(feeRequired: feeRequired);

    if (draftUrl == null && nextStatus == DocStatus.forApproval) {
      // Cannot auto-advance free docs without a generated draft record.
      return AutomationOutcome(
        processed: false,
        finalStatus: DocStatus.submitted,
        message:
            'Auto-draft unavailable (often web). Request left for secretary processing.',
        pdfGenerated: false,
      );
    }

    // Paid requests require a human secretary to review the request and send
    // the invoice. Automation only prepares the draft and never reaches
    // `invoiced` on its own; free docs may still auto-advance.
    if (feeRequired) {
      final leftStatus =
          draftUrl != null ? DocStatus.draftGenerated : DocStatus.submitted;

      await _safeNotify(
        userId: request.userId,
        title: 'Request under review',
        message:
            'Your ${AutomationConstants.labelFor(request.documentType)} request is awaiting barangay review. You will receive an invoice with payment instructions once it is verified.',
        type: 'system',
      );

      // Generate initial e-receipt (fire-and-forget, never blocks)
      try {
        await _generateAndUploadERecceipt(
          request: request,
          paymentReceiptUrl: null,
        );
      } catch (_) {}

      return AutomationOutcome(
        processed: true,
        finalStatus: leftStatus,
        message: draftUrl != null
            ? 'Draft generated; awaiting secretary review and invoice'
            : 'Awaiting secretary review',
        pdfGenerated: pdfGenerated,
      );
    }

    await _documentService.markVerifiedForPayment(
      requestId: request.id,
      secretaryId: null, // automation acts as system, not as a secretary
      paymentRequired: false,
    );

    await _safeNotify(
      userId: request.userId,
      title: 'Request ready for approval',
      message:
          'Your ${AutomationConstants.labelFor(request.documentType)} request was verified and forwarded for final approval.',
      type: 'request_approved',
    );

    // Generate initial e-receipt (fire-and-forget, never blocks)
    try {
      await _generateAndUploadERecceipt(
        request: request,
        paymentReceiptUrl: null,
      );
    } catch (_) {}

    return AutomationOutcome(
      processed: true,
      finalStatus: nextStatus,
      message: 'Auto-verified; forwarded for captain approval',
      pdfGenerated: pdfGenerated,
    );
  }

  /// After citizen uploads a payment receipt: canonicalize status + notify.
  Future<AutomationOutcome> afterPaymentReceipt({
    required DocumentRequest request,
    required String receiptUrl,
  }) async {
    final preCheck = PipelineRules.preCheckPaymentReceipt(
      receiptUrl: receiptUrl,
      expectedAmount: request.paymentAmount,
      recordedAmount: request.paymentAmount,
    );

    if (!preCheck.isValid) {
      return AutomationOutcome(
        processed: false,
        finalStatus: request.requestStatus,
        message: preCheck.errors.join('; '),
        errors: preCheck.errors,
      );
    }

    await _documentService.submitPaymentReceipt(
      requestId: request.id,
      receiptUrl: receiptUrl,
    );
    await _documentService.markPaymentSubmitted(requestId: request.id);

    await _safeNotify(
      userId: request.userId,
      title: 'Payment receipt received',
      message:
          'Your payment receipt for ${AutomationConstants.labelFor(request.documentType)} is awaiting treasurer verification.',
      type: 'system',
    );

    // Update e-receipt with payment info (fire-and-forget, never blocks)
    try {
      await _generateAndUploadERecceipt(
        request: request,
        paymentReceiptUrl: receiptUrl,
      );
    } catch (_) {}

    return AutomationOutcome(
      processed: true,
      finalStatus: DocStatus.paymentSubmitted,
      message: 'Payment receipt recorded for treasurer verification',
    );
  }

  /// After treasurer confirms payment (human decision already made).
  Future<void> afterPaymentConfirmed({
    required DocumentRequest request,
    required String treasurerId,
    String? method,
    String? referenceNumber,
  }) async {
    await _documentService.treasurerConfirmPayment(
      requestId: request.id,
      treasurerId: treasurerId,
      method: method,
      referenceNumber: referenceNumber,
    );
    await _safeNotify(
      userId: request.userId,
      title: 'Payment verified',
      message:
          'Payment for your ${AutomationConstants.labelFor(request.documentType)} was verified and forwarded for final approval.',
      type: 'payment_verified',
    );
  }

  /// After treasurer rejects payment (human decision already made).
  Future<void> afterPaymentRejected({
    required DocumentRequest request,
    required String treasurerId,
    required String reason,
  }) async {
    await _documentService.treasurerRejectPayment(
      requestId: request.id,
      treasurerId: treasurerId,
      reason: reason,
    );
    await _safeNotify(
      userId: request.userId,
      title: 'Payment rejected',
      message:
          'Payment for your ${AutomationConstants.labelFor(request.documentType)} was rejected: $reason',
      type: 'payment_rejected',
    );
  }

  /// After captain/kagawad APPROVE (human): generate final PDF, upload,
  /// release with verification identity, notify citizen.
  Future<AutomationOutcome> afterCaptainApproved({
    required DocumentRequest request,
    required String approverId,
    required String approverRole,
    required String citizenName,
    required BarangayConfig config,
    required UserProfile citizen,
    String? approverName,
  }) async {
    final now = DateTime.now();
    var payload = ReleasePayload.buildIdentity(
      requestId: request.id,
      sequence: now.millisecondsSinceEpoch,
      releasedBy: approverId,
      now: now,
      singleUse: false,
      maxUses: null,
    );

    final pdfFile = await generateFinalPdf(
      request: request,
      config: config,
      citizen: citizen,
      approverName: approverName ?? approverNameFallback(approverRole),
      documentId: payload.documentId,
      qrUrl: payload.qrUrl,
      expiresAtLabel: payload.expiresAt != null
          ? DateFormat('MMM dd, yyyy').format(payload.expiresAt!)
          : null,
    );

    try {
      final bytes = await pdfFile.readAsBytes();
      payload = payload.withContentHash(bytes);

      final docUrl = await _documentService.uploadGeneratedDocument(
        request.id,
        pdfFile,
      );
      await _documentService.releaseDocument(
        requestId: request.id,
        releasedBy: approverId,
        finalDocumentUrl: docUrl,
        citizenName: citizenName,
        payload: payload,
      );

      await _safeNotify(
        userId: request.userId,
        title: 'Document released',
        message:
            'Your ${AutomationConstants.labelFor(request.documentType)} is ready. You can download it and verify it online.',
        type: 'request_released',
      );

      // Generate final e-receipt with release info (fire-and-forget, never blocks)
      try {
        await _generateAndUploadERecceipt(
          request: request,
          paymentReceiptUrl: request.paymentReceiptUrl,
          documentId: payload.documentId,
          qrUrl: payload.qrUrl,
          verificationToken: payload.verificationToken,
          expiresAtLabel: payload.expiresAt != null
              ? DateFormat('MMM dd, yyyy').format(payload.expiresAt!)
              : null,
        );
      } catch (_) {}

      return AutomationOutcome(
        processed: true,
        finalStatus: DocStatus.released,
        message: 'Document released with QR verification',
        pdfGenerated: true,
      );
    } finally {
      try {
        await pdfFile.delete();
      } catch (_) {}
    }
  }

  /// After captain/kagawad REJECT (human reason already provided).
  Future<void> afterCaptainRejected({
    required DocumentRequest request,
    required String approverId,
    required String approverRole,
    required String reason,
  }) async {
    await _documentService.captainReject(
      requestId: request.id,
      approverId: approverId,
      approverRole: approverRole,
      reason: reason,
    );
    await _safeNotify(
      userId: request.userId,
      title: 'Request rejected',
      message:
          'Your ${AutomationConstants.labelFor(request.documentType)} was rejected: $reason',
      type: 'request_rejected',
    );
  }

  /// Flag overdue invoices (mechanical). Does not auto-approve anything.
  Future<List<DocumentRequest>> findOverdueInvoices({DateTime? now}) {
    final cutoff = now ?? DateTime.now();
    return _documentService
        .getPendingPayments()
        .then(
          (requests) =>
              requests.where((r) => PipelineRules.isInvoiceOverdue(
                    status: r.requestStatus,
                    dueDate: r.invoiceDueDate,
                    now: cutoff,
                  )).toList(),
        );
  }

  Future<void> notifyOverdueInvoices({DateTime? now}) async {
    final overdue = await findOverdueInvoices(now: now);
    for (final request in overdue) {
      await _safeNotify(
        userId: request.userId,
        title: 'Payment overdue',
        message:
            'Invoice for your ${AutomationConstants.labelFor(request.documentType)} is past due. Please complete payment to continue processing.',
        type: 'system',
      );
    }
  }

  /// Generate a draft PDF for a request. Returns null if generation fails
  /// (e.g. web platform without dart:io PDF write path).
  Future<String?> _generateAndUploadDraft(DocumentRequest request) async {
    final config = await _barangayService.getBarangayConfig();
    if (config == null) return null;
    final citizen = await _userService.getUserProfile(request.userId);
    if (citizen == null) return null;

    final pdfFile = await generateDraftPdf(
      request: request,
      config: config,
      citizen: citizen,
    );
    try {
      return await _documentService.uploadGeneratedDocument(
        request.id,
        pdfFile,
      );
    } finally {
      try {
        await pdfFile.delete();
      } catch (_) {}
    }
  }

  /// Generate and upload an e-receipt PDF for a request.
  /// Returns the public URL or null if generation fails.
  Future<String?> _generateAndUploadERecceipt({
    required DocumentRequest request,
    String? paymentReceiptUrl,
    String? documentId,
    String? qrUrl,
    String? verificationToken,
    String? expiresAtLabel,
  }) async {
    final config = await _barangayService.getBarangayConfig();
    if (config == null) return null;
    final citizen = await _userService.getUserProfile(request.userId);
    if (citizen == null) return null;

    final pdfFile = await PdfService.generateERecceipt(
      request: request,
      config: config,
      userFullName: citizen.fullName,
      userAddress: citizen.address,
      paymentReceiptUrl: paymentReceiptUrl,
      documentId: documentId,
      qrUrl: qrUrl,
      verificationToken: verificationToken,
      expiresAtLabel: expiresAtLabel,
    );
    try {
      final url = await _documentService.uploadERecceipt(request.id, pdfFile);
      await _documentService.updateERecceiptUrl(
        requestId: request.id,
        eReceiptUrl: url,
      );
      return url;
    } catch (_) {
      return null;
    } finally {
      try {
        await pdfFile.delete();
      } catch (_) {}
    }
  }

  /// Public PDF generation used by automation and screens.
  static Future<File> generateDraftPdf({
    required DocumentRequest request,
    required BarangayConfig config,
    required UserProfile citizen,
  }) {
    return _generatePdf(
      request: request,
      config: config,
      citizen: citizen,
      isDraft: true,
      approverName: null,
    );
  }

  /// Public final PDF generation (post human approval).
  static Future<File> generateFinalPdf({
    required DocumentRequest request,
    required BarangayConfig config,
    required UserProfile citizen,
    String? approverName,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) {
    return _generatePdf(
      request: request,
      config: config,
      citizen: citizen,
      isDraft: false,
      approverName: approverName,
      documentId: documentId,
      qrUrl: qrUrl,
      expiresAtLabel: expiresAtLabel,
      copyNotice: copyNotice,
    );
  }

  static Future<File> _generatePdf({
    required DocumentRequest request,
    required BarangayConfig config,
    required UserProfile citizen,
    required bool isDraft,
    required String? approverName,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) {
    switch (request.documentType) {
      case 'barangay_clearance':
        return PdfService.generateBarangayClearance(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'indigency':
        return PdfService.generateIndigencyCertificate(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'cedula':
        return PdfService.generateCedula(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          dateOfBirth:
              '${citizen.dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${citizen.dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${citizen.dateOfBirth.day.toString().padLeft(2, '0')}',
          placeOfBirth: citizen.placeOfBirth,
          gender: citizen.gender,
          profilePhotoUrl: citizen.profilePhotoUrl,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'barangay_id':
        return PdfService.generateBarangayId(
          userId: citizen.id,
          fullName: citizen.fullName,
          address: citizen.address,
          dateOfBirth:
              '${citizen.dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${citizen.dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${citizen.dateOfBirth.day.toString().padLeft(2, '0')}',
          contactNumber: citizen.phoneNumber,
          emergencyContactName:
              request.documentData['emergency_contact_name']?.toString() ??
                  request.documentData['contact_number']?.toString() ??
                  'N/A',
          emergencyContactNumber:
              request.documentData['emergency_contact_number']?.toString() ??
                  request.documentData['contact_number']?.toString() ??
                  'N/A',
          bloodType: request.documentData['blood_type']?.toString() ??
              'Unknown',
          config: config,
          profilePhotoUrl: citizen.profilePhotoUrl,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'business_clearance':
        return PdfService.generateBusinessClearance(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'certification':
        return PdfService.generateCertification(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'good_moral':
        return PdfService.generateGoodMoral(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'residency':
        return PdfService.generateResidency(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      case 'oath_undertaking':
        return PdfService.generateOathUndertaking(
          request: request,
          config: config,
          userFullName: citizen.fullName,
          userAddress: citizen.address,
          userAge: citizen.age,
          civilStatus: citizen.civilStatus,
          profilePhotoUrl: citizen.profilePhotoUrl,
          isDraft: isDraft,
          approverName: approverName,
          documentId: documentId,
          qrUrl: qrUrl,
          expiresAtLabel: expiresAtLabel,
          copyNotice: copyNotice,
        );
      default:
        throw Exception('Unknown document type: ${request.documentType}');
    }
  }

  /// Render a reprint of a citizen's saved/printed copy. Mirrors
  /// [_generateAndUploadDraft]'s service lookups. The caller owns the
  /// returned file (do not delete it here).
  Future<File> generatePrintableCopyPdf({
    required DocumentRequest request,
    required String documentId,
    required String qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
    String? approverName,
  }) async {
    final config = await _barangayService.getBarangayConfig();
    if (config == null) {
      throw Exception('Barangay configuration not found.');
    }
    final citizen = await _userService.getUserProfile(request.userId);
    if (citizen == null) {
      throw Exception('Citizen profile not found');
    }

    return generateFinalPdf(
      request: request,
      config: config,
      citizen: citizen,
      approverName: approverName ??
          (request.approverRole != null
              ? approverNameFallback(request.approverRole!)
              : null),
      documentId: documentId,
      qrUrl: qrUrl,
      expiresAtLabel: expiresAtLabel,
      copyNotice: copyNotice,
    );
  }

  static String approverNameFallback(String role) {
    switch (role) {
      case 'captain':
        return 'Barangay Captain';
      case 'kagawad_representative':
        return 'Kagawad Representative';
      case 'admin':
        return 'Administrator';
      default:
        return 'Barangay Official';
    }
  }

  Future<void> _safeNotify({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );
    } catch (_) {
      // Notifications must never block the pipeline.
    }
  }
}

/// Builds a ReleasePayload without touching Supabase (for reuse/tests).
/// Note: documentHash is empty until [ReleasePayload.withContentHash] is called.
ReleasePayload buildReleasePayload({
  required String requestId,
  required String releasedBy,
  required String finalDocumentUrl,
  DateTime? now,
  String verificationBaseUrl = 'https://citeease-verify.vercel.app',
}) {
  final timestamp = now ?? DateTime.now();
  return ReleasePayload.buildIdentity(
    requestId: requestId,
    sequence: timestamp.millisecondsSinceEpoch,
    releasedBy: releasedBy,
    now: timestamp,
    verificationBaseUrl: verificationBaseUrl,
  );
}
