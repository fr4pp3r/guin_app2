import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// One decision button rendered in this page's pinned action bar.
///
/// Each queue screen builds its own descriptors (the captain passes
/// Reject + Sign & Release, the secretary passes the status-dependent set its
/// cards used to show inline) so the review page never has to know which
/// workflow it is looking at.
class RequestAction {
  final String label;
  final IconData icon;

  /// Foreground/border color — `AppColors.error` for destructive actions,
  /// the workflow's accent color otherwise.
  final Color color;

  /// true → solid filled button (the primary action), false → outlined.
  final bool filled;
  final Future<void> Function() onPressed;

  const RequestAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });
}

/// Full-page review of a single document request: requestor profile, the
/// submitted details, payment state and the workflow trail, with the
/// caller's decision actions pinned to the bottom.
///
/// This is the only place those actions live — the queue cards navigate here
/// instead of carrying inline buttons, so every decision is made with the
/// complete picture in front of the officer.
class DocumentRequestDetailScreen extends StatefulWidget {
  final DocumentRequest request;
  final List<RequestAction> actions;

  const DocumentRequestDetailScreen({
    super.key,
    required this.request,
    required this.actions,
  });

  @override
  State<DocumentRequestDetailScreen> createState() =>
      _DocumentRequestDetailScreenState();
}

