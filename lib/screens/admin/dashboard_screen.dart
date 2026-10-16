import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/screens/announcements/announcements_screen.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, int>? _documentStats;
  Map<String, int>? _userStats;
  UserProvider? _userProvider;
  DocumentProvider? _documentProvider;
  NotificationProvider? _notificationProvider;
  IncidentReportProvider? _reportProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userProvider = context.read<UserProvider>();
      _documentProvider = context.read<DocumentProvider>();
      _notificationProvider = context.read<NotificationProvider>();
      _reportProvider = context.read<IncidentReportProvider>();

      _loadData();
      // Subscribe to real-time updates with callback to reload stats
      _userProvider!.subscribeToUsers();
      _documentProvider!.subscribeToDocuments();

      // Listen to provider changes to reload statistics
      _userProvider!.addListener(_onDataChanged);
      _documentProvider!.addListener(_onDataChanged);

      // Notification bell: same load + subscribe lifecycle as the citizen
      // dashboard (unsubscribed in dispose).
      _initNotifications();

      // Queue counts behind the role-gated badges below.
      _loadQueueCounts(context.read<AuthProvider>().userProfile?.role ?? '');
    });
  }

  Future<void> _initNotifications() async {
    final userId = context.read<AuthProvider>().userProfile?.id;
    if (userId == null || _notificationProvider == null) return;
    await _notificationProvider!.loadNotifications(userId);
    _notificationProvider!.subscribeToNotifications(userId);
  }

  /// Refresh the role-appropriate work queues so the dashboard badges show
  /// live counts. Runs once per dashboard open — no new realtime
  /// subscriptions are created here, only provider state is reused.
  void _loadQueueCounts(String role) {
    final docs = _documentProvider;
    final users = _userProvider;
    if (docs != null) {
      if (AppRoles.canReviewDocuments(role)) {
        docs.loadPendingReviews();
      }
      if (AppRoles.canApproveDocuments(role)) {
        docs.loadForApproval();
      }
      if (AppRoles.canVerifyPayments(role)) {
        docs.loadPendingPayments();
      }
    }
    if (users != null && AppRoles.canManageUsers(role)) {
      users.loadPendingUsers();
    }
    if (AppRoles.canManageReports(role)) {
      _reportProvider?.loadAllReports();
    }
  }

  void _onDataChanged() {
    // Reload statistics when data changes
    _loadData();
  }

  @override
  void dispose() {
    // Remove listeners first
    _userProvider?.removeListener(_onDataChanged);
    _documentProvider?.removeListener(_onDataChanged);

    // Unsubscribe from real-time updates
    _userProvider?.unsubscribeFromUsers();
    _documentProvider?.unsubscribeFromDocuments();
    _notificationProvider?.unsubscribe();

    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted || _userProvider == null || _documentProvider == null) return;

    try {
      final docStats = await _documentProvider!.getStatistics();
      final usrStats = await _userProvider!.getUserStatistics();

      if (mounted) {
        setState(() {
          _documentStats = docStats;
          _userStats = usrStats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).adashLoadStatsError('$e'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;
    final role = userProfile?.role ?? '';
    final canManageUsers = AppRoles.canManageUsers(role);
    final canVerifyPayments = AppRoles.canVerifyPayments(role);
    final canReviewDocuments = AppRoles.canReviewDocuments(role);
    final canReleaseDocuments = AppRoles.canReleaseDocuments(role);
    final canApproveDocuments = AppRoles.canApproveDocuments(role);
    final canManageReports = AppRoles.canManageReports(role);
    final canManageSettings =
        role == AppRoles.captain || role == AppRoles.legacyAdmin;

    // Watched so the badge counts rebuild as soon as a provider reloads.
    final userProvider = context.watch<UserProvider>();
    final documentProvider = context.watch<DocumentProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final reportProvider = context.watch<IncidentReportProvider>();

    // Reports still needing action: everything not resolved/closed/dismissed
    // (the terminal statuses offered in IncidentReportsScreen).
    final openIncidents = reportProvider.reports
        .where(
          (r) =>
              r.status != 'resolved' &&
              r.status != 'closed' &&
              r.status != 'dismissed',
        )
        .length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.adashTitle(AppRoles.displayName(userProfile?.role ?? 'admin')),
          style: const TextStyle(fontWeight: FontWeight.w600),
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
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: l10n.notificationsTitle,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.notifications),
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
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: l10n.profileMyProfile,
            onPressed: () => Navigator.of(context).pushNamed('/admin/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.commonLogout,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.orange),
                      const SizedBox(width: 12),
                      Text(l10n.adashConfirmLogoutTitle),
                    ],
                  ),
                  content: Text(l10n.adashConfirmLogoutMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.commonCancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(l10n.commonLogout),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Welcome Card with Gradient
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.adashWelcomeBack,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userProfile?.fullName ?? l10n.adashFallbackAdmin,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // User Statistics
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.adashUserManagement,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    l10n.adashStatPendingUsers,
                    _userStats?['pending_users']?.toString() ?? '0',
                    Icons.person_add,
                    Colors.orange,
                    () =>
                        Navigator.of(context).pushNamed('/admin/pending-users'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    l10n.adashStatTotalUsers,
                    _userStats?['total_users']?.toString() ?? '0',
                    Icons.people,
                    Colors.blue,
                    null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Document Statistics
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.adashDocumentRequests,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (canVerifyPayments ||
                canReviewDocuments ||
                canReleaseDocuments) ...[
              Row(
                children: [
                  if (canVerifyPayments)
                    Expanded(
                      child: _buildStatCard(
                        l10n.adashStatPendingPayments,
                        _documentStats?['pending_payment']?.toString() ?? '0',
                        Icons.payment,
                        Colors.purple,
                        () => Navigator.of(
                          context,
                        ).pushNamed('/admin/pending-payments'),
                        badgeCount: documentProvider.pendingPayments.length,
                      ),
                    ),
                  if (canVerifyPayments &&
                      (canReviewDocuments || canReleaseDocuments))
                    const SizedBox(width: 12),
                  if (canReviewDocuments || canReleaseDocuments)
                    Expanded(
                      child: _buildStatCard(
                        l10n.adashStatPendingReviews,
                        _documentStats?['pending_review']?.toString() ?? '0',
                        Icons.rate_review,
                        Colors.indigo,
                        () => Navigator.of(
                          context,
                        ).pushNamed('/admin/pending-reviews'),
                        badgeCount: documentProvider.pendingReviews.length,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      l10n.adashStatApproved,
                      _documentStats?['approved']?.toString() ?? '0',
                      Icons.check_circle,
                      Colors.green,
                      null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      l10n.adashStatRejected,
                      _documentStats?['rejected']?.toString() ?? '0',
                      Icons.cancel,
                      Colors.red,
                      null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Quick Actions
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.adashQuickActions,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (canReviewDocuments ||
                canReleaseDocuments ||
                canVerifyPayments) ...[
              _buildActionButton(
                l10n.adashViewAllRequests,
                Icons.list_alt,
                () => Navigator.of(context).pushNamed('/admin/all-requests'),
              ),
              const SizedBox(height: 8),
            ],
            if (canManageUsers) ...[
              _buildActionButton(
                l10n.adashManageUsers,
                Icons.people,
                () => Navigator.of(context).pushNamed('/admin/pending-users'),
                badgeCount: userProvider.pendingUsers.length,
              ),
              const SizedBox(height: 8),
            ],
            if (canManageSettings) ...[
              _buildActionButton(
                l10n.adashBarangaySettings,
                Icons.settings,
                () => Navigator.of(context).pushNamed('/admin/settings'),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                l10n.adashManageDocumentFees,
                Icons.money,
                () => Navigator.of(context).pushNamed('/admin/document-fees'),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                l10n.adashViewDocumentFormats,
                Icons.preview,
                () =>
                    Navigator.of(context).pushNamed('/admin/document-formats'),
              ),
              const SizedBox(height: 8),
            ],
            if (canApproveDocuments) ...[
              _buildActionButton(
                l10n.adashCaptainApprovalQueue,
                Icons.approval_outlined,
                () =>
                    Navigator.of(context).pushNamed(AppRoutes.captainApproval),
                badgeCount: documentProvider.forApproval.length,
              ),
              const SizedBox(height: 8),
            ],
            if (canManageReports) ...[
              _buildActionButton(
                l10n.adashIncidentReports,
                Icons.report,
                () =>
                    Navigator.of(context).pushNamed(AppRoutes.incidentReports),
                badgeCount: openIncidents,
              ),
              const SizedBox(height: 8),
            ],
            // Announcements — every official can read; the create FAB inside
            // the feed handles posting rights, so no role gate here.
            _buildActionButton(
              l10n.adashAnnouncements,
              Icons.campaign_outlined,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              l10n.adashVerifyDocument,
              Icons.qr_code_scanner,
              () => Navigator.of(context).pushNamed(AppRoutes.verifyDocument),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, size: 28, color: color),
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              top: -6,
                              right: -8,
                              child: _countPill(badgeCount),
                            ),
                        ],
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 8),
                  _countPill(badgeCount),
                ],
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small red pill showing how many items are waiting in a queue.
  /// Hidden by every caller when the count is zero.
  Widget _countPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
