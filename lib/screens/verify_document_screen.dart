import 'package:flutter/material.dart';
import 'package:guin_app/automation/document_access_rules.dart';
import 'package:guin_app/automation/verification_qr.dart';
import 'package:guin_app/models/document_print_copy.dart';
import 'package:guin_app/models/document_verification.dart';
import 'package:guin_app/services/verification_service.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _blue = Color(0xFF1976D2);
const _lightBlue = Color(0xFF42A5F5);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFF57C00);
const _red = Color(0xFFD32F2F);
const _neutral = Color(0xFF616161);

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class VerifyDocumentScreen extends StatefulWidget {
  final String? documentId;
  final String? token;

  const VerifyDocumentScreen({super.key, this.documentId, this.token});

  @override
  State<VerifyDocumentScreen> createState() => _VerifyDocumentScreenState();
}

class _VerifyDocumentScreenState extends State<VerifyDocumentScreen> {
  final _documentIdController = TextEditingController();
  final _service = VerificationService();

  DocumentVerification? _verification;

  /// Set when the scanned token belongs to a printable copy rather than the
  /// document's original verification token.
  DocumentPrintCopy? _copy;
  String? _error;
  String? _notice;
  String? _feedback;
  Color? _feedbackTone;
  String? _token;
  String? _tokenDocumentId;
  bool _isLoading = false;
  bool _isUsing = false;

  @override
  void initState() {
    super.initState();
    if (widget.documentId != null) {
      _documentIdController.text = widget.documentId!;
      _verify(widget.documentId!, token: widget.token);
    }
  }

  @override
  void dispose() {
    _documentIdController.dispose();
    super.dispose();
  }

  /// The token that belongs to the document currently on screen.
  /// Tokens only ever come from the QR code (or the initial route arguments),
  /// so a document found by plain ID stays "view only" until it is scanned.
  String? get _usableToken {
    final verification = _verification;
    final token = _token;
    if (verification == null || token == null) return null;
    if (_tokenDocumentId != verification.documentId) return null;
    return token;
  }

  DocumentAccessState _accessState(DocumentVerification v) =>
      DocumentAccessState(
        status: v.status,
        expiresAt: v.expiresAt,
        singleUse: v.singleUse,
        maxUses: v.maxUses,
        useCount: v.useCount,
      );

  Future<void> _verify(String documentId, {String? token}) async {
    final l10n = AppLocalizations.of(context);
    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken && _tokenDocumentId != documentId) {
      // A plain ID lookup for another document drops the previous token.
      _token = null;
      _tokenDocumentId = null;
    }

    setState(() {
      _isLoading = true;
      _notice = null;
      _feedback = null;
      _feedbackTone = null;
    });

