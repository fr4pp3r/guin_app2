import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/emergency_hotline.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/hotline_provider.dart';
import 'package:guin_app/screens/hotlines/hotline_edit_screen.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Emergency hotline directory — every signed-in user reads the same list.
///
/// Officials who pass [AppRoles.canManageHotlines] get the add FAB and
/// per-card edit/delete affordances; everyone else gets a read-only list.
class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key});

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  HotlineProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = context.read<HotlineProvider>();
      _provider!.loadHotlines();
      _provider!.subscribeToHotlines();
    });
  }

  @override
  void dispose() {
    _provider?.unsubscribe();
    super.dispose();
  }

  Future<void> _openEdit({EmergencyHotline? existing}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HotlineEditScreen(existing: existing),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      // Snackbar must fire on this route — it dies with the edit route.
      Helpers.showSuccessSnackBar(
        context,
        existing == null ? l10n.hotlineAdded : l10n.hotlineUpdated,
      );
      // Refresh here so the change shows even if realtime lags behind.
      _provider?.loadHotlines();
    }
  }

  Future<void> _delete(EmergencyHotline hotline) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: l10n.hotlineDeleteTitle,
      message: l10n.hotlineDeleteConfirmBody(hotline.name),
      confirmText: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<HotlineProvider>();
    final ok = await provider.deleteHotline(hotline.id);
    if (!mounted) return;
    if (ok) {
      Helpers.showSuccessSnackBar(context, l10n.hotlineDeleted);
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(provider.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<HotlineProvider>();
    final role = context.watch<AuthProvider>().userProfile?.role ?? '';
    final canManage = AppRoles.canManageHotlines(role);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.hotlineTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEdit(),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.hotlineNew,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: provider.loadHotlines,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(HotlineProvider provider) {
    // First load with nothing cached yet → spinner.
    if (provider.isLoading && provider.hotlines.isEmpty) {
      return _scrollableCentered(const CircularProgressIndicator());
    }
    if (provider.hotlines.isEmpty) {
      if (provider.error != null) {
        return _errorState(provider);
      }
      return _emptyState();
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: provider.hotlines.length,
      itemBuilder: (context, index) =>
          _hotlineCard(provider.hotlines[index]),
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

  Widget _errorState(HotlineProvider provider) {
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
                l10n.hotlineLoadError,
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
                onPressed: provider.loadHotlines,
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
                  Icons.phone_disabled,
                  size: 52,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.hotlineEmptyTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.hotlineEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hotlineCard(EmergencyHotline hotline) {
    final l10n = AppLocalizations.of(context);
    final role = context.watch<AuthProvider>().userProfile?.role ?? '';
    final canManage = AppRoles.canManageHotlines(role);
    final inactive = !hotline.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: inactive ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inactive
                  ? Colors.grey.withValues(alpha: 0.15)
                  : const Color(0xFFD32F2F).withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: inactive
                          ? Colors.grey.withValues(alpha: 0.10)
                          : const Color(0xFFD32F2F).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.phone_in_talk,
                      size: 18,
                      color: inactive
                          ? Colors.grey
                          : const Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotline.name,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: inactive
                                ? Colors.grey.shade600
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          hotline.number,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: inactive
                                ? Colors.grey.shade500
                                : const Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inactive) ...[
                    const SizedBox(width: 8),
                    _inactiveChip(),
                  ],
                ],
              ),
              if (hotline.description != null &&
                  hotline.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  hotline.description!,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: inactive
                        ? Colors.grey.shade500
                        : Colors.grey.shade700,
                  ),
                ),
              ],
              if (canManage) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openEdit(existing: hotline),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(l10n.commonEdit),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _delete(hotline),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(l10n.commonDelete),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _inactiveChip() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.30)),
      ),
      child: Text(
        l10n.hotlineInactive,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}
