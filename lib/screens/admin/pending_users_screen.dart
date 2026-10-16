import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({super.key});

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingUsers();
    });
  }

  Future<void> _loadPendingUsers() async {
    if (!mounted) return;
    await context.read<UserProvider>().loadPendingUsers();
  }

  Future<void> _handleApprove(UserProfile user) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.auserApproveUserTitle,
      message: l10n.apendApproveConfirm(user.fullName),
    );

    if (!confirm) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, l10n.apendApprovingUser);

    final success = await userProvider.approveUser(user.id);

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (success) {
      Helpers.showSuccessSnackBar(context, l10n.apendUserApproved);
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  Future<void> _handleReject(UserProfile user) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.auserRejectUserTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.auserRejectingName(user.fullName)),
            const SizedBox(height: AppSizes.paddingM),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.commonRejectionReason,
                hintText: l10n.apendRejectReasonHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(
                  context,
                  l10n.commonPleaseProvideReason,
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonReject),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, l10n.apendRejectingUser);

    final success = await userProvider.rejectUser(
      user.id,
      reasonController.text.trim(),
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (success) {
      Helpers.showSuccessSnackBar(context, l10n.apendUserRejected);
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.apendTitle,
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
      body: RefreshIndicator(
        onRefresh: _loadPendingUsers,
        child: userProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : userProvider.pendingUsers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Text(
                      l10n.apendNoPending,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                itemCount: userProvider.pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = userProvider.pendingUsers[index];
                  return _buildUserCard(user);
                },
              ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.profilePhotoUrl != null
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
                  child: user.profilePhotoUrl == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSizes.paddingL),

            // Details
            _buildInfoRow(Icons.location_on, user.address),
            const SizedBox(height: AppSizes.paddingS),
            _buildInfoRow(Icons.calendar_today, l10n.apendYearsOld(user.age)),
            const SizedBox(height: AppSizes.paddingS),
            _buildInfoRow(Icons.phone, user.phoneNumber),
            const SizedBox(height: AppSizes.paddingS),
            _buildInfoRow(
              Icons.access_time,
              l10n.auserRegisteredAt(Helpers.formatDate(user.createdAt)),
            ),

            const SizedBox(height: AppSizes.paddingL),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(user),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l10n.commonReject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(user),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.commonApprove),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
