import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/screens/announcements/announcements_screen.dart';
import 'package:guin_app/screens/tanod/incident_detail_screen.dart';
import 'package:guin_app/screens/tanod/incident_visuals.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Barangay Tanod home screen — incident-first by design.
///
/// A tanod's day is "what's new, what's urgent, what's next", so the screen
/// is: a duty card with the live open/urgent counts, an urgent-first feed of
/// open incidents (priority-filterable), a short list of recently handled
/// reports, and quiet secondary shortcuts. Every write goes through the
/// existing `IncidentReportProvider.updateStatus` on the detail screen; there
/// are no new backend calls, subscriptions, or permission checks beyond
/// `AppRoles`.
class TanodDashboardScreen extends StatefulWidget {
  const TanodDashboardScreen({super.key});

  @override
  State<TanodDashboardScreen> createState() => _TanodDashboardScreenState();
}

class _TanodDashboardScreenState extends State<TanodDashboardScreen> {
  IncidentReportProvider? _reportProvider;
  NotificationProvider? _notificationProvider;

  /// null = show every priority; otherwise only that priority is in the feed.
  String? _priorityFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportProvider = context.read<IncidentReportProvider>();
      _notificationProvider = context.read<NotificationProvider>();
      _loadReports();
      _initNotifications();
    });
  }

  /// Same load + subscribe lifecycle as the admin/citizen dashboards'
  /// notification bell.
  Future<void> _initNotifications() async {
    final userId = context.read<AuthProvider>().userProfile?.id;
    if (userId == null || _notificationProvider == null) return;
    await _notificationProvider!.loadNotifications(userId);
    _notificationProvider!.subscribeToNotifications(userId);
  }

  /// Initial load. `loadAllReports` has no offline cache (unlike the
  /// citizen's own reports), so on failure the provider keeps its error and
  /// the body renders a retry state.
  Future<void> _loadReports() async {
    try {
      await _reportProvider?.loadAllReports();
    } catch (_) {
      // Error is already stored on the provider; the UI reads it from there.
    }
  }

  Future<void> _refresh() async {
    try {
      await _reportProvider?.loadAllReports();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Helpers.showErrorSnackBar(context, l10n.tdashRefreshError);
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    if (confirm == true && mounted) {
      await authProvider.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  static int _openPriorityFirst(IncidentReport a, IncidentReport b) {
    final rank = IncidentVisuals.priorityRank(
      a.priority,
    ).compareTo(IncidentVisuals.priorityRank(b.priority));
    if (rank != 0) return rank;
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;
    final notificationProvider = context.watch<NotificationProvider>();
    final reportProvider = context.watch<IncidentReportProvider>();

    final reports = reportProvider.reports;
    final openIncidents = reports
        .where((r) => IncidentVisuals.isOpen(r.status))
        .toList()
      ..sort(_openPriorityFirst);
    final handledIncidents = reports
        .where((r) => !IncidentVisuals.isOpen(r.status))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final urgentCount = openIncidents
        .where((r) => r.priority == 'urgent')
        .length;
    final highCount = openIncidents.where((r) => r.priority == 'high').length;
    final normalCount = openIncidents
        .where((r) => r.priority == 'normal')
        .length;
    final lowCount = openIncidents.where((r) => r.priority == 'low').length;

    final visibleFeed = _priorityFilter == null
        ? openIncidents
        : openIncidents.where((r) => r.priority == _priorityFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tdashTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              l10n.tdashDutySubtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D3B66), Color(0xFF1565C0)],
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
                      notificationProvider.unreadCount > 99
                          ? '99+'
                          : '${notificationProvider.unreadCount}',
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
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: reportProvider.isLoading && reports.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : reportProvider.error != null && reports.isEmpty
            ? _buildErrorState(l10n)
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Duty card: who you are, what's open, what's urgent ──
                  _buildDutyCard(
                    l10n,
                    userProfile?.fullName ?? '',
                    openIncidents.length,
                    urgentCount,
                  ),
                  const SizedBox(height: 24),

                  // ── Needs attention: priority filter + open feed ──
                  _buildSectionHeader(l10n.tdashNeedsAttention),
                  const SizedBox(height: 12),
                  _buildFilterChips(l10n, {
                    'urgent': urgentCount,
                    'high': highCount,
                    'normal': normalCount,
                    'low': lowCount,
                  }, openIncidents.length),
                  const SizedBox(height: 12),
                  if (visibleFeed.isEmpty)
                    _buildFeedEmpty(l10n)
                  else
                    ...visibleFeed.map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildIncidentCard(l10n, report),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── Recently handled ──
                  if (handledIncidents.isNotEmpty) ...[
                    _buildSectionHeader(l10n.tdashHandledSection),
                    const SizedBox(height: 12),
                    ...handledIncidents
                        .take(3)
                        .map(
                          (report) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildHandledRow(l10n, report),
                          ),
                        ),
                    const SizedBox(height: 4),
                  ],
                  _buildActionButton(
                    l10n.tdashViewAllReports,
                    Icons.list_alt,
                    () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.incidentReports),
                    badgeCount: openIncidents.length,
                  ),
                  const SizedBox(height: 24),

                  // ── Secondary shortcuts ──
                  _buildSectionHeader(l10n.adashQuickActions),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickTile(
                          l10n.adashAnnouncements,
                          Icons.campaign_outlined,
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AnnouncementsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickTile(
                          l10n.adashVerifyDocument,
                          Icons.qr_code_scanner,
                          () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.verifyDocument),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Emergency hotlines — full-width so it stands out; every
                  // signed-in user (tanod included) can open the directory.
                  _buildQuickTile(
                    l10n.adashHotlines,
                    Icons.emergency,
                    () => Navigator.of(context).pushNamed(AppRoutes.hotlines),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────

  Widget _buildDutyCard(
    AppLocalizations l10n,
    String fullName,
    int openCount,
    int urgentCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B66).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_police_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adashWelcomeBack,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullName.isEmpty
                            ? AppRoles.displayName(
                                AppRoles.barangayTanod,
                              )
                            : fullName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$openCount',
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    l10n.tdashOpenIncidents,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: urgentCount > 0
                        ? AppColors.error
                        : AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        urgentCount > 0
                            ? Icons.priority_high
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n.tdashUrgentOpen(urgentCount),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D3B66), Color(0xFF2196F3)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  /// Priority pills — tap to filter the open feed, tap again to clear.
  Widget _buildFilterChips(
    AppLocalizations l10n,
    Map<String, int> counts,
    int totalCount,
  ) {
    Widget chip(String? value, String label, Color color, int count) {
      final selected = _priorityFilter == value;
      return Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => setState(() {
            _priorityFilter = selected ? null : value;
          }),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? color : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip(
            null,
            l10n.tdashFilterAll,
            AppColors.textSecondary,
            totalCount,
          ),
          const SizedBox(width: 8),
          chip(
            'urgent',
            l10n.tdashPriorityUrgent,
            IncidentVisuals.priorityColor('urgent'),
            counts['urgent'] ?? 0,
          ),
          const SizedBox(width: 8),
          chip(
            'high',
            l10n.tdashPriorityHigh,
            IncidentVisuals.priorityColor('high'),
            counts['high'] ?? 0,
          ),
          const SizedBox(width: 8),
          chip(
            'normal',
            l10n.tdashPriorityNormal,
            IncidentVisuals.priorityColor('normal'),
            counts['normal'] ?? 0,
          ),
          const SizedBox(width: 8),
          chip(
            'low',
            l10n.tdashPriorityLow,
            IncidentVisuals.priorityColor('low'),
            counts['low'] ?? 0,
          ),
        ],
      ),
    );
  }

  /// The main feed card: priority color rail, fast-scan metadata, big tap
  /// target. Tap opens the detail screen.
  Widget _buildIncidentCard(AppLocalizations l10n, IncidentReport report) {
    final priorityColor = IncidentVisuals.priorityColor(report.priority);
    final statusColor = IncidentVisuals.statusColor(report.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(report: report),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority rail — instant scanning from the corner of an eye.
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        priorityColor,
                        priorityColor.withValues(alpha: 0.45),
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              IncidentVisuals.reportNumber(report),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Helpers.timeAgo(report.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              IncidentVisuals.typeLabel(
                                l10n,
                                report.reportType,
                              ).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              IncidentVisuals.priorityLabel(
                                l10n,
                                report.priority,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.location,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                IncidentVisuals.statusLabel(
                                  l10n,
                                  report.status,
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (report.isAnonymous || report.isSensitive) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (report.isAnonymous)
                                _badge(l10n.commonAnonymous, Colors.purple),
                              if (report.isSensitive)
                                _badge(
                                  l10n.commonSensitive,
                                  const Color(0xFFEF6C00),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact row for the recently handled list.
  Widget _buildHandledRow(AppLocalizations l10n, IncidentReport report) {
    final statusColor = IncidentVisuals.statusColor(report.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(report: report),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                IncidentVisuals.statusIcon(report.status),
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  IncidentVisuals.statusLabel(l10n, report.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                Helpers.timeAgo(report.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedEmpty(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 36,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.tdashFeedEmpty,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tdashFeedEmptyHint,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.tdashLoadError,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ],
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D3B66), Color(0xFF2196F3)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTile(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
