import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:pdfrx/pdfrx.dart'
    show PdfTextSelectionParams, PdfViewer, PdfViewerParams;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:guin_app/automation/print_copy_rules.dart';
import 'package:guin_app/models/document_print_copy.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/services/document_automation_service.dart';
import 'package:guin_app/services/storage_service.dart';
import 'package:guin_app/services/verification_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

/// Result of comparing the downloaded bytes against the stored checksum.
enum _IntegrityStatus { verified, mismatched, unknown }

class _IntegrityInfo {
  const _IntegrityInfo({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
}

/// Friendly, non-technical failure raised while fetching the document.
class _ViewerMessageException implements Exception {
  _ViewerMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// View-only presentation of an issued barangay document.
///
/// The file never leaves the app: it is fetched into memory, integrity-checked
/// against the stored SHA-256, rendered in-app, watermarked per view, and
/// screen-capture protection is requested while the screen is open.
///
/// The one intentional export path is "Request printable copy": the official
/// PDF is regenerated with a per-copy notice, a copy serial and a QR built
/// from a freshly minted verification token, then handed to the platform
/// print / share sheet.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.request,
    this.viewerName,
  });

  final DocumentRequest request;

  /// Name stamped into the watermark. Resolved from [AuthProvider] when null.
  final String? viewerName;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1976D2);

  Uint8List? _bytes;
  bool _isLoading = true;
  String? _loadErrorMessage;
  _IntegrityStatus _integrity = _IntegrityStatus.unknown;

  /// Drives the expand / collapse of the integrity banner's detail message.
  late final AnimationController _integrityDetailsController;
  late final Animation<double> _integrityDetailsProgress;

  /// True while a printable copy is being minted and rendered.
  bool _isRequestingCopy = false;

  /// Result of the last successful request, kept so the sheet with the
  /// print / save actions can be reopened without minting another copy.
  DocumentPrintCopy? _issuedCopy;
  Uint8List? _issuedPdfBytes;

  late final String _viewerName;
  late final String _viewNonce;
  late final String _openedAtLabel;

  @override
  void initState() {
    super.initState();
    _viewerName = _resolveViewerName();
    _viewNonce = _generateNonce();
    _openedAtLabel = _formatStamp(DateTime.now());
    _integrityDetailsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _integrityDetailsProgress = CurvedAnimation(
      parent: _integrityDetailsController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _setScreenshotProtection(protect: true);
    _loadDocument();
  }

  @override
  void dispose() {
    _integrityDetailsController.dispose();
    _setScreenshotProtection(protect: false);
    super.dispose();
  }

  // ── Identity / per-view watermark ────────────────────────────────────

  String _resolveViewerName() {
    final passed = widget.viewerName?.trim();
    if (passed != null && passed.isNotEmpty) return passed;

    final profile = context.read<AuthProvider>().userProfile;
    final fullName = profile?.fullName.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final recordName = widget.request.userFullName?.trim();
    if (recordName != null && recordName.isNotEmpty) return recordName;

    return 'Barangay Resident';
  }

  /// Short random code so every open of this screen is individually traceable.
  String _generateNonce() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }

  String _formatStamp(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} '
        '${pad(time.hour)}:${pad(time.minute)}';
  }

  String get _watermarkText => '$_viewerName • $_viewNonce • $_openedAtLabel';

  // ── Screenshot protection (best-effort) ──────────────────────────────

  /// Blocks capture while the document is on screen and releases it on exit.
  ///
  /// Native targets honor OS-level capture blocking; on the web only the
  /// JS deterrents (right-click, PrintScreen, text selection) apply, so the
  /// call is fired and forgotten there. Failures are never fatal.
  Future<void> _setScreenshotProtection({required bool protect}) async {
    Future<bool> apply() => protect
        ? NoScreenshot.instance.screenshotOff()
        : NoScreenshot.instance.screenshotOn();

    if (kIsWeb) {
      apply().catchError((_) => false);
      return;
    }

    try {
      await apply();
    } catch (_) {
      // Platform without capture-blocking support (e.g. Linux/Wayland).
      // The per-view watermark still marks anything that gets captured.
    }
  }

  // ── Loading ──────────────────────────────────────────────────────────

  String get _documentUrl =>
      widget.request.finalDocumentUrl ?? widget.request.documentUrl ?? '';

  String _storagePathFromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    final documentsIndex = segments.indexOf('documents');
    if (documentsIndex == -1 || documentsIndex >= segments.length - 1) {
      throw _ViewerMessageException(
        'The document link for this request is not in the expected format.',
      );
    }
    return segments.sublist(documentsIndex + 1).join('/');
  }

  _IntegrityStatus _checkIntegrity(Uint8List data) {
    final stored = widget.request.documentHash?.trim() ?? '';
    if (stored.isEmpty) return _IntegrityStatus.unknown;

    final computed = sha256.convert(data).toString();
    return computed.toLowerCase() == stored.toLowerCase()
        ? _IntegrityStatus.verified
        : _IntegrityStatus.mismatched;
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      final url = _documentUrl;
      if (url.isEmpty) {
        throw _ViewerMessageException(
          'No document file is attached to this request yet.',
        );
      }

      final downloaded = await StorageService().downloadFile(
        bucket: 'documents',
        path: _storagePathFromUrl(url),
      );
      final data = Uint8List.fromList(downloaded);

      if (!mounted) return;
      setState(() {
        _bytes = data;
        _integrity = _checkIntegrity(data);
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

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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

  Widget _buildHeader() {
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
                  Icons.verified_user,
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
                    const Text(
                      'Official copy • view only',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'SECURE',
                      style: TextStyle(
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
            const Text(
              'Preparing your document…',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifying the file and applying your personal watermark.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
            const Text(
              'We could not open this document',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadErrorMessage ?? 'Please try again in a moment.',
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
              label: const Text(
                'Try again',
                style: TextStyle(fontWeight: FontWeight.w600),
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
              child: const Text(
                'Go back',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _buildIntegrityBanner(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PdfViewer.data(
                    _bytes!,
                    sourceName: 'document.pdf',
                    params: PdfViewerParams(
                      backgroundColor: const Color(0xFFDCE2E8),
                      margin: 12,
                      // View-only: no text selection and no context menu.
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
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'This file could not be displayed.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ),
                  // Per-view watermark: never interactive, never removable.
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _WatermarkPainter(text: _watermarkText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildPrintCopyAction(),
        _buildFooterNote(),
      ],
    );
  }

  _IntegrityInfo get _integrityInfo {
    switch (_integrity) {
      case _IntegrityStatus.verified:
        return const _IntegrityInfo(
          color: Color(0xFF2E7D32),
          icon: Icons.verified_outlined,
          title: 'Integrity verified — file matches record',
          message:
              'The file’s SHA-256 content hash matches the record held by the barangay. This confirms the file was not altered after release; scan the QR code to confirm authenticity with the barangay.',
        );
      case _IntegrityStatus.mismatched:
        return const _IntegrityInfo(
          color: AppColors.error,
          icon: Icons.error_outline,
          title: 'Integrity check failed — may be tampered with',
          message:
              'The hash of this file does not match the hash recorded at release. Request a fresh copy if in doubt.',
        );
      case _IntegrityStatus.unknown:
        return const _IntegrityInfo(
          color: Color(0xFF546E7A),
          icon: Icons.info_outline,
          title: 'No integrity hash on record',
          message:
              'This document was issued without a stored checksum, so its authenticity cannot be confirmed here.',
        );
    }
  }

  /// Slim, single-line integrity row.
  ///
  /// Collapsed it takes roughly one line of space (small icon tile + short
  /// title + chevron). Tapping it expands the full [_IntegrityInfo.message]
  /// inline below with a short height + fade animation, so the detail is
  /// still one tap away without costing vertical space at rest.
  Widget _buildIntegrityBanner() {
    final info = _integrityInfo;
    final prominent = _integrity == _IntegrityStatus.mismatched;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: prominent ? 0.09 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: info.color.withValues(alpha: prominent ? 0.5 : 0.28),
          width: prominent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => setState(() {
                _integrityDetailsController.isCompleted
                    ? _integrityDetailsController.reverse()
                    : _integrityDetailsController.forward();
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(info.icon, size: 15, color: info.color),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        info.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: info.color,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(
                        _integrityDetailsProgress,
                      ),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: info.color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _integrityDetailsProgress,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(
              opacity: _integrityDetailsProgress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                child: Text(
                  info.message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final request = widget.request;
    final issuedAt =
        request.releasedAt ?? request.approvedAt ?? request.requestedAt;
    final expired = request.isExpired;
    final usesRemaining = request.maxUses == null
        ? 'Unlimited'
        : '${request.remainingUses}';
    final rawQrUrl = request.qrUrl?.trim();
    final storedQrUrl = (rawQrUrl == null || rawQrUrl.isEmpty) ? null : rawQrUrl;
    // Regenerate QR URL with new query-param format if documentId exists
    final qrUrl = _regenerateQrUrl(request) ?? storedQrUrl;

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
                  Icons.description_outlined,
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
                      'Purpose: ${request.purpose}',
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
                  label: 'DOCUMENT ID',
                  value: request.documentId ?? 'Not yet issued',
                ),
              ),
              const _TileSpacer(),
              Expanded(
                child: _summaryTile(
                  label: 'USES REMAINING',
                  value: usesRemaining,
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
                  label: 'VALID UNTIL',
                  value: request.expiresAt == null
                      ? 'No expiry'
                      : Helpers.formatDate(request.expiresAt!),
                  valueColor: expired ? AppColors.error : AppColors.textPrimary,
                  badge: expired ? const _ExpiredBadge() : null,
                ),
              ),
              const _TileSpacer(),
              Expanded(
                child: _summaryTile(
                  label: 'ISSUED ON',
                  value: Helpers.formatDate(issuedAt),
                ),
              ),
            ],
          ),
          if (qrUrl != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEDF1F5)),
            _buildViewQrAction(qrUrl),
          ],
        ],
      ),
    );
  }

  /// Slim tappable row inside the summary card that opens a larger,
  /// scannable view of the document's verification QR code. Rendered only
  /// when the row actually carries a QR link.
  /// Regenerates the QR URL with the new query-param format from the stored
  /// URL's token. Falls back to the stored URL if the token can't be parsed.
  String? _regenerateQrUrl(DocumentRequest request) {
    final documentId = request.documentId;
    if (documentId == null || documentId.isEmpty) return null;

    final storedUrl = request.qrUrl?.trim();
    if (storedUrl == null || storedUrl.isEmpty) return null;

    final uri = Uri.tryParse(storedUrl);
    if (uri == null) return null;

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return null;

    return VerificationService().buildQrUrl(
      VerificationService.verificationBaseUrl,
      documentId,
      token,
    );
  }

  Widget _buildViewQrAction(String qrUrl) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _showQrSheet(qrUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2, color: _primary, size: 18),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View QR code',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Open a larger code to scan',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet with a large QR code for [qrUrl] and the underlying
  /// verification link. View-only: no share, save or export actions.
  Future<void> _showQrSheet(String qrUrl) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final screenWidth = MediaQuery.sizeOf(sheetContext).width;
        final qrSize = min(264.0, max(180.0, screenWidth - 96));

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: _primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Verification QR code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan this code with a camera to check this document with '
                  'the barangay. It is shown here only — nothing is shared '
                  'or saved.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: QrImageView(
                      data: qrUrl,
                      version: QrVersions.auto,
                      size: qrSize,
                      gapless: false,
                      backgroundColor: Colors.white,
                      semanticsLabel: 'Verification QR code',
                      errorStateBuilder: (context, error) => SizedBox(
                        width: qrSize,
                        height: qrSize,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'This QR code could not be displayed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'VERIFICATION LINK',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                SelectionArea(
                  child: Text(
                    qrUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF37474F),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: Color(0xFFD5DCE4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            Icons.lock_outline,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'View-only in this app: every view is watermarked and screen capture is blocked where supported. For paper or a file, request a watermarked, serial-numbered printable copy.',
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

  // ── Printable copy (the one intentional export path) ─────────────────

  /// A printable copy can only be minted once the document has an ID and has
  /// been approved / released.
  bool get _canRequestPrintCopy {
    final request = widget.request;
    return request.documentId != null &&
        (request.isReleased || request.isApproved);
  }

  String get _printCopyDisabledReason {
    if (widget.request.documentId == null) {
      return 'A printable copy becomes available once your document ID is '
          'issued.';
    }
    return 'A printable copy can be requested once this document is approved '
        'for release.';
  }

  String _isoDateLabel(DateTime date) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${pad(date.month)}-${pad(date.day)}';
  }

  String _printCopyFilename(DocumentPrintCopy copy) =>
      '${copy.documentId}_copy_${copy.copyNumber}.pdf';

  Widget _buildPrintCopyAction() {
    final eligible = _canRequestPrintCopy;
    final busy = _isRequestingCopy;
    final issued = _issuedCopy;
    final issuedBytes = _issuedPdfBytes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: eligible && !busy ? _requestPrintCopy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE4E9F0),
                disabledForegroundColor: const Color(0xFF8E9AAB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 11),
                        Text(
                          'Preparing your printable copy…',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print_outlined, size: 19),
                        SizedBox(width: 9),
                        Text(
                          'Request printable copy',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (!eligible)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
              child: Text(
                _printCopyDisabledReason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          if (!busy && issued != null && issuedBytes != null)
            TextButton.icon(
              onPressed: () => _showReadySheet(issued, issuedBytes),
              icon: const Icon(Icons.print_outlined, size: 16, color: _primary),
              label: Text(
                '${issued.displayLabel} — print or save again',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestPrintCopy() async {
    if (_isRequestingCopy || !_canRequestPrintCopy) return;

    if (kIsWeb) {
      await _showInfoSheet(
        icon: Icons.print_disabled_outlined,
        tone: _primary,
        title: 'Printing is not available here',
        message:
            'Printing and saving are available on mobile and desktop. Open '
            'this document in the barangay app on your phone or computer to '
            'get your printable copy.',
      );
      return;
    }

    final confirmed = await _showPrintCopyConfirmation();
    if (confirmed != true || !mounted) return;
    await _createPrintCopy();
  }

  /// Plain-language confirmation shown before a copy is minted.
  Future<bool?> _showPrintCopyConfirmation() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.print_outlined,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Request a printable copy?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your copy is regenerated from the official record the '
                  'barangay holds — the same approved document, with its '
                  'signature and QR code.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                _copyBullet(
                  icon: Icons.badge_outlined,
                  text:
                      'Watermarked with your name and stamped with a unique '
                      'serial number, so every printed copy can be traced '
                      'back to you.',
                ),
                _copyBullet(
                  icon: Icons.picture_as_pdf_outlined,
                  text:
                      'Printing and saving are allowed — you can print it or '
                      'keep it as a PDF. Each document allows up to '
                      '${PrintCopyRules.maxCopiesPerDocument} printable copies '
                      'in total.',
                ),
                _copyBullet(
                  icon: Icons.qr_code_scanner,
                  text:
                      'Scanning the QR code on the copy checks this '
                      'document’s expiry, single-use and use limits — '
                      'exactly like the original.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Create my printable copy',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _copyBullet({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF37474F),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mint the copy, render the official PDF with the per-copy notice and QR,
  /// then offer print / save. Never throws.
  Future<void> _createPrintCopy() async {
    final request = widget.request;
    final documentId = request.documentId;
    if (_isRequestingCopy || documentId == null) return;

    setState(() => _isRequestingCopy = true);

    try {
      final verification = VerificationService();
      final copy = await verification.issuePrintCopy(
        requestId: request.id,
        documentId: documentId,
        issuedBy: null,
      );
      final qrUrl = verification.buildQrUrl(
        VerificationService.verificationBaseUrl,
        documentId,
        copy.verificationToken,
      );
      final copyNotice = PrintCopyRules.noticeFor(
        copyNumber: copy.copyNumber,
        issuedTo: _viewerName,
        issuedAt: request.releasedAt ?? DateTime.now(),
      );
      final expiresAt = request.expiresAt;

      final file = await DocumentAutomationService().generatePrintableCopyPdf(
        request: request,
        documentId: documentId,
        qrUrl: qrUrl,
        expiresAtLabel: expiresAt == null ? null : _isoDateLabel(expiresAt),
        copyNotice: copyNotice,
      );
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _issuedCopy = copy;
        _issuedPdfBytes = bytes;
        _isRequestingCopy = false;
      });
      await _showReadySheet(copy, bytes);
    } catch (error) {
      await _showPrintCopyError(error);
    } finally {
      if (mounted && _isRequestingCopy) {
        setState(() => _isRequestingCopy = false);
      }
    }
  }

  /// Bottom sheet with the two export actions: platform print and share.
  Future<void> _showReadySheet(DocumentPrintCopy copy, Uint8List bytes) async {
    if (!mounted) return;
    final filename = _printCopyFilename(copy);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        // Lives in the route builder closure so it survives rebuilds.
        String? busyAction;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> run(
              String action,
              Future<void> Function() body,
            ) async {
              if (busyAction != null) return;
              setSheetState(() => busyAction = action);
              try {
                await body();
              } catch (error) {
                await _showPrintCopyError(error);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => busyAction = null);
                }
              }
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetHandle(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.11),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your printable copy is ready',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.request.documentTypeDisplay} • '
                                '${copy.copyLabel}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_2, size: 16, color: _primary),
                              SizedBox(width: 7),
                              Text(
                                'TRACEABLE, NUMBERED COPY',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Serial ${copy.serial} — recorded as '
                            '${copy.copyLabel} for $_viewerName. Scanning the '
                            'QR code on this copy shows which copy was used, '
                            'and this document’s expiry and use limits '
                            'still apply.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: busyAction == null
                                  ? () => run(
                                      'print',
                                      () => Printing.layoutPdf(
                                        onLayout: (_) async => bytes,
                                        name: filename,
                                      ),
                                    )
                                  : null,
                              icon: busyAction == 'print'
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.print_outlined, size: 19),
                              label: Text(
                                busyAction == 'print' ? 'Preparing…' : 'Print',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFE4E9F0,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF8E9AAB,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: busyAction == null
                                  ? () => run(
                                      'save',
                                      () => Printing.sharePdf(
                                        bytes: bytes,
                                        filename: filename,
                                      ),
                                    )
                                  : null,
                              icon: busyAction == 'save'
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: _primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save_alt_outlined,
                                      size: 19,
                                    ),
                              label: Text(
                                busyAction == 'save' ? 'Saving…' : 'Save PDF',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: BorderSide(
                                  color: _primary.withValues(alpha: 0.55),
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF8E9AAB,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: busyAction == null
                          ? () => Navigator.of(sheetContext).pop()
                          : null,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPrintCopyError(Object error) async {
    final info = _printCopyErrorInfo(error);
    await _showInfoSheet(
      icon: info.icon,
      tone: info.tone,
      title: info.title,
      message: info.message,
    );
  }

  ({IconData icon, Color tone, String title, String message})
  _printCopyErrorInfo(Object error) {
    if (error is StateError) {
      return (
        icon: Icons.print_disabled_outlined,
        tone: const Color(0xFFEF6C00),
        title: 'Print limit reached',
        message:
            'This document already has its maximum of '
            '${PrintCopyRules.maxCopiesPerDocument} printable copies. If you '
            'need another one, please visit or call the barangay office.',
      );
    }
    if (error is UnsupportedError ||
        error is UnimplementedError ||
        _looksLikePlatformError(error)) {
      return (
        icon: Icons.devices_other_outlined,
        tone: _primary,
        title: 'Not available on this device',
        message:
            'Printing and saving are available on mobile and desktop. Open '
            'this document in the barangay app on your phone or computer to '
            'get your printable copy.',
      );
    }
    if (error is FileSystemException) {
      return (
        icon: Icons.folder_off_outlined,
        tone: const Color(0xFFEF6C00),
        title: 'We could not prepare the file',
        message:
            'The PDF could not be saved on this device. Please try again in '
            'a moment.',
      );
    }
    return (
      icon: Icons.error_outline,
      tone: AppColors.error,
      title: 'We could not create your printable copy',
      message: Helpers.parseSupabaseError(error),
    );
  }

  bool _looksLikePlatformError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('dart:io') ||
        text.contains('not available on this platform') ||
        text.contains('unsupported operation') ||
        text.contains('unimplemented');
  }

  /// Generic, dismissible message sheet used for errors and notices.
  Future<void> _showInfoSheet({
    required IconData icon,
    required Color tone,
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: tone, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE3EA),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
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

/// Tiled, diagonal, semi-transparent stamp of the viewer identity, view nonce
/// and open time — every capture of this screen is traceable to one viewing.
class _WatermarkPainter extends CustomPainter {
  const _WatermarkPainter({required this.text});

  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF1976D2).withValues(alpha: 0.13),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (painter.width <= 0 || painter.height <= 0) return;

    const angle = -0.6; // ≈ -34°
    final cosine = cos(angle.abs());
    final sine = sin(angle.abs());
    final cellWidth = painter.width + 72;
    final cellHeight = painter.height + 58;

    // Bounding half-extent of the rotated viewport, plus one cell of margin,
    // so every visible pixel is stamped without over-painting off screen.
    final halfWidth =
        (size.width * cosine + size.height * sine) / 2 + cellWidth;
    final halfHeight =
        (size.width * sine + size.height * cosine) / 2 + cellHeight;
    final cols = (halfWidth / cellWidth).ceil();
    final rows = (halfHeight / cellHeight).ceil();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    for (var row = -rows; row <= rows; row++) {
      final shift = row.isOdd ? cellWidth / 2 : 0.0;
      for (var col = -cols; col <= cols; col++) {
        painter.paint(
          canvas,
          Offset(col * cellWidth + shift, row * cellHeight),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => oldDelegate.text != text;
}