class _DocumentRequestDetailScreenState
    extends State<DocumentRequestDetailScreen> {
  UserProfile? _profile;
  bool _loadingProfile = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService().getUserProfile(widget.request.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });
    } catch (_) {
      // Offline / transient failure — the request details below still render.
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Run one bar action, then return to the queue only if the request was
  /// actually decided. Handlers return the same `Future<void>` on success and
  /// on a cancelled dialog, so we ask the (already reloaded) provider whether
  /// the status moved: unchanged → the officer backed out, stay on this page;
  /// changed or gone from both queues → pop back to the refreshed queue.
  Future<void> _runAction(RequestAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final dp = context.read<DocumentProvider>();
    try {
      await action.onPressed();
    } catch (_) {
      // Handlers surface their own errors; never strand the reviewer here.
    }
    if (!mounted) return;
    if (_wasDecided(dp)) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  bool _wasDecided(DocumentProvider dp) {
    final id = widget.request.id;
    DocumentRequest? current;
    for (final r in dp.pendingReviews) {
      if (r.id == id) {
        current = r;
        break;
      }
    }
    if (current == null) {
      for (final r in dp.forApproval) {
        if (r.id == id) {
          current = r;
          break;
        }
      }
    }
    // No longer queued anywhere → acted on (approved/rejected).
    if (current == null) return true;
    // Still queued with the same status → cancelled dialog or failed action.
    return current.requestStatus != widget.request.requestStatus;
  }

  void _openViewer(String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(title: title, url: url),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Request Review',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.actions.isEmpty ? null : _buildActionBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(r),
          _buildRequestorCard(r),
          _buildRequestDetailsCard(r),
          if (r.paymentRequired) _buildPaymentCard(r),
          _buildTrailCard(r),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeaderCard(DocumentRequest r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1976D2).withValues(alpha: 0.08),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _docIcon(r.documentType),
                    color: const Color(0xFF1976D2),
                    size: 24,
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
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Requested ${Helpers.formatDate(r.requestedAt)}',
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusChip(r),
                if (r.paymentRequired)
                  _pill(
                    color: _paymentColor(r.paymentStatus),
                    icon: Icons.payments_outlined,
                    label: 'Payment ${_capitalize(r.paymentStatus)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(DocumentRequest r) {
    final key = r.statusColor;
    final Color color;
    final IconData icon;
    switch (key) {
      case 'blue':
        color = const Color(0xFF1976D2);
        icon = Icons.pending_actions_outlined;
        break;
      case 'orange':
        color = Colors.orange[800]!;
        icon = Icons.edit_note;
        break;
      case 'green':
        color = Colors.green[700]!;
        icon = Icons.check_circle;
        break;
      case 'teal':
        color = Colors.teal[700]!;
        icon = Icons.verified;
        break;
      case 'red':
        color = AppColors.error;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.blueGrey;
        icon = Icons.info_outline;
        break;
    }
    return _pill(color: color, icon: icon, label: r.statusDisplay);
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green[700]!;
      case 'rejected':
        return AppColors.error;
      case 'pending':
        return Colors.orange[800]!;
      default:
        return Colors.blueGrey;
    }
  }

  // ── Requestor ───────────────────────────────────────────────────────────

  Widget _buildRequestorCard(DocumentRequest r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.person_outline, 'Requestor'),
            const SizedBox(height: 14),
            if (_loadingProfile)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_profile == null)
              _profileUnavailable(r)
            else
              _profileContent(_profile!),
          ],
        ),
      ),
    );
  }

  Widget _profileUnavailable(DocumentRequest r) {
    final fallback = r.userFullName ?? r.userName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          const Text(
            'Requestor profile unavailable',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          if (fallback != null && fallback.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Requested by $fallback',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'The request details below are still complete.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _profileContent(UserProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _requestorAvatar(p),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.fullName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${p.username}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    p.email,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _registrationChip(p.registrationStatus),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _detailRow('Phone number', p.phoneNumber),
        _detailRow('Address', p.address),
        _detailRow('Age', '${p.age} years old'),
        _detailRow('Date of birth', Helpers.formatDate(p.dateOfBirth)),
        _detailRow('Civil status', p.civilStatus),
        _detailRow('Gender', p.gender),
        _detailRow('Place of birth', p.placeOfBirth),
      ],
    );
  }

  Widget _requestorAvatar(UserProfile p) {
    final photo = p.profilePhotoUrl;
    const fallback = Color(0xFF1976D2);
    final Widget inner;
    if (photo == null) {
      inner = Container(
        color: fallback.withValues(alpha: 0.08),
        child: const Icon(Icons.person, size: 34, color: fallback),
      );
    } else {
      inner = Image.network(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: fallback.withValues(alpha: 0.08),
          child: const Icon(Icons.person, size: 34, color: fallback),
        ),
      );
    }
    return InkWell(
      onTap: photo == null ? null : () => _openViewer('Profile photo', photo),
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(child: SizedBox(width: 68, height: 68, child: inner)),
      ),
    );
  }

  Widget _registrationChip(String status) {
    final Color color;
    final IconData icon;
    final String label;
    switch (status) {
      case 'approved':
        color = Colors.green[700]!;
        icon = Icons.check_circle;
        label = 'Approved resident';
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        label = 'Rejected resident';
        break;
      default:
        color = Colors.orange[800]!;
        icon = Icons.hourglass_top;
        label = 'Registration pending';
        break;
    }
    return _pill(color: color, icon: icon, label: label);
  }

  // ── Request details ─────────────────────────────────────────────────────

  Widget _buildRequestDetailsCard(DocumentRequest r) {
    final dataRows = _dataRows(r);
    return _sectionCard(
      icon: Icons.description_outlined,
      title: 'Request details',
      children: [
        const Text(
          'Purpose',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(r.purpose, style: const TextStyle(fontSize: 13)),
        ),
        if (dataRows.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Submitted details',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...dataRows,
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'No additional details were provided with this request.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }

  /// Generic renderer for `document_data`: humanized keys, non-empty values,
  /// dates formatted. The keys are what the request forms in
  /// `request_document_screen.dart` write (full_name, birth_place,
  /// emergency_contact_name, blood_type, …) so the generic pass covers them.
  List<Widget> _dataRows(DocumentRequest r) {
    final rows = <Widget>[];
    r.documentData.forEach((key, value) {
      final text = _humanizeValue(key, value);
      if (text.isEmpty) return;
      // The purpose already has its own highlighted box above.
      if (key == 'purpose' && text == r.purpose.trim()) return;
      rows.add(_detailRow(_humanizeKey(key), text));
    });
    return rows;
  }

  String _humanizeKey(String key) {
    switch (key) {
      case 'tin':
        return 'TIN';
      default:
        break;
    }
    final words = key.split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return key;
    final text = words
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    return text;
  }

  String _humanizeValue(String key, Object? value) {
    if (value == null) return '';
    if (value is bool) return value ? 'Yes' : 'No';
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    if (key == 'birth_date' || key == 'date_of_birth') {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return Helpers.formatDate(parsed);
    }
    return text;
  }

  // ── Payment ─────────────────────────────────────────────────────────────

  Widget _buildPaymentCard(DocumentRequest r) {
    final hasReceipt =
        r.paymentReceiptUrl != null && r.paymentReceiptUrl!.isNotEmpty;
    return _sectionCard(
      icon: Icons.payments_outlined,
      title: 'Payment',
      children: [
        _detailRow('Amount', '₱${r.paymentAmount.toStringAsFixed(2)}'),
        _detailRow('Payment status', _capitalize(r.paymentStatus)),
        if ((r.paymentMethod ?? '').isNotEmpty)
          _detailRow('Method', r.paymentMethod!),
        if ((r.paymentReferenceNumber ?? '').isNotEmpty)
          _detailRow('Reference number', r.paymentReferenceNumber!),
        if (r.paymentVerifiedAt != null)
          _detailRow('Verified', Helpers.formatDate(r.paymentVerifiedAt!)),
        if ((r.paymentRejectionReason ?? '').isNotEmpty)
          _detailRow('Rejection reason', r.paymentRejectionReason!),
        if (hasReceipt) ...[
          const SizedBox(height: 6),
          const Text(
            'Payment receipt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _receiptTile(r.paymentReceiptUrl!),
        ],
      ],
    );
  }

  Widget _receiptTile(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: InkWell(
            onTap: () => _openViewer('Payment receipt', url),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey.shade400,
                        size: 30,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Receipt image unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(right: 8, bottom: 8, child: _ZoomBadge()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap to open full-screen and zoom in.',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Workflow trail ──────────────────────────────────────────────────────

  Widget _buildTrailCard(DocumentRequest r) {
    final rows = <Widget>[];
    void addText(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        rows.add(_detailRow(label, value.trim()));
      }
    }

    void addDate(String label, DateTime? value) {
      if (value != null) rows.add(_detailRow(label, Helpers.formatDate(value)));
    }

    addText('Secretary notes', r.secretaryNotes);
    addText('Invoice description', r.invoiceDescription);
    addDate('Invoice due date', r.invoiceDueDate);
    if ((r.draftUrl ?? '').isNotEmpty) {
      rows.add(
        _detailRow('Draft document', 'Generated — available for review'),
      );
    }
    addText('Rejection reason', r.rejectionReason);
    addText(
      'Approved by',
      r.approverRole == null ? null : AppRoles.displayName(r.approverRole!),
    );
    addDate('Approved on', r.captainApprovedAt);
    addText('Release method', r.releaseMethod);
    addDate('Released on', r.releasedAt);

    if (rows.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.timeline_outlined,
      title: 'Workflow trail',
      children: rows,
    );
  }

  // ── Section scaffolding ────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(icon, title),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1976D2)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  IconData _docIcon(String type) {
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

  // ── Bottom action bar ──────────────────────────────────────────────────

  Widget _buildActionBar() {
    // Two buttons per row — the secretary can hand over up to four actions
    // across statuses, so the bar wraps into rows instead of squeezing.
    final actions = widget.actions;
    final rows = <List<RequestAction>>[];
    for (var i = 0; i < actions.length; i += 2) {
      final end = i + 2 < actions.length ? i + 2 : actions.length;
      rows.add(actions.sublist(i, end));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var j = 0; j < rows[i].length; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(child: _actionButton(rows[i][j])),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(RequestAction action) {
    final onPressed = _busy ? null : () => _runAction(action);
    final label = Text(
      action.label,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    if (action.filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(action.icon, size: 16),
        label: label,
        style: ElevatedButton.styleFrom(
          backgroundColor: action.color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: action.color.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(action.icon, size: 16),
      label: label,
      style: OutlinedButton.styleFrom(
        foregroundColor: action.color,
        side: BorderSide(color: action.color.withValues(alpha: 0.5)),
        disabledForegroundColor: action.color.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.zoom_in, size: 15, color: Colors.white),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String title;
  final String url;

  const _FullScreenImageViewer({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, _, _) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Image failed to load',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
