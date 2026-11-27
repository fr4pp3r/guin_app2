import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/automation/release_payload.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/screens/admin/document_request_detail_screen.dart';
import 'package:guin_app/services/pdf_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

class CaptainApprovalScreen extends StatefulWidget {
  const CaptainApprovalScreen({super.key, this.focusId});

  /// ID of one document to auto-open the review detail immediately after load.
  final String? focusId;

  @override
  State<CaptainApprovalScreen> createState() => _CaptainApprovalScreenState();
}

class _CaptainApprovalScreenState extends State<CaptainApprovalScreen> {
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<DocumentProvider>().loadForApproval();
    _tryOpenFocus(widget.focusId);
  }

  Future<void> _tryOpenFocus(String? id) async {
    if (id == null || _focusHandled || !mounted) return;
    final dp = context.read<DocumentProvider>();
    final matches = dp.forApproval.where((r) => r.id == id).toList();
    // Stale reference (row already released/deleted): stay on the list.
    if (matches.isEmpty || !mounted) return;
    setState(() => _focusHandled = true);
    _openRequestReview(matches.first);
  }

  // ── Approve + Release with e-signature ──────────────────────────────

  Future<void> _handleApprove(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb) {
      Helpers.showErrorSnackBar(context, l10n.acapPdfWebUnavailable);
      return;
    }

    final auth = context.read<AuthProvider>();
    final role = auth.userProfile!.role;

    // Kagawad can only approve when Captain is unavailable
    if (AppRoles.isKagawad(role)) {
      final ok = await Helpers.showConfirmDialog(
        context,
        title: l10n.acapKagawadApproval,
        message: l10n.acapKagawadApprovalMessage(''),
      );
      if (!ok) return;
    } else {
      final ok = await Helpers.showConfirmDialog(
        context,
        title: l10n.acapApproveAndSign,
        message: l10n.acapApproveAndSignMessage(
          request.documentTypeDisplay,
          '',
        ),
      );
      if (!ok) return;
    }

    if (!mounted) return;
    final dp = context.read<DocumentProvider>();
    final bp = context.read<BarangayProvider>();

    Helpers.showLoadingDialog(context, l10n.acapGeneratingFinalDocument);

    try {
      await bp.loadConfig();
      final config = bp.config;
      if (config == null) throw Exception('Barangay configuration not found.');

      final userService = UserService();
      final citizen = await userService.getUserProfile(request.userId);
      if (citizen == null) throw Exception('Citizen profile not found');

      final approverName = auth.userProfile!.fullName;
      final approverSignatureUrl = auth.userProfile!.signatureUrl;

      // Build verification identity FIRST so the PDF can embed the QR + expiry.
      // Uses default validity: January 1 of the incoming year.
      final payload = ReleasePayload.buildIdentity(
        requestId: request.id,
        sequence: Helpers.now().millisecondsSinceEpoch,
        releasedBy: auth.userProfile!.id,
        now: Helpers.now(),
        singleUse: false,
        maxUses: null,
      );
      final expiresAtLabel = payload.expiresAt != null
          ? DateFormat('MMM dd, yyyy').format(Helpers.toPh(payload.expiresAt!))
          : null;

      // Generate FINAL PDF with e-signature
      File pdfFile;
      switch (request.documentType) {
        case 'barangay_clearance':
          pdfFile = await PdfService.generateBarangayClearance(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'indigency':
          pdfFile = await PdfService.generateIndigencyCertificate(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'cedula':
          pdfFile = await PdfService.generateCedula(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            dateOfBirth: DateFormat(
              'MMMM dd, yyyy',
            ).format(Helpers.toPh(citizen.dateOfBirth)),
            placeOfBirth: citizen.placeOfBirth,
            gender: citizen.gender,
            profilePhotoUrl: citizen.profilePhotoUrl,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'barangay_id':
          pdfFile = await PdfService.generateBarangayId(
            userId: citizen.id,
            fullName: citizen.fullName,
            address: citizen.address,
            dateOfBirth: DateFormat(
              'MMMM dd, yyyy',
            ).format(Helpers.toPh(citizen.dateOfBirth)),
            contactNumber: citizen.phoneNumber,
            emergencyContactName:
                request.documentData['emergency_contact_name']?.toString() ??
                'N/A',
            emergencyContactNumber:
                request.documentData['emergency_contact_number']?.toString() ??
                'N/A',
            bloodType:
                request.documentData['blood_type']?.toString() ?? 'Unknown',
            config: config,
            profilePhotoUrl: citizen.profilePhotoUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'business_clearance':
          pdfFile = await PdfService.generateBusinessClearance(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'certification':
          pdfFile = await PdfService.generateCertification(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'good_moral':
          pdfFile = await PdfService.generateGoodMoral(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'residency':
          pdfFile = await PdfService.generateResidency(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        case 'oath_undertaking':
          pdfFile = await PdfService.generateOathUndertaking(
            request: request,
            config: config,
            userFullName: citizen.fullName,
            userAddress: citizen.address,
            userAge: citizen.age,
            civilStatus: citizen.civilStatus,
            profilePhotoUrl: citizen.profilePhotoUrl,
            isDraft: false,
            approverName: approverName,
            approverSignatureUrl: approverSignatureUrl,
            documentId: payload.documentId,
            qrUrl: payload.qrUrl,
            expiresAtLabel: expiresAtLabel,
          );
          break;
        default:
          throw Exception('Unknown document type: ${request.documentType}');
      }

      final bytes = await pdfFile.readAsBytes();
      final finalPayload = payload.withContentHash(bytes);

      await dp.captainApproveAndRelease(
        requestId: request.id,
        approverId: auth.userProfile!.id,
        approverRole: role,
        finalDocument: pdfFile,
        citizenName: citizen.fullName,
        payload: finalPayload,
      );
      await pdfFile.delete();

      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(context, l10n.acapApprovedSignedReleased);
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        l10n.acapErrorFormatted(Helpers.parseSupabaseError(e.toString())),
      );
    }
  }

  // ── Reject ──────────────────────────────────────────────────────────

  Future<void> _handleReject(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.acapRejectDocument),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.acapRejectingDocument(request.documentTypeDisplay)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.acapReasonForRejection,
                hintText: l10n.commonProvideReason,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, l10n.commonPleaseProvideReason);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonReject),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final dp = context.read<DocumentProvider>();
    final auth = context.read<AuthProvider>();
    Helpers.showLoadingDialog(context, l10n.acapRejecting);
    try {
      await dp.captainReject(
        requestId: request.id,
        approverId: auth.userProfile!.id,
        approverRole: auth.userProfile!.role,
        reason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(context, l10n.acapRequestRejected);
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(e.toString()),
      );
    }
  }

  // ── Review page ─────────────────────────────────────────────────────

  /// The decision buttons live only on the review page — the card just
  /// hands over its handlers, unchanged, as action descriptors.
  void _openRequestReview(DocumentRequest r) {
    final l10n = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentRequestDetailScreen(
          request: r,
          actions: [
            RequestAction(
              label: l10n.commonReject,
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              onPressed: () => _handleReject(r),
            ),
            RequestAction(
              label: l10n.acapSignAndRelease,
              icon: Icons.draw_outlined,
              color: const Color(0xFF0D47A1),
              filled: true,
              onPressed: () => _handleApprove(r),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dp = context.watch<DocumentProvider>();
    final auth = context.watch<AuthProvider>();
    final roleLabel = AppRoles.displayName(auth.userProfile?.role ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.approval_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.acapTitle(roleLabel),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.acapSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _NotificationsBell(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: dp.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dp.forApproval.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.acapNoDocumentsAwaiting,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      itemCount: dp.forApproval.length,
                      itemBuilder: (_, i) =>
                          _buildApprovalCard(dp.forApproval[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(DocumentRequest r) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _openRequestReview(r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _docIcon(r.documentType),
                        color: Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.documentTypeDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.acapRequestedAt(
                              Helpers.formatDate(r.requestedAt),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.acapForApproval,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.userFullName != null || r.userName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              r.userFullName ?? r.userName ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      l10n.commonPurpose,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.purpose,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (r.paymentRequired) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.acapPaymentLine(
                              r.paymentAmount.toStringAsFixed(2),
                              r.paymentStatus,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.acapReviewRequest,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: Color(0xFF1976D2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'barangay_clearance':
        return Icons.verified_user_outlined;
      case 'indigency':
        return Icons.people_outline;
      case 'barangay_id':
        return Icons.badge_outlined;
      case 'business_clearance':
        return Icons.storefront;
      case 'certification':
        return Icons.verified;
      case 'oath_undertaking':
        return Icons.assignment_turned_in;
      case 'good_moral':
        return Icons.workspace_premium;
      case 'residency':
        return Icons.home;
      default:
        return Icons.description_outlined;
    }
  }
}

/// Bell with unread badge for the gradient header. The officials' dashboard
/// owns the load/subscribe lifecycle for NotificationProvider — this only
/// reads `unreadCount` for display.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = context.watch<NotificationProvider>().unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: l10n.notificationsTitle,
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
