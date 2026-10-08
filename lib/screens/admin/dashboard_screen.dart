import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:guin_app/config/routes.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userProvider = context.read<UserProvider>();
      _documentProvider = context.read<DocumentProvider>();

      _loadData();
      // Subscribe to real-time updates with callback to reload stats
      _userProvider!.subscribeToUsers();
      _documentProvider!.subscribeToDocuments();

      // Listen to provider changes to reload statistics
      _userProvider!.addListener(_onDataChanged);
      _documentProvider!.addListener(_onDataChanged);
    });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading statistics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '${AppRoles.displayName(userProfile?.role ?? 'admin')} Dashboard',
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.logout, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Confirm Logout'),
                    ],
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Logout'),
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
                              const Text(
                                'Welcome Back!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userProfile?.fullName ?? 'Admin',
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
                  const Text(
                    'User Management',
                    style: TextStyle(
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
                    'Pending Users',
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
                    'Total Users',
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
                  const Text(
                    'Document Requests',
                    style: TextStyle(
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
                        'Pending Payments',
                        _documentStats?['pending_payment']?.toString() ?? '0',
                        Icons.payment,
                        Colors.purple,
                        () => Navigator.of(
                          context,
                        ).pushNamed('/admin/pending-payments'),
                      ),
                    ),
                  if (canVerifyPayments &&
                      (canReviewDocuments || canReleaseDocuments))
                    const SizedBox(width: 12),
                  if (canReviewDocuments || canReleaseDocuments)
                    Expanded(
                      child: _buildStatCard(
                        'Pending Reviews',
                        _documentStats?['pending_review']?.toString() ?? '0',
                        Icons.rate_review,
                        Colors.indigo,
                        () => Navigator.of(
                          context,
                        ).pushNamed('/admin/pending-reviews'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Approved',
                      _documentStats?['approved']?.toString() ?? '0',
                      Icons.check_circle,
                      Colors.green,
                      null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Rejected',
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
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
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
                'View All Requests',
                Icons.list_alt,
                () => Navigator.of(context).pushNamed('/admin/all-requests'),
              ),
              const SizedBox(height: 8),
            ],
            if (canManageUsers) ...[
              _buildActionButton(
                'Manage Users',
                Icons.people,
                () => Navigator.of(context).pushNamed('/admin/pending-users'),
              ),
              const SizedBox(height: 8),
            ],
            if (canManageSettings) ...[
              _buildActionButton(
                'Barangay Settings',
                Icons.settings,
                () => Navigator.of(context).pushNamed('/admin/settings'),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Manage Document Fees',
                Icons.money,
                () => Navigator.of(context).pushNamed('/admin/document-fees'),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'View Document Formats',
                Icons.preview,
                () =>
                    Navigator.of(context).pushNamed('/admin/document-formats'),
              ),
              const SizedBox(height: 8),
            ],
            if (canApproveDocuments) ...[
              _buildActionButton(
                'Captain Approval Queue',
                Icons.approval_outlined,
                () =>
                    Navigator.of(context).pushNamed(AppRoutes.captainApproval),
              ),
              const SizedBox(height: 8),
            ],
            if (canManageReports) ...[
              _buildActionButton(
                'Incident Reports',
                Icons.report,
                () =>
                    Navigator.of(context).pushNamed(AppRoutes.incidentReports),
              ),
              const SizedBox(height: 8),
            ],
            _buildActionButton(
              'Verify Document',
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
    VoidCallback? onTap,
  ) {
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 28, color: color),
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

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
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
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
