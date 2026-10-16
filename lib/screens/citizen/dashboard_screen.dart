import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/models/announcement.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/providers/announcement_provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/screens/announcements/announcement_detail_screen.dart';
import 'package:guin_app/screens/announcements/announcements_screen.dart';
import 'package:guin_app/screens/citizen/document_viewer_screen.dart';
import 'package:guin_app/screens/citizen/upload_payment_screen.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  DocumentProvider? _documentProvider;
  NotificationProvider? _notificationProvider;
  AnnouncementProvider? _announcementProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _documentProvider = context.read<DocumentProvider>();
      _notificationProvider = context.read<NotificationProvider>();
      _announcementProvider = context.read<AnnouncementProvider>();
      _loadData();
    });
  }

  @override
  void dispose() {
    // Unsubscribe when leaving the screen
    _documentProvider?.unsubscribeFromDocuments();
    _notificationProvider?.unsubscribe();
    _announcementProvider?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted ||
        _documentProvider == null ||
        _notificationProvider == null ||
        _announcementProvider == null) {
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final barangayProvider = context.read<BarangayProvider>();

    if (authProvider.userProfile != null) {
      await _documentProvider!.loadMyRequests(authProvider.userProfile!.id);
      await _notificationProvider!.loadNotifications(
        authProvider.userProfile!.id,
      );
      await _announcementProvider!.loadAnnouncements();

      // GCash details for the dashboard invoice card — only fetched when a
      // request is actually waiting for payment.
      if (_documentProvider!.myRequests.any((r) => r.isInvoiced) &&
          barangayProvider.config == null) {
        try {
          await barangayProvider.loadConfig();
        } catch (e) {
          debugPrint('Barangay config load failed: $e');
        }
      }

      // Subscribe to real-time updates using stored providers
      _documentProvider!.subscribeToUserDocuments(authProvider.userProfile!.id);
      _notificationProvider!.subscribeToNotifications(
        authProvider.userProfile!.id,
      );
      _announcementProvider!.subscribeToAnnouncements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final documentProvider = context.watch<DocumentProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final announcementProvider = context.watch<AnnouncementProvider>();
    final barangayProvider = context.watch<BarangayProvider>();
    final userProfile = authProvider.userProfile;

    // First request still awaiting payment, if any — drives the invoice card
    // shown above the dashboard sections.
    DocumentRequest? invoiceRequest;
    for (final request in documentProvider.myRequests) {
      if (request.isInvoiced) {
        invoiceRequest = request;
        break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header with welcome
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
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.profile);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFF0F4FF),
                          backgroundImage: userProfile?.profilePhotoUrl != null
                              ? NetworkImage(userProfile!.profilePhotoUrl!)
                              : null,
                          child: userProfile?.profilePhotoUrl == null
                              ? Text(
                                  Helpers.getInitials(
                                    userProfile?.fullName ?? 'U',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.citizenWelcomeBack,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userProfile?.fullName ?? l10n.citizenFallbackName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Notifications
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.notifications,
                          ),
                        ),
                        if (notificationProvider.unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                '${notificationProvider.unreadCount}',
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
                    ),
                    // Logout
                    IconButton(
                      icon: const Icon(
                        Icons.logout_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () async {
                        final confirm = await Helpers.showConfirmDialog(
                          context,
                          title: l10n.commonLogout,
                          message: l10n.citizenLogoutConfirm,
                        );
                        if (confirm && context.mounted) {
                          await authProvider.signOut();
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.paddingM,
                  AppSizes.paddingL,
                  AppSizes.paddingM,
                  AppSizes.paddingXL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // Quick Actions Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.citizenQuickActions,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingL),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.file_copy,
                            title: l10n.citizenRequestDocument.replaceAll(
                              ' ',
                              '\n',
                            ),
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.requestDocument,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.history,
                            title: l10n.myRequestsTitle.replaceAll(' ', '\n'),
                            color: AppColors.secondary,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.myRequests,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.report_problem,
                            title: l10n.citizenReportIncident.replaceAll(
                              ' ',
                              '\n',
                            ),
                            color: AppColors.warning,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.submitReport,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.qr_code_scanner,
                            title: l10n.citizenVerifyDocument.replaceAll(
                              ' ',
                              '\n',
                            ),
                            color: Colors.teal,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.verifyDocument,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.list_alt,
                            title: l10n.myReportsTitle.replaceAll(' ', '\n'),
                            color: AppColors.accent,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.myReports);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Invoice call-to-action — the first request still waiting
                    // for payment, kept above every other section so the citizen
                    // can pay without opening My Requests.
                    if (invoiceRequest != null) ...[
                      _buildInvoiceCard(
                        context,
                        invoiceRequest,
                        l10n,
                        barangayProvider,
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Announcements Section — hidden entirely when nothing
                    // has been posted (no empty card).
                    if (announcementProvider.announcements.isNotEmpty) ...[
                      _buildAnnouncementsSection(
                        announcementProvider.announcements,
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Request Statistics Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.citizenYourRequests,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            l10n.citizenStatTotal,
                            documentProvider.myRequests.length.toString(),
                            Icons.description,
                            AppColors.primary,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.myRequests,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: _buildStatCard(
                            l10n.citizenStatPending,
                            documentProvider.myRequests
                                .where((r) => r.isInProgress)
                                .length
                                .toString(),
                            Icons.pending,
                            AppColors.warning,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.myRequests,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: _buildStatCard(
                            l10n.citizenStatApproved,
                            documentProvider.myRequests
                                .where((r) => r.isApprovedOrReleased)
                                .length
                                .toString(),
                            Icons.check_circle,
                            AppColors.success,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.myRequests,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingXL),

                    // Recent Requests Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.citizenRecentRequests,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.myRequests);
                          },
                          child: Text(
                            l10n.citizenViewAll,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (documentProvider.isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.paddingXL),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(strokeWidth: 3),
                              const SizedBox(height: AppSizes.paddingM),
                              Text(
                                l10n.citizenLoadingRequests,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (documentProvider.myRequests.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.paddingXL),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: Icon(
                                  Icons.inbox_outlined,
                                  size: 56,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingL),
                              Text(
                                l10n.citizenNoRequests,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.citizenCreateFirstRequest,
                                style: TextStyle(
                                  color: Colors.grey.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...documentProvider.myRequests.take(3).map((request) {
                        final viewable =
                            (request.isApproved || request.isReleased) &&
                            (request.finalDocumentUrl != null ||
                                request.documentUrl != null);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (viewable) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DocumentViewerScreen(request: request),
                                  ),
                                );
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.myRequests,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSizes.paddingL,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              request.requestStatus,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _getDocumentIcon(
                                              request.documentType,
                                            ),
                                            color: _getStatusColor(
                                              request.requestStatus,
                                            ),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                request.documentTypeDisplay,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                l10n.citizenRequestedLabel(
                                                  Helpers.formatDate(
                                                    request.requestedAt,
                                                  ),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w400,
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
                                            color: _getStatusColor(
                                              request.requestStatus,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            request.statusDisplay,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(
                                                request.requestStatus,
                                              ),
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
                      }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent call-to-action for the first request awaiting payment. The card
  /// itself and its button both open the receipt upload screen, exactly like
  /// the payment prompt in My Requests.
  Widget _buildInvoiceCard(
    BuildContext context,
    DocumentRequest request,
    AppLocalizations l10n,
    BarangayProvider barangayProvider,
  ) {
    const invoiceInk = Color(0xFFBF3600);
    final config = barangayProvider.config;
    final dueDate = request.invoiceDueDate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openUploadPayment(request),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title: "Payment due" + document type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getDocumentIcon(request.documentType),
                      color: invoiceInk,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.citizenInvoicePaymentDue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: invoiceInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.documentTypeDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount + due date
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.citizenInvoiceAmount,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱${request.paymentAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: invoiceInk,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: dueDate != null
                              ? invoiceInk.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: dueDate != null
                                  ? invoiceInk
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dueDate != null
                                    ? l10n.citizenInvoiceDueDate(
                                        Helpers.formatDate(dueDate),
                                      )
                                    : l10n.citizenInvoiceNoDueDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: dueDate != null
                                      ? invoiceInk
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // GCash details (same source as the upload payment screen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: config != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  config.gcashName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_android,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  config.gcashNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _copyGcashNumber(config.gcashNumber, l10n),
                                tooltip: l10n.citizenInvoiceCopyGcashNumber,
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          if (barangayProvider.isLoading)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green.shade600,
                              ),
                            )
                          else
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.payLoadingGcash,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openUploadPayment(request),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(
                    l10n.citizenUploadPaymentReceipt,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: invoiceInk,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.myRequests);
                  },
                  child: Text(
                    l10n.citizenInvoiceViewAllRequests,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the receipt upload screen for [request] — same navigation My
  /// Requests uses for its payment prompt.
  void _openUploadPayment(DocumentRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UploadPaymentScreen(request: request)),
    );
  }

  /// Copies the barangay GCash number so the citizen can paste it into GCash.
  Future<void> _copyGcashNumber(String number, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: number));
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.citizenInvoiceGcashNumberCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Section header plus the latest two announcements. Only rendered when the
  /// provider list is non-empty, so the section never shows an empty card.
  Widget _buildAnnouncementsSection(List<Announcement> announcements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'See all ›',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...announcements.take(2).map(_buildAnnouncementPreviewCard),
      ],
    );
  }

  /// Preview card for one announcement (title + body preview) on the feed.
  Widget _buildAnnouncementPreviewCard(Announcement announcement) {
    final pinned = announcement.isPinned;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AnnouncementDetailScreen(announcement: announcement),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pinned
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pinned ? Icons.push_pin : Icons.campaign_outlined,
                    size: 16,
                    color: pinned ? AppColors.primary : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                announcement.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${announcement.createdByName}  ·  '
                '${Helpers.formatDate(announcement.createdAt)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.3,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
      case 'payment_submitted':
      case 'pending_review':
      case 'pending_secretary_review':
      case 'needs_revision':
        return AppColors.warning;
      // Invoiced renders orange in the model's statusColor.
      case 'invoiced':
        return AppColors.accent;
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
