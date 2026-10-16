import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/screens/admin/document_request_detail_screen.dart';
import 'package:guin_app/services/pdf_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingRequests();
    });
  }

  Future<void> _loadPendingRequests() async {
    if (!mounted) return;
    await context.read<DocumentProvider>().loadPendingReviews();
  }

  // ── Generate DRAFT PDF ───────────────────────────────────────────────

  Future<void> _handleGenerateDraft(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb) {
      Helpers.showErrorSnackBar(
        context,
        l10n.asecPdfWebUnavailable,
      );
      return;
    }

    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.asecGenerateDraft,
      message: l10n.asecGenerateDraftMessage(request.documentTypeDisplay),
    );
    if (!confirm) return;

    final documentProvider = context.read<DocumentProvider>();
    final barangayProvider = context.read<BarangayProvider>();
    final authProvider = context.read<AuthProvider>();

    Helpers.showLoadingDialog(context, l10n.asecGeneratingDraft);

    try {
      await barangayProvider.loadConfig();
      final config = barangayProvider.config;
      if (config == null) {
        throw Exception('Barangay configuration not found.');
      }

      final userService = UserService();
      final userProfile = await userService.getUserProfile(request.userId);
      if (userProfile == null) throw Exception('User profile not found');

      File pdfFile;
      switch (request.documentType) {
        case 'barangay_clearance':
          pdfFile = await PdfService.generateBarangayClearance(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
            isDraft: true,
          );
          break;
        case 'indigency':
          pdfFile = await PdfService.generateIndigencyCertificate(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'cedula':
          pdfFile = await PdfService.generateCedula(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            dateOfBirth: DateFormat(
              'MMMM dd, yyyy',
            ).format(userProfile.dateOfBirth),
            placeOfBirth: userProfile.placeOfBirth,
            gender: userProfile.gender,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'barangay_id':
          pdfFile = await PdfService.generateBarangayId(
            userId: userProfile.id,
            fullName: userProfile.fullName,
            address: userProfile.address,
            dateOfBirth: DateFormat(
              'MMMM dd, yyyy',
            ).format(userProfile.dateOfBirth),
            contactNumber: userProfile.phoneNumber,
            emergencyContactName:
                request.documentData['emergency_contact_name']?.toString() ??
                'N/A',
            emergencyContactNumber:
                request.documentData['emergency_contact_number']?.toString() ??
                'N/A',
            bloodType:
                request.documentData['blood_type']?.toString() ?? 'Unknown',
            config: config,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'business_clearance':
          pdfFile = await PdfService.generateBusinessClearance(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'certification':
          pdfFile = await PdfService.generateCertification(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'good_moral':
          pdfFile = await PdfService.generateGoodMoral(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'residency':
          pdfFile = await PdfService.generateResidency(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        case 'oath_undertaking':
          pdfFile = await PdfService.generateOathUndertaking(
            request: request,
            config: config,
            userFullName: userProfile.fullName,
            userAddress: userProfile.address,
            userAge: userProfile.age,
            civilStatus: userProfile.civilStatus,
            profilePhotoUrl: userProfile.profilePhotoUrl,
          );
          break;
        default:
          throw Exception('Unknown document type: ${request.documentType}');
      }

      await documentProvider.recordDraftGenerated(
        requestId: request.id,
        secretaryId: authProvider.userProfile!.id,
        draftDocument: pdfFile,
      );
      await pdfFile.delete();

      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(context, l10n.asecDraftGeneratedSuccess);
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        l10n.asecErrorFormatted(Helpers.parseSupabaseError(e.toString())),
      );
    }
  }

  // ── Request Revision ─────────────────────────────────────────────────

  Future<void> _handleRequestRevision(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.asecRequestRevision),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.asecRequestChangesToDocument(request.documentTypeDisplay),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.asecRevisionNotesForCitizen,
                hintText: l10n.asecRevisionNotesHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              if (notesCtrl.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, l10n.asecPleaseProvideNotes);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(l10n.asecSendRevision),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final documentProvider = context.read<DocumentProvider>();
    final authProvider = context.read<AuthProvider>();
    Helpers.showLoadingDialog(context, l10n.asecRequestingRevision);
    try {
      await documentProvider.requestRevision(
        requestId: request.id,
        secretaryId: authProvider.userProfile!.id,
        notes: notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        l10n.asecRevisionRequestedNotified,
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(e.toString()),
      );
    }
  }

  // ── Verify for Payment / Forward to Approval ─────────────────────────

  Future<void> _handleVerifyForPayment(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.asecVerifyForwardTitle,
      message: request.paymentRequired
          ? l10n.asecVerifyPaidMessage(
              request.paymentAmount.toStringAsFixed(2),
            )
          : l10n.asecVerifyNoPaymentMessage,
    );
    if (!confirm || !mounted) return;

    final documentProvider = context.read<DocumentProvider>();
    final authProvider = context.read<AuthProvider>();
    Helpers.showLoadingDialog(context, l10n.asecProcessing);
    try {
      await documentProvider.markVerifiedForPayment(
        requestId: request.id,
        secretaryId: authProvider.userProfile!.id,
        paymentRequired: request.paymentRequired,
      );
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        request.paymentRequired
            ? l10n.asecInvoiceSent
            : l10n.asecForwardedToCaptain,
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(e.toString()),
      );
    }
  }

  // ── Reject outright ──────────────────────────────────────────────────

  Future<void> _handleReject(DocumentRequest request) async {
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.asecRejectRequestTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.asecRejectingDocument(request.documentTypeDisplay),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.commonRejectionReason,
                hintText: l10n.asecProvideRejectionReasonHint,
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
                Helpers.showErrorSnackBar(
                  ctx,
                  l10n.commonPleaseProvideReason,
                );
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

    final documentProvider = context.read<DocumentProvider>();
    final authProvider = context.read<AuthProvider>();
    Helpers.showLoadingDialog(context, l10n.asecRejecting);
    try {
      await documentProvider.rejectRequest(
        requestId: request.id,
        adminId: authProvider.userProfile!.id,
        reason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(context, l10n.asecRequestRejected);
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

  /// The decision buttons live only on the review page — this builds the
  /// same status-dependent set the cards used to show inline and hands the
  /// handlers over unchanged as action descriptors.
  List<RequestAction> _actionsFor(DocumentRequest r) {
    final l10n = AppLocalizations.of(context);
    final status = r.requestStatus;
    if (status == DocStatus.submitted || status == DocStatus.pendingReview) {
      return [
        RequestAction(
          label: l10n.commonReject,
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          onPressed: () => _handleReject(r),
        ),
        RequestAction(
          label: l10n.asecGenerateDraft,
          icon: Icons.description_outlined,
          color: AppColors.primary,
          filled: true,
          onPressed: () => _handleGenerateDraft(r),
        ),
      ];
    }
    if (status == DocStatus.draftGenerated) {
      return [
        RequestAction(
          label: l10n.asecNeedsRevision,
          icon: Icons.edit_note,
          color: Colors.orange,
          onPressed: () => _handleRequestRevision(r),
        ),
        RequestAction(
          label: r.paymentRequired
              ? l10n.asecSendInvoice
              : l10n.asecForwardToCaptain,
          icon: Icons.verified_outlined,
          color: Colors.teal,
          filled: true,
          onPressed: () => _handleVerifyForPayment(r),
        ),
      ];
    }
    // e.g. needs_revision — the card showed a waiting banner, no actions.
    return const [];
  }

  void _openRequestReview(DocumentRequest r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentRequestDetailScreen(request: r, actions: _actionsFor(r)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dp = context.watch<DocumentProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                  Color(0xFF42A5F5),
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
                      Icons.rate_review_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.asecHeaderTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.asecHeaderSubtitle,
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
              onRefresh: _loadPendingRequests,
              child: dp.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dp.pendingReviews.isEmpty
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
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.asecNoPendingRequests,
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
                      itemCount: dp.pendingReviews.length,
                      itemBuilder: (_, i) =>
                          _buildRequestCard(dp.pendingReviews[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(DocumentRequest r) {
    final l10n = AppLocalizations.of(context);
    final status = r.requestStatus;
    final isSubmitted =
        status == DocStatus.submitted || status == DocStatus.pendingReview;
    final isDraft = status == DocStatus.draftGenerated;
    final isRevision = status == DocStatus.needsRevision;
    final isApproved = r.isApproved;

    Color statusColor;
    if (isSubmitted) {
      statusColor = Colors.blue;
    } else if (isDraft) {
      statusColor = Colors.teal;
    } else if (isRevision) {
      statusColor = Colors.orange;
    } else if (isApproved) {
      statusColor = AppColors.success;
    } else {
      statusColor = Colors.grey;
    }

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
                  color: statusColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getDocumentIcon(r.documentType),
                        color: statusColor,
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
                            l10n.asecRequestedAt(
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
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.statusDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
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
                    if (r.secretaryNotes != null &&
                        r.secretaryNotes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.asecRevisionNotes,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.secretaryNotes!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.asecReviewRequest,
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

  IconData _getDocumentIcon(String type) {
    switch (type) {
      case 'barangay_clearance':
        return Icons.verified_user_outlined;
      case 'indigency':
        return Icons.people_outline;
      case 'barangay_id':
        return Icons.badge_outlined;
      case 'cedula':
        return Icons.receipt_long;
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
