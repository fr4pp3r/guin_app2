import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/screens/citizen/document_viewer_screen.dart';
import 'package:guin_app/screens/citizen/upload_payment_screen.dart';
import 'package:guin_app/screens/citizen/e_receipt_viewer_screen.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

// ignore_for_file: unused_import

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String _filter = 'all'; // all, pending, approved, rejected, payment

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    if (authProvider.userProfile != null) {
      await documentProvider.loadMyRequests(authProvider.userProfile!.id);
    }
  }

  List<DocumentRequest> _getFilteredRequests(List<DocumentRequest> requests) {
    switch (_filter) {
      case 'pending':
        // Anything still moving through the pipeline (review, draft, invoice,
        // payment, approval). Uses the canonical status set — the old
        // `pending_review`-only filter hid submitted/invoiced requests.
        return requests
            .where((r) => !r.isReleased && !r.isRejected && !r.isCancelled)
            .toList();
      case 'payment':
        return requests
            .where((r) =>
                r.isInvoiced ||
                r.requestStatus == DocStatus.paymentSubmitted ||
                r.requestStatus == DocStatus.paymentRejected ||
                r.requestStatus == DocStatus.pendingPayment)
            .toList();
      case 'approved':
        return requests.where((r) => r.isApproved || r.isReleased).toList();
      case 'rejected':
        return requests.where((r) => r.isRejected).toList();
      default:
        return requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final documentProvider = context.watch<DocumentProvider>();
    final filteredRequests = _getFilteredRequests(documentProvider.myRequests);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
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
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.myRequestsTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.myRequestsSubtitle,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Offline / stale-data banner — visible only when the list is being
          // served from the local cache (network fetch failed). When hidden it
          // collapses to zero height, so it never affects the live layout.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: documentProvider.isFromCache
                  ? Padding(
                      key: const ValueKey('offline-banner'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _buildOfflineBanner(
                        documentProvider.cacheTimestamp,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('offline-banner-absent')),
            ),
          ),

          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(l10n.citizenFilterAll, 'all'),
                  const SizedBox(width: 8),
                  _chip(l10n.citizenFilterPending, 'pending'),
                  const SizedBox(width: 8),
                  _chip(l10n.citizenFilterPayment, 'payment'),
                  const SizedBox(width: 8),
                  _chip(l10n.citizenFilterApproved, 'approved'),
                  const SizedBox(width: 8),
                  _chip(l10n.citizenFilterRejected, 'rejected'),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: documentProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'all'
                                ? l10n.citizenNoRequestsFound
                                : l10n.citizenNoFilteredRequestsFound(
                                    _filterLabel(l10n),
                                  ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.citizenPullDownToRefresh,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) =>
                          _buildRequestCard(filteredRequests[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Soft amber "info" strip shown above the list while the requests on screen
  /// come from the local offline cache instead of the network.
  Widget _buildOfflineBanner(DateTime? savedAt) {
    final l10n = AppLocalizations.of(context);
    final savedLine = savedAt == null
        ? l10n.citizenSavedRequestsHint
        : l10n.citizenSavedRequestsFrom(_formatCacheTime(savedAt));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // amber 50 — warm, never alarming
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 16,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.offlineBanner,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  savedLine,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF616161),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain, locale-aware relative time for the cache timestamp:
  /// "2:14 PM" (today), "yesterday at 2:14 PM", "Oct 10 at 2:14 PM".
  String _formatCacheTime(DateTime savedAt) {
    final l10n = AppLocalizations.of(context);
    final local = savedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(local.year, local.month, local.day);
    final time = DateFormat.jm().format(local);
    final dayDiff = today.difference(thatDay).inDays;

    if (dayDiff <= 0) return time;
    if (dayDiff == 1) return l10n.citizenYesterdayAt(time);
    return l10n.citizenDateAtTime(DateFormat.MMMd().format(local), time);
  }

  /// Localized label for the active filter chip, used in the empty-state
  /// message ("No Pending found", etc.).
  String _filterLabel(AppLocalizations l10n) {
    switch (_filter) {
      case 'pending':
        return l10n.citizenFilterPending;
      case 'payment':
        return l10n.citizenFilterPayment;
      case 'approved':
        return l10n.citizenFilterApproved;
      case 'rejected':
        return l10n.citizenFilterRejected;
      default:
        return l10n.citizenFilterAll;
    }
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : Colors.grey.withValues(alpha: 0.25),
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  Widget _buildRequestCard(DocumentRequest request) {
    final l10n = AppLocalizations.of(context);
    final statusColor = _getStatusColor(request.requestStatus);
    final docIcon = _getDocumentIcon(request.documentType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(docIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 3),
                      Text(
                        l10n.citizenRequestedAt(
                          Helpers.formatDate(request.requestedAt),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.statusDisplay,
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
          // Purpose
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.commonPurpose,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(request.purpose, style: const TextStyle(fontSize: 13)),

                // Rejection reason
                if (request.isRejected && request.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.rejectionReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // View document (in-app, view only — no download)
                if ((request.isApproved || request.isReleased) &&
                    (request.finalDocumentUrl != null ||
                        request.documentUrl != null)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDocumentViewer(request),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(
                        l10n.citizenViewDocument,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],

                // View e-receipt (available for all statuses when e-receipt exists)
                if (request.eReceiptUrl != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openERecceiptViewer(request),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(
                        'View E-Receipt',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],

                // Payment rejection reason (treasurer sent the receipt back)
                if (request.requestStatus == DocStatus.paymentRejected &&
                    request.paymentRejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.paymentRejectionReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Payment needed: invoice sent (no receipt yet) or the last
                // receipt was rejected (citizen must upload a new one).
                // Canonical statuses — `pending_payment` is legacy only.
                if ((request.isInvoiced ||
                        request.requestStatus == DocStatus.paymentRejected ||
                        request.requestStatus == DocStatus.pendingPayment) &&
                    (request.paymentReceiptUrl == null ||
                        request.requestStatus ==
                            DocStatus.paymentRejected)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.citizenPaymentRequiredTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.citizenPayAmountPrompt(request.paymentAmount.toStringAsFixed(2)),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showPaymentDialog(request),
                            icon: const Icon(Icons.payment, size: 16),
                            label: Text(
                              l10n.citizenUploadPaymentReceipt,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Payment submitted, awaiting verification
                if (request.requestStatus == DocStatus.paymentSubmitted ||
                    (request.requestStatus == DocStatus.pendingPayment &&
                        request.paymentReceiptUrl != null)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_bottom,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.citizenPaymentAwaitingVerification,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Pending review / earlier pipeline stages
                if (request.isPendingReview ||
                    request.requestStatus == DocStatus.submitted ||
                    request.requestStatus == DocStatus.draftGenerated ||
                    request.requestStatus == DocStatus.needsRevision ||
                    request.requestStatus == DocStatus.verifiedForPayment ||
                    request.requestStatus == DocStatus.forApproval) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pending_actions,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.citizenRequestUnderReview,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(DocumentRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UploadPaymentScreen(request: request)),
    );
  }

  void _openDocumentViewer(DocumentRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(request: request)),
    );
  }

  void _openERecceiptViewer(DocumentRequest request) {
    Navigator.pushNamed(
      context,
      AppRoutes.eReceipt,
      arguments: request,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_review':
      case 'pending_secretary_review':
        return AppColors.warning;
      case 'pending_payment':
        return const Color(0xFF7B1FA2);
      case 'submitted':
      case 'draft_generated':
      case 'verified_for_payment':
      case 'for_approval':
        return AppColors.primary;
      case 'invoiced':
        // Matches the dashboard invoice card accent.
        return AppColors.accent;
      case 'payment_submitted':
        return Colors.teal;
      case 'payment_rejected':
        return AppColors.error;
      case 'payment_confirmed':
      case 'payment_verified':
      case 'generated':
      case 'approved':
      case 'approved_for_release':
        return AppColors.success;
      case 'released':
        return AppColors.primary;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      case 'needs_revision':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getDocumentIcon(String type) {
    switch (type) {
      case 'barangay_clearance':
        return Icons.description;
      case 'business_clearance':
        return Icons.storefront;
      case 'certification':
        return Icons.verified;
      case 'oath_undertaking':
        return Icons.assignment_turned_in;
      case 'indigency':
        return Icons.volunteer_activism;
      case 'good_moral':
        return Icons.workspace_premium;
      case 'residency':
        return Icons.home;
      case 'cedula':
        return Icons.receipt_long;
      case 'barangay_id':
        return Icons.badge;
      default:
        return Icons.description;
    }
  }
}
