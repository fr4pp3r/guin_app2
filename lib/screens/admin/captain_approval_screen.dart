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
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

class CaptainApprovalScreen extends StatefulWidget {
  const CaptainApprovalScreen({super.key});

  @override
  State<CaptainApprovalScreen> createState() => _CaptainApprovalScreenState();
}

class _CaptainApprovalScreenState extends State<CaptainApprovalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<DocumentProvider>().loadForApproval();
  }

  // ── Approve + Release with e-signature ──────────────────────────────

  Future<void> _handleApprove(DocumentRequest request) async {
    if (kIsWeb) {
      Helpers.showErrorSnackBar(
        context,
        'PDF generation is not available on web. Use mobile or desktop.',
      );
      return;
    }

    // 1) Configure the release policy (expiry / single-use / use limit)
    //    BEFORE anything is generated. Dismissing the sheet aborts cleanly.
    final policy = await _showReleasePolicySheet();
    if (!mounted || policy == null) return;
    final policyLine = 'Release policy: ${_describePolicy(policy)}';

    final auth = context.read<AuthProvider>();
    final role = auth.userProfile!.role;

    // Kagawad can only approve when Captain is unavailable
    if (AppRoles.isKagawad(role)) {
      final ok = await Helpers.showConfirmDialog(
        context,
        title: 'Kagawad Approval',
        message:
            'You are approving as Kagawad Representative.\n\n'
            'This action is only allowed when the Captain is unavailable. '
            'This will be logged.\n\n'
            '$policyLine\n\nContinue?',
      );
      if (!ok) return;
    } else {
      final ok = await Helpers.showConfirmDialog(
        context,
        title: 'Approve & Sign',
        message:
            'Approve this ${request.documentTypeDisplay}?\n\n'
            'Your digital signature will be applied and a final document '
            'with QR verification will be released to the citizen.\n\n'
            '$policyLine',
      );
      if (!ok) return;
    }

    if (!mounted) return;
    final dp = context.read<DocumentProvider>();
    final bp = context.read<BarangayProvider>();

    Helpers.showLoadingDialog(context, 'Generating final document...');

    try {
      await bp.loadConfig();
      final config = bp.config;
      if (config == null) throw Exception('Barangay configuration not found.');

      final userService = UserService();
      final citizen = await userService.getUserProfile(request.userId);
      if (citizen == null) throw Exception('Citizen profile not found');

      final approverName = auth.userProfile!.fullName;

      // Build verification identity FIRST so the PDF can embed the QR + expiry.
      final payload = ReleasePayload.buildIdentity(
        requestId: request.id,
        sequence: DateTime.now().millisecondsSinceEpoch,
        releasedBy: auth.userProfile!.id,
        now: DateTime.now(),
        singleUse: policy.singleUse,
        maxUses: policy.singleUse ? null : policy.maxUses,
        validFor: policy.noExpiry
            ? null
            : (policy.validFor ?? const Duration(days: 30)),
        noExpiry: policy.noExpiry,
      );
      final expiresAtLabel = payload.expiresAt != null
          ? DateFormat('MMM dd, yyyy').format(payload.expiresAt!)
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
            ).format(citizen.dateOfBirth),
            placeOfBirth: citizen.placeOfBirth,
            gender: citizen.gender,
            profilePhotoUrl: citizen.profilePhotoUrl,
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
            ).format(citizen.dateOfBirth),
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
      Helpers.showSuccessSnackBar(
        context,
        'Document approved, signed & released with QR verification!',
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        'Error: ${Helpers.parseSupabaseError(e.toString())}',
      );
    }
  }

  // ── Release policy picker (expiry / single-use / use limit) ─────────

  Future<_ReleasePolicy?> _showReleasePolicySheet() {
    return showModalBottomSheet<_ReleasePolicy>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReleasePolicySheet(),
    );
  }

  // ── Reject ──────────────────────────────────────────────────────────

  Future<void> _handleReject(DocumentRequest request) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rejecting: ${request.documentTypeDisplay}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Provide a reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, 'Please provide a reason');
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final dp = context.read<DocumentProvider>();
    final auth = context.read<AuthProvider>();
    Helpers.showLoadingDialog(context, 'Rejecting...');
    try {
      await dp.captainReject(
        requestId: request.id,
        approverId: auth.userProfile!.id,
        approverRole: auth.userProfile!.role,
        reason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(context, 'Request rejected');
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentRequestDetailScreen(
          request: r,
          actions: [
            RequestAction(
              label: 'Reject',
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              onPressed: () => _handleReject(r),
            ),
            RequestAction(
              label: 'Sign & Release',
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
                            '$roleLabel — Final Approval',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Sign and release documents to citizens',
                            style: TextStyle(
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
                              const Text(
                                'No documents awaiting approval',
                                style: TextStyle(
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
                            'Requested ${Helpers.formatDate(r.requestedAt)}',
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
                      child: const Text(
                        'For Approval',
                        style: TextStyle(
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
                    const Text(
                      'Purpose',
                      style: TextStyle(
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
                            'Payment: ₱${r.paymentAmount.toStringAsFixed(2)} — ${r.paymentStatus}',
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
                        const Text(
                          'Review request',
                          style: TextStyle(
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

// ── Release policy (expiry • single-use • use limit) ─────────────────────

/// Per-document release policy chosen by the approver before signing.
class _ReleasePolicy {
  const _ReleasePolicy({
    required this.validFor,
    required this.noExpiry,
    required this.singleUse,
    required this.maxUses,
  });

  /// How long the released copy stays valid. Unused when [noExpiry] is true.
  final Duration? validFor;

  /// When true the document never expires ([validFor] is not applied).
  final bool noExpiry;

  /// The document may only be claimed once.
  final bool singleUse;

  /// Allowed uses when not single-use; `null` means unlimited.
  final int? maxUses;

  /// 30 days, expiring, multi-use, unlimited — the sensible default.
  static const _ReleasePolicy defaults = _ReleasePolicy(
    validFor: Duration(days: 30),
    noExpiry: false,
    singleUse: false,
    maxUses: null,
  );
}

/// One-line description of a policy — used in the confirmation dialog and as
/// the live preview inside the policy sheet.
String _describePolicy(_ReleasePolicy p) {
  final validity = p.noExpiry
      ? 'No expiry'
      : 'Valid for ${p.validFor?.inDays ?? 30} days';
  final usage = p.singleUse
      ? 'Single-use'
      : p.maxUses == null
      ? 'Multi-use (unlimited)'
      : 'Multi-use (max ${p.maxUses} uses)';
  return '$validity • $usage';
}

/// Bottom sheet where the approver configures how the released document may
/// be used. Pops with the chosen [_ReleasePolicy], or `null` when dismissed.
class _ReleasePolicySheet extends StatefulWidget {
  const _ReleasePolicySheet();

  @override
  State<_ReleasePolicySheet> createState() => _ReleasePolicySheetState();
}

class _ReleasePolicySheetState extends State<_ReleasePolicySheet> {
  /// Matches the "Sign & Release" button / gradient header blue.
  static const Color _accent = Color(0xFF0D47A1);

  /// `(label, days)` — `days == null` is the "No expiry" option.
  static const List<(String, int?)> _validityOptions = [
    ('7 days', 7),
    ('30 days', 30),
    ('90 days', 90),
    ('1 year (365 days)', 365),
    ('No expiry', null),
  ];

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );

  int _days = _ReleasePolicy.defaults.validFor?.inDays ?? 30;
  bool _noExpiry = _ReleasePolicy.defaults.noExpiry;
  bool _singleUse = _ReleasePolicy.defaults.singleUse;
  final TextEditingController _maxUsesCtrl = TextEditingController();
  final TextEditingController _customDaysCtrl = TextEditingController();
  String? _maxUsesError;
  String? _customDaysError;

  @override
  void dispose() {
    _maxUsesCtrl.dispose();
    _customDaysCtrl.dispose();
    super.dispose();
  }

  /// Best-effort policy for the live preview; strict validation happens in
  /// [_confirm].
  _ReleasePolicy _previewPolicy() {
    final rawMax = _maxUsesCtrl.text.trim();
    final rawCustom = _customDaysCtrl.text.trim();

    int activeDays = _days;
    if (rawCustom.isNotEmpty) {
      final customParsed = int.tryParse(rawCustom);
      if (customParsed != null && customParsed > 0) {
        activeDays = customParsed;
      }
    }

    return _ReleasePolicy(
      validFor: _noExpiry ? null : Duration(days: activeDays),
      noExpiry: _noExpiry,
      singleUse: _singleUse,
      maxUses: _singleUse || rawMax.isEmpty ? null : int.tryParse(rawMax),
    );
  }

  void _selectValidity(int? days) {
    setState(() {
      if (days == null) {
        _noExpiry = true;
      } else {
        _noExpiry = false;
        _days = days;
      }
      _customDaysError = null;
    });
  }

  void _confirm() {
    int? maxUses;
    if (!_singleUse) {
      final raw = _maxUsesCtrl.text.trim();
      if (raw.isNotEmpty) {
        final parsed = RegExp(r'^\d+$').hasMatch(raw)
            ? int.tryParse(raw)
            : null;
        if (parsed == null || parsed < 1) {
          setState(() {
            _maxUsesError = 'Enter a whole number of 1 or more, or leave blank';
          });
          return;
        }
        maxUses = parsed;
      }
    }

    if (!mounted) return;

    // Validate custom days if they are typed
    final rawCustom = _customDaysCtrl.text.trim();
    int finalDays = _days;
    if (rawCustom.isNotEmpty) {
      final parsed = int.tryParse(rawCustom);
      if (parsed == null || parsed <= 0) {
        setState(() {
          _customDaysError = 'Enter a positive whole number';
        });
        return;
      }
      finalDays = parsed;
    }

    Navigator.pop(
      context,
      _ReleasePolicy(
        validFor: _noExpiry ? null : Duration(days: finalDays),
        noExpiry: _noExpiry,
        singleUse: _singleUse,
        maxUses: _singleUse ? null : maxUses,
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: _labelStyle);

  Widget _buildSegment(String label, int? days) {
    final selected = days == null ? _noExpiry : !_noExpiry && _days == days;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectValidity(days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Modal bottom sheets are not keyboard-aware on their own — lift the
    // content so the max-uses field and buttons stay visible.
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height - 12),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Release Policy',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set how the citizen can use this document.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Validity
                _sectionLabel('VALIDITY'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (final (label, days) in _validityOptions)
                        _buildSegment(label, days),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Single-use switch
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: _singleUse ? 0.4 : 0.12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.looks_one,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Single-use',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Only one claim allowed — no repeat uses.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _singleUse,
                        onChanged: (value) => setState(() {
                          _singleUse = value;
                          if (value) _maxUsesError = null;
                        }),
                      ),
                    ],
                  ),
                ),

                // Custom days input
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('CUSTOM DAYS'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customDaysCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            setState(() => _customDaysError = null),
                        decoration: InputDecoration(
                          labelText: 'Custom days',
                          hintText: 'Enter number of days',
                          helperText: 'Positive whole number of days',
                          errorText: _customDaysError,
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live summary of the chosen policy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: _accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _describePolicy(_previewPolicy()),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text(
                          'Confirm Policy',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bell with unread badge for the gradient header. The officials' dashboard
/// owns the load/subscribe lifecycle for NotificationProvider — this only
/// reads `unreadCount` for display.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'Notifications',
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
