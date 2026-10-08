import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  UserProvider? _userProvider;
  DocumentProvider? _documentProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userProvider = context.read<UserProvider>();
      _documentProvider = context.read<DocumentProvider>();
      
      _loadData();
      // Subscribe to real-time updates
      _userProvider!.subscribeToUsers();
      _documentProvider!.subscribeToDocuments();
    });
  }

  @override
  void dispose() {
    // Unsubscribe when leaving the screen
    _userProvider?.unsubscribeFromUsers();
    _documentProvider?.unsubscribeFromDocuments();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted || _userProvider == null || _documentProvider == null) return;

    await Future.wait([
      _userProvider!.loadPendingUsers(),
      _documentProvider!.loadPendingReviews(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final documentProvider = context.watch<DocumentProvider>();

    final userProfile = authProvider.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await Helpers.showConfirmDialog(
                context,
                title: 'Logout',
                message: 'Are you sure you want to logout?',
              );
              if (confirm) {
                await authProvider.signOut();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                userProfile?.profilePhotoUrl != null
                                ? NetworkImage(userProfile!.profilePhotoUrl!)
                                : null,
                            child: userProfile?.profilePhotoUrl == null
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${userProfile?.fullName ?? "Admin"}!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Barangay Administrator',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
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
              const SizedBox(height: AppSizes.paddingL),

              // Statistics
              const Text(
                'Pending Approvals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Users',
                      count: userProvider.pendingUsers.length,
                      icon: Icons.people_outline,
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pushNamed(context, '/admin/pending-users');
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Requests',
                      count: documentProvider.pendingReviews.length,
                      icon: Icons.description_outlined,
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.pushNamed(context, '/admin/pending-requests');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingXL),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _buildQuickActionCard(
                title: 'Review Pending Users',
                subtitle:
                    '${userProvider.pendingUsers.length} waiting for approval',
                icon: Icons.person_add,
                color: AppColors.primary,
                onTap: () {
                  Navigator.pushNamed(context, '/admin/pending-users');
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              _buildQuickActionCard(
                title: 'Review Document Requests',
                subtitle:
                    '${documentProvider.pendingReviews.length} pending reviews',
                icon: Icons.description,
                color: AppColors.warning,
                onTap: () {
                  Navigator.pushNamed(context, '/admin/pending-requests');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: AppSizes.paddingS),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
