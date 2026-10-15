import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart'
    show PdfTextSelectionParams, PdfViewer, PdfViewerParams;
import 'package:provider/provider.dart';

import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/services/storage_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Simple, read-only viewer for e-receipt PDFs.
///
/// Unlike [DocumentViewerScreen], this screen has no watermark, no
/// screenshot protection, no printable-copy flow, and no verification QR.
/// It simply fetches the PDF from [DocumentRequest.eReceiptUrl] and displays
/// it with a minimal summary card and a close button.
///
/// Access control: only the citizen who requested the document or official
/// roles (secretary, treasurer, captain, kagawad, tanod, admin) may view.
class EReceiptViewerScreen extends StatefulWidget {
  const EReceiptViewerScreen({
    super.key,
    required this.request,
    this.viewerName,
  });

  final DocumentRequest request;

  /// Optional name to display in the header. Falls back to the logged-in
  /// user's profile or the request's user name when null.
  final String? viewerName;

  @override
  State<EReceiptViewerScreen> createState() => _EReceiptViewerScreenState();
}

class _EReceiptViewerScreenState extends State<EReceiptViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1976D2);

  Uint8List? _bytes;
  bool _isLoading = true;
  String? _loadErrorMessage;
  bool _accessDenied = false;

  String _viewerName = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewerName.isEmpty) {
      _checkAccess();
      if (!_accessDenied) {
        _viewerName = _resolveViewerName();
        _loadDocument();
      }
    }
  }

  void _checkAccess() {
    final authProvider = context.read<AuthProvider>();
    final userProfile = authProvider.userProfile;
    if (userProfile == null) {
      _accessDenied = true;
      return;
    }

    // Allow if user is the request owner
    if (widget.request.userId == userProfile.id) {
      _accessDenied = false;
      return;
    }

    // Allow if user has an official role
    final role = userProfile.role;
    _accessDenied = !AppRoles.isOfficial(role);
  }

  String _resolveViewerName() {
    final passed = widget.viewerName?.trim();
    if (passed != null && passed.isNotEmpty) return passed;

    final profile = context.read<AuthProvider>().userProfile;
    final fullName = profile?.fullName.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final recordName = widget.request.userFullName?.trim();
    if (recordName != null && recordName.isNotEmpty) return recordName;

    return AppLocalizations.of(context).viewerDefaultName;
  }

  String get _documentUrl => widget.request.eReceiptUrl ?? '';

  String _storagePathFromUrl(String url, AppLocalizations l10n) {
    final segments = Uri.parse(url).pathSegments;
    final documentsIndex = segments.indexOf('documents');
    if (documentsIndex == -1 || documentsIndex >= segments.length - 1) {
      throw _ViewerMessageException(l10n.viewerLinkInvalidFormat);
    }
    return segments.sublist(documentsIndex + 1).join('/');
  }

  Future<void> _loadDocument() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      final url = _documentUrl;
      if (url.isEmpty) {
        throw _ViewerMessageException(l10n.viewerNoFileAttached);
      }

      final downloaded = await StorageService().downloadFile(
        bucket: 'documents',
        path: _storagePathFromUrl(url, l10n),
      );
      final data = Uint8List.fromList(downloaded);

      if (!mounted) return;
      setState(() {
        _bytes = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _bytes = null;
        _loadErrorMessage = error is _ViewerMessageException
            ? error.message
            : Helpers.parseSupabaseError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return _buildAccessDenied();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loadErrorMessage != null
                ? _buildErrorState()
                : _bytes == null || _isLoading
                    ? _buildLoadingState()
                    : _buildViewerContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 46,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Access Denied',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view this e-receipt.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  l10n.commonBack,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 22),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.documentTypeDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.viewerOfficialCopyViewOnly,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'E-RECEIPT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
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

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3.4,
                color: _primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.viewerPreparing,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.viewerVerifying,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 46,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.viewerOpenErrorTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadErrorMessage ?? l10n.viewerTryAgainMoment,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _loadDocument,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                l10n.commonRetry,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.commonBack,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerContent() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _buildSummaryCard(),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PdfViewer.data(
                _bytes!,
                sourceName: 'e_receipt.pdf',
                params: PdfViewerParams(
                  backgroundColor: const Color(0xFFDCE2E8),
                  margin: 12,
                  textSelectionParams: const PdfTextSelectionParams(
                    enabled: false,
                  ),
                  buildContextMenu: (context, params) => null,
                  loadingBannerBuilder:
                      (context, bytesDownloaded, totalBytes) =>
                          const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _primary,
                            ),
                          ),
                  errorBannerBuilder:
                      (context, error, stackTrace, documentRef) =>
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.viewerFileNotDisplayed,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                ),
              ),
            ),
          ),
        ),
        _buildFooterNote(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final request = widget.request;
    final l10n = AppLocalizations.of(context);
    final issuedAt = request.releasedAt ?? request.approvedAt ?? request.requestedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.documentTypeDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.viewerPurposeLine(request.purpose),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
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
                  color: _statusColorOf(
                    request.statusColor,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  request.statusDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColorOf(request.statusColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryTile(
                  label: l10n.viewerDocumentIdLabel,
                  value: request.documentId ?? l10n.viewerNotYetIssued,
                ),
              ),
              const _TileSpacer(),
              Expanded(
                child: _summaryTile(
                  label: 'PAYMENT AMOUNT',
                  value: '₱${request.paymentAmount.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryTile(
                  label: l10n.viewerValidUntilLabel,
                  value: request.expiresAt == null
                      ? l10n.viewerNoExpiry
                      : Helpers.formatDate(request.expiresAt!),
                  valueColor: request.isExpired ? AppColors.error : AppColors.textPrimary,
                  badge: request.isExpired ? const _ExpiredBadge() : null,
                ),
              ),
              const _TileSpacer(),
              Expanded(
                child: _summaryTile(
                  label: l10n.viewerIssuedOnLabel,
                  value: Helpers.formatDate(issuedAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryTile(
                  label: 'PAYMENT STATUS',
                  value: request.paymentStatus.isEmpty
                      ? l10n.viewerNotYetIssued
                      : request.paymentStatus,
                  valueColor: _paymentStatusColor(request.paymentStatus),
                ),
              ),
              const _TileSpacer(),
              Expanded(
                child: _summaryTile(
                  label: 'VIEWED BY',
                  value: _viewerName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _paymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'confirmed':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFEF6C00);
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _summaryTile({
    required String label,
    required String value,
    Color valueColor = AppColors.textPrimary,
    Widget? badge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge],
          ],
        ),
      ],
    );
  }

  Widget _buildFooterNote() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'E-Receipt for your records. This is not a legal document.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColorOf(String name) {
    switch (name) {
      case 'blue':
        return _primary;
      case 'green':
        return const Color(0xFF2E7D32);
      case 'orange':
        return const Color(0xFFEF6C00);
      case 'red':
        return AppColors.error;
      case 'teal':
        return const Color(0xFF00897B);
      default:
        return Colors.grey;
    }
  }
}

class _ViewerMessageException implements Exception {
  _ViewerMessageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _TileSpacer extends StatelessWidget {
  const _TileSpacer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFEDF1F5),
    );
  }
}

class _ExpiredBadge extends StatelessWidget {
  const _ExpiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'EXPIRED',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.error,
        ),
      ),
    );
  }
}