    try {
      final resolved = await _service.resolveDocument(documentId, token: token);
      final verification = resolved?.document;
      if (!mounted) return;
      setState(() {
        _verification = verification;
        // Non-null only when the scanned token belongs to a printed copy.
        _copy = resolved?.copy;
        // Only a token that matched a real record may be used later.
        if (verification != null && hasToken) {
          _token = token;
          _tokenDocumentId = documentId;
        }
        _error = verification == null ? l10n.verifyDocumentNotFound : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verification = null;
        _copy = null;
        _error = l10n.verifyError(e);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openScanner() async {
    final l10n = AppLocalizations.of(context);
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const _QrScanScreen(),
      ),
    );
    if (!mounted || raw == null) return;

    final qr = VerificationQrParser.parse(raw);
    if (qr == null) {
      setState(() {
        _notice = l10n.verifyInvalidQr;
      });
      return;
    }

    _documentIdController.text = qr.documentId;
    await _verify(qr.documentId, token: qr.token);
  }

  Future<void> _useDocument() async {
    final l10n = AppLocalizations.of(context);
    final verification = _verification;
    final token = _usableToken;
    if (verification == null || token == null || _isUsing) return;

    setState(() {
      _isUsing = true;
      _notice = null;
      _feedback = null;
      _feedbackTone = null;
    });

    try {
      final result = await _service.consumeDocument(
        verification.documentId,
        token: token,
      );
      if (!mounted) return;

      setState(() {
        final updated = result.verification;
        if (updated != null) _verification = updated;

        if (result.allowed) {
          final remaining = updated == null
              ? null
              : DocumentAccessRules.remainingUses(_accessState(updated));
          _feedback = l10n.verifyDocumentUsedSuccess(_usesLeft(remaining));
          _feedbackTone = _green;
        } else {
          _feedback =
              '${DocumentAccessRules.describe(result.decision)} — '
              '${_reasonFor(result.decision)}';
          _feedbackTone = _toneFor(result.decision);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = l10n.verifyCouldNotUse(e);
        _feedbackTone = _red;
      });
    } finally {
      if (mounted) setState(() => _isUsing = false);
    }
  }

  String _usesLeft(int? remaining) {
    final l10n = AppLocalizations.of(context);
    if (remaining == null) return l10n.verifyUsesUnlimited;
    if (remaining <= 0) return l10n.verifyNoUsesRemaining;
    return l10n.verifyUsesRemaining(remaining);
  }

  String _reasonFor(DocumentAccessDecision decision) {
    final l10n = AppLocalizations.of(context);
    switch (decision) {
      case DocumentAccessDecision.allowed:
        return l10n.verifyReasonAllowed;
      case DocumentAccessDecision.notFound:
        return l10n.verifyReasonNotFound;
      case DocumentAccessDecision.revoked:
        return l10n.verifyReasonRevoked;
      case DocumentAccessDecision.expired:
        return l10n.verifyReasonExpired;
      case DocumentAccessDecision.used:
        return l10n.verifyReasonUsed;
      case DocumentAccessDecision.useLimitReached:
        return l10n.verifyReasonUseLimit;
    }
  }

  Color _toneFor(DocumentAccessDecision decision) {
    switch (decision) {
      case DocumentAccessDecision.allowed:
        return _green;
      case DocumentAccessDecision.revoked:
      case DocumentAccessDecision.expired:
      case DocumentAccessDecision.notFound:
        return _red;
      case DocumentAccessDecision.used:
      case DocumentAccessDecision.useLimitReached:
        return _orange;
    }
  }

  IconData _iconFor(DocumentAccessDecision decision) {
    switch (decision) {
      case DocumentAccessDecision.allowed:
        return Icons.verified;
      case DocumentAccessDecision.notFound:
        return Icons.search_off;
      case DocumentAccessDecision.revoked:
        return Icons.block;
      case DocumentAccessDecision.expired:
        return Icons.event_busy;
      case DocumentAccessDecision.used:
        return Icons.done_all;
      case DocumentAccessDecision.useLimitReached:
        return Icons.lock_outline;
    }
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _sentenceCase(String value) {
    if (value.isEmpty) return value;
    final spaced = value.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildResultArea()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.verifyTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search field inside header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _documentIdController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _verify(v.trim());
                    },
                    decoration: InputDecoration(
                      hintText: l10n.verifyDocumentIdHint,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.qr_code_scanner_outlined,
                        color: Color(0xFF1976D2),
                      ),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Color(0xFF1976D2),
                              ),
                              onPressed: () {
                                final id = _documentIdController.text.trim();
                                if (id.isNotEmpty) _verify(id);
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(child: _buildScanButton()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.verifyScanOrTypeHint,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
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

  Widget _buildScanButton() {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openScanner,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, color: _blue, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.verifyScanQrButton,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    final notice = _notice == null ? null : _buildNotice();
    final verification = _verification;
    final error = _error;

    if (verification == null && error == null) {
      return Column(
        children: [
          if (notice != null) notice,
          Expanded(child: _buildEmptyState()),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[notice, const SizedBox(height: 14)],
          if (error != null)
            _buildInvalidResult(error)
          else if (verification != null)
            _buildVerificationResult(verification),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: _orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _notice!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5D4037),
                  height: 1.45,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: _orange),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _notice = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_outlined,
                size: 72,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.verifyEmptyStateTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.verifyEmptyStateDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(l10n.verifyScanQrButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: BorderSide(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationResult(DocumentVerification v) {
    final l10n = AppLocalizations.of(context);
    final decision = _service.evaluate(v);
    final tone = _toneFor(decision);
    final remaining = DocumentAccessRules.remainingUses(_accessState(v));
    final expired = v.isExpired || decision == DocumentAccessDecision.expired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                child: Icon(_iconFor(decision), color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decision == DocumentAccessDecision.allowed
                          ? l10n.verifyDocumentVerified
                          : DocumentAccessRules.describe(decision),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: tone,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _reasonFor(decision),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _detailRow(
            l10n.verifyDocTypeLabel,
            Text(
              v.documentType,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _detailRow(
            l10n.verifyCitizenNameLabel,
            Text(
              v.citizenName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _detailRow(
            l10n.commonStatus,
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _sentenceCase(v.status),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _badge(DocumentAccessRules.describe(decision), tone),
              ],
            ),
          ),
          if (_copy != null) _buildCopyRow(),
          _detailRow(
            l10n.verifyIssuedLabel,
            Text(
              _formatDate(v.issuedAt),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _detailRow(
            l10n.verifyExpiryLabel,
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  v.expiresAt == null
                      ? l10n.verifyNoExpiry
                      : _formatDate(v.expiresAt!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _badge(
                  expired ? l10n.verifyExpiredBadge : l10n.verifyValidBadge,
                  expired ? _red : _green,
                ),
              ],
            ),
          ),
          _detailRow(
            l10n.verifyUsageLabel,
            _badge(
              v.singleUse ? l10n.verifySingleUseBadge : l10n.verifyMultiUseBadge,
              v.singleUse ? _blue : _neutral,
            ),
          ),
          _detailRow(
            l10n.verifyUsesRemainingLabel,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  remaining == null ? l10n.verifyUnlimited : '$remaining',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (v.maxUses != null)
                  Text(
                    l10n.verifyOfMaxUses(v.maxUses!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            _buildFeedback(),
          ],
          const SizedBox(height: 18),
          _buildUseSection(hasToken: _usableToken != null),
        ],
      ),
    );
  }

  /// Row shown when the scanned QR belongs to a watermarked printable copy.
  Widget _buildCopyRow() {
    final l10n = AppLocalizations.of(context);
    final copy = _copy!;
    return _detailRow(
      l10n.verifyPrintCopyLabel,
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _badge(copy.copyLabel, _blue),
          Text(
            copy.serial,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final tone = _feedbackTone ?? _blue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == _green ? Icons.check_circle : Icons.error_outline,
            color: tone,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedback!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUseSection({required bool hasToken}) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_document, size: 18, color: _blue),
              const SizedBox(width: 8),
              Text(
                l10n.verifyMarkUsedTitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasToken)
            Text(
              l10n.verifyTokenReadHint,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.grey,
                height: 1.45,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: _blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.verifyScanTokenHint,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF37474F),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _buildUseButton(enabled: hasToken),
        ],
      ),
    );
  }

  Widget _buildUseButton({required bool enabled}) {
    final l10n = AppLocalizations.of(context);
    final canUse = enabled && !_isUsing && !_isLoading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canUse ? _useDocument : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isUsing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline, size: 20),
        label: Text(
          _isUsing ? l10n.verifyRecordingUse : l10n.verifyUseDocumentButton,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildInvalidResult(String message) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.verifyFailedTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen QR scanner used by the verifier to read a document QR code.
/// Returns the raw decoded text to the caller, or null when it is closed
/// without a scan (manual entry stays available on every platform).
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _sweepController;

  bool _starting = false;
  bool _handled = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sweepController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_handled || !mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
      case AppLifecycleState.inactive:
        _controller.stop();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _handled || _starting || _startupError != null) return;
    _starting = true;
    try {
      await _controller.start();
    } on MobileScannerException catch (error) {
      // Reported through the controller state and shown by the error view.
      debugPrint('Scanner start failed: ${error.errorCode.name}');
    } catch (error) {
      // No camera implementation on this platform (e.g. desktop without one).
      if (mounted) setState(() => _startupError = error);
    } finally {
      _starting = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  ({IconData icon, String title, String message}) _cameraProblem(Object error) {
    final l10n = AppLocalizations.of(context);
    final code = error is MobileScannerException
        ? error.errorCode
        : MobileScannerErrorCode.genericError;

    if (code == MobileScannerErrorCode.permissionDenied) {
      return (
        icon: Icons.no_photography_outlined,
        title: l10n.verifyCameraPermissionDenied,
        message: l10n.verifyCameraPermissionDeniedMessage,
      );
    }
    if (code == MobileScannerErrorCode.unsupported) {
      return (
        icon: Icons.videocam_off_outlined,
        title: l10n.verifyNoCameraAvailable,
        message: l10n.verifyNoCameraMessage,
      );
    }
    return (
      icon: Icons.error_outline,
      title: l10n.verifyCameraUnavailable,
      message: l10n.verifyCameraUnavailableMessage,
    );
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) =>
                const ColoredBox(color: Colors.black),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final problem = _startupError ?? state.error;
              if (problem != null) return _buildProblemView(problem);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0x66000000)),
                  _buildScanFrame(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(),
                  ),
                ],
              );
            },
          ),
          Positioned(left: 0, right: 0, top: 0, child: _buildTopBar()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: _close,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.verifyScanDocumentQrTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: [
              Text(
                l10n.verifyPositionQrHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTorchButton(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                    label: Text(l10n.verifyEnterIdInstead),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTorchButton() {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        if (!state.isInitialized ||
            state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final enabled = state.torchState == TorchState.on;
        return Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _controller.toggleTorch(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                enabled ? Icons.flashlight_on : Icons.flashlight_off,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanFrame() {
    const double frameSize = 240;
    const double inset = 12;

    return Center(
      child: SizedBox(
        width: frameSize + inset * 2,
        height: frameSize + inset * 2,
        child: Stack(
          children: [
            Positioned(
              left: inset,
              top: inset,
              right: inset,
              bottom: inset,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 16,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: AnimatedBuilder(
                    animation: _sweepController,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(0, _sweepController.value * 2 - 1),
                        child: child,
                      );
                    },
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            _lightBlue,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _lightBlue.withValues(alpha: 0.7),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: inset,
              top: inset,
              child: _corner(
                radius: const BorderRadius.only(topLeft: Radius.circular(16)),
                border: const Border(
                  top: BorderSide(color: Colors.white, width: 4),
                  left: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
            Positioned(
              right: inset,
              top: inset,
              child: _corner(
                radius: const BorderRadius.only(topRight: Radius.circular(16)),
                border: const Border(
                  top: BorderSide(color: Colors.white, width: 4),
                  right: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
            Positioned(
              left: inset,
              bottom: inset,
              child: _corner(
                radius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                ),
                border: const Border(
                  bottom: BorderSide(color: Colors.white, width: 4),
                  left: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
            Positioned(
              right: inset,
              bottom: inset,
              child: _corner(
                radius: const BorderRadius.only(
                  bottomRight: Radius.circular(16),
                ),
                border: const Border(
                  bottom: BorderSide(color: Colors.white, width: 4),
                  right: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner({required BorderRadius radius, required Border border}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(borderRadius: radius, border: border),
    );
  }

  Widget _buildProblemView(Object error) {
    final l10n = AppLocalizations.of(context);
    final problem = _cameraProblem(error);
    return Container(
      color: const Color(0xFF0B1220),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(problem.icon, color: Colors.white70, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            problem.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            problem.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.tonal(
            onPressed: _close,
            child: Text(l10n.verifyEnterDocumentIdInstead),
          ),
        ],
      ),
    );
  }
}
