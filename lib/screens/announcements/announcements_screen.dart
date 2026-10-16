import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/announcement.dart';
import 'package:guin_app/providers/announcement_provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/screens/announcements/announcement_detail_screen.dart';
import 'package:guin_app/screens/announcements/create_announcement_screen.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Barangay announcement feed — every signed-in user reads the same list.
///
/// Officials who pass [AppRoles.canPostAnnouncements] get the create FAB;
/// everyone else gets a read-only feed. Cards open the detail screen, where
/// officials may delete.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  AnnouncementProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = context.read<AnnouncementProvider>();
      _provider!.loadAnnouncements();
      _provider!.subscribeToAnnouncements();
    });
  }

  @override
  void dispose() {
    _provider?.unsubscribe();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final l10n = AppLocalizations.of(context);
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateAnnouncementScreen()),
    );
    if (!mounted) return;
    if (posted == true) {
      // Snackbar must fire on this route — it dies with the create route.
      Helpers.showSuccessSnackBar(context, l10n.annPosted);
      // Refresh here so the new item shows even if realtime lags behind.
      _provider?.loadAnnouncements();
    }
  }

  Future<void> _openDetail(Announcement announcement) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: announcement),
      ),
    );
    if (!mounted) return;
    if (deleted == true) {
      _provider?.loadAnnouncements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AnnouncementProvider>();
    final role = context.watch<AuthProvider>().userProfile?.role ?? '';
    final canPost = AppRoles.canPostAnnouncements(role);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.annFeedTitle,
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
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.annNew,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: provider.loadAnnouncements,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(AnnouncementProvider provider) {
    // First load with nothing cached yet → spinner.
    if (provider.isLoading && provider.announcements.isEmpty) {
      return _scrollableCentered(const CircularProgressIndicator());
    }
    if (provider.announcements.isEmpty) {
      if (provider.error != null) {
        return _errorState(provider);
      }
      return _emptyState();
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: provider.announcements.length,
      itemBuilder: (context, index) =>
          _announcementCard(provider.announcements[index]),
    );
  }

  Widget _scrollableCentered(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
        Center(child: child),
      ],
    );
  }

  Widget _errorState(AnnouncementProvider provider) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.24),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 52,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.annLoadError,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Helpers.parseSupabaseError(provider.error),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: provider.loadAnnouncements,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.27),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  size: 52,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.annFeedEmptyTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.annFeedEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _announcementCard(Announcement announcement) {
    final pinned = announcement.isPinned;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(announcement),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pinned
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pinned
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: pinned
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.07),
                  blurRadius: pinned ? 12 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: pinned
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        pinned ? Icons.push_pin : Icons.campaign_outlined,
                        size: 16,
                        color: pinned ? AppColors.primary : AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (pinned) ...[const SizedBox(width: 8), _pinnedChip()],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  announcement.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${announcement.createdByName}  ·  '
                        '${Helpers.formatDate(announcement.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinnedChip() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Text(
        l10n.annPinned,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
