import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:guin_app/screens/admin/create_user_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadPendingUsers();
      context.read<UserProvider>().loadAllUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Pending users actions ────────────────────────────────────────────────

  Future<void> _handleApprove(UserProfile user) async {
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Approve User',
      message: 'Approve ${user.fullName}?',
    );
    if (!confirm) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, 'Approving...');
    final ok = await userProvider.approveUser(user.id);
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Helpers.showSuccessSnackBar(context, 'User approved');
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  Future<void> _handleReject(UserProfile user) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rejecting: ${user.fullName}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Provide a reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, 'Please provide a reason');
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, 'Rejecting...');
    final ok = await userProvider.rejectUser(
      user.id,
      reasonController.text.trim(),
    );
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Helpers.showSuccessSnackBar(context, 'Registration rejected');
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  // ── All users actions ───────────────────────────────────────────────────

  Future<void> _handleChangeRole(UserProfile user) async {
    String selectedRole = user.role;
    final roles = [
      'citizen',
      'secretary',
      'treasurer',
      'kagawad_representative',
      'barangay_tanod',
      'captain',
      'admin',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(AppRoles.displayName(r)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setS(() => selectedRole = v ?? selectedRole),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;
    Helpers.showLoadingDialog(context, 'Updating role...');
    final userProvider = context.read<UserProvider>();
    final ok = await userProvider.updateUserRole(user.id, selectedRole);
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Helpers.showSuccessSnackBar(
        context,
        'Role updated to ${AppRoles.displayName(selectedRole)}',
      );
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  Future<void> _handleDeleteUser(UserProfile user) async {
    final myId = context.read<AuthProvider>().userProfile?.id;
    if (user.id == myId) {
      Helpers.showErrorSnackBar(context, 'You cannot delete your own account');
      return;
    }
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Delete User',
      message: 'Permanently delete ${user.fullName}? This cannot be undone.',
    );
    if (!confirm || !mounted) return;

    Helpers.showLoadingDialog(context, 'Deleting...');
    final userProvider = context.read<UserProvider>();
    final ok = await userProvider.deleteUser(user.id);
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Helpers.showSuccessSnackBar(context, 'User deleted');
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  // ── Create user ─────────────────────────────────────────────────────────

  void _openCreateUserScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
    if (mounted) {
      context.read<UserProvider>().loadAllUsers();
      _tabController.animateTo(1);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Manage Users',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Pending (${userProvider.pendingUsers.length})',
              icon: const Icon(Icons.hourglass_empty, size: 18),
            ),
            Tab(
              text: 'All Users (${userProvider.allUsers.length})',
              icon: const Icon(Icons.people, size: 18),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserScreen,
        icon: const Icon(Icons.person_add),
        label: const Text('Create User'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(userProvider),
          _buildAllUsersTab(userProvider),
        ],
      ),
    );
  }

  // ── Pending tab ─────────────────────────────────────────────────────────

  Widget _buildPendingTab(UserProvider userProvider) {
    return RefreshIndicator(
      onRefresh: () => userProvider.loadPendingUsers(),
      child: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProvider.pendingUsers.isEmpty
          ? _emptyState(
              'No pending registrations',
              Icons.check_circle_outline,
              Colors.green,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: userProvider.pendingUsers.length,
              itemBuilder: (_, i) =>
                  _buildPendingCard(userProvider.pendingUsers[i]),
            ),
    );
  }

  Widget _buildPendingCard(UserProfile user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.profilePhotoUrl != null
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
                  child: user.profilePhotoUrl == null
                      ? const Icon(Icons.person, size: 26)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_kycBadgeData(user) != null) ...[
              const SizedBox(height: 10),
              _kycBadge(_kycBadgeData(user)!),
            ],
            const Divider(height: 20),
            _infoRow(Icons.location_on, user.address),
            const SizedBox(height: 4),
            _infoRow(Icons.cake, '${user.age} years old · ${user.gender}'),
            const SizedBox(height: 4),
            _infoRow(Icons.phone, user.phoneNumber),
            const SizedBox(height: 4),
            _infoRow(
              Icons.access_time,
              'Registered: ${Helpers.formatDate(user.createdAt)}',
            ),
            // ID info
            if (user.kycIdType != null) ...[
              const SizedBox(height: 4),
              _infoRow(
                Icons.badge_outlined,
                '${KycIdTypes.label(user.kycIdType)}: ${user.kycIdNumber ?? "N/A"}',
              ),
            ],
            if (user.idIssuedAt != null) ...[
              const SizedBox(height: 4),
              _infoRow(
                Icons.event_available,
                'ID issued: ${Helpers.formatDate(user.idIssuedAt!)}',
              ),
            ],
            if (user.idExpiryAt != null) ...[
              const SizedBox(height: 4),
              _infoRow(
                Icons.event_busy,
                'ID expires: ${Helpers.formatDate(user.idExpiryAt!)}',
              ),
            ],
            // Liveness info
            if (user.livenessVerified) ...[
              const SizedBox(height: 4),
              _infoRow(
                Icons.face_retouching_natural,
                'Liveness verified${user.livenessVerifiedAt != null ? " on ${Helpers.formatDate(user.livenessVerifiedAt!)}" : ""}',
              ),
            ],
            // Indigent info
            if (user.isIndigent &&
                (user.indigencyReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              _infoRow(
                Icons.speaker_notes_outlined,
                'Indigency reason: ${user.indigencyReason}',
              ),
            ],
            const SizedBox(height: 12),
            _kycPhotoRow(user),
            if (user.kycAiResult != null) ...[
              const SizedBox(height: 4),
              _kycAiSummary(user.kycAiResult!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(user),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(user),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
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
          ],
        ),
      ),
    );
  }

  // ── KYC pre-check surface on pending cards ──────────────────────────────

  ({String label, Color color, IconData icon})? _kycBadgeData(
    UserProfile user,
  ) {
    switch (user.kycMethod) {
      case 'ai_verified':
        return (
          label: 'AI pre-checked',
          color: const Color(0xFF1976D2),
          icon: Icons.auto_awesome,
        );
      case 'indigent_bypass':
        return (
          label: 'Indigent — guarantor verification required',
          color: Colors.orange[800]!,
          icon: Icons.priority_high,
        );
      case 'guarantor_verified':
        return (
          label: 'Guarantor-backed',
          color: Colors.teal[700]!,
          icon: Icons.verified_user,
        );
      default:
        return null;
    }
  }

  Widget _kycBadge(({String label, Color color, IconData icon}) data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 12, color: data.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              data.label,
              style: TextStyle(
                fontSize: 11,
                color: data.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact side-by-side thumbnails so the reviewer can compare the profile
  /// photo against the uploaded ID (front + back).
  Widget _kycPhotoRow(UserProfile user) {
    final idLabel = user.isIndigent ? 'Certificate of Indigency' : 'ID';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _kycThumb(user.profilePhotoUrl, 'Profile photo'),
            ),
            const SizedBox(width: 12),
            Expanded(child: _kycThumb(user.validIdUrl, '$idLabel — front')),
          ],
        ),
        if (user.validIdBackUrl != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kycThumb(user.validIdBackUrl, '$idLabel — back'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _kycThumb(String? url, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 92,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: url == null
                ? Icon(Icons.image_outlined, color: Colors.grey.shade400)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Collapsible, read-only summary of the stored AI pre-check. Keeps the
  /// card scannable while giving the reviewer the machine's reasoning.
  Widget _kycAiSummary(Map<String, dynamic> kyc) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        dense: true,
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        leading: const Icon(
          Icons.auto_awesome,
          size: 16,
          color: Color(0xFF1976D2),
        ),
        title: const Text(
          'AI advisory summary',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          ..._kycSummaryRows(kyc),
          const SizedBox(height: 4),
          const Text(
            'AI-assisted advisory — final review by the barangay.',
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
    );
  }

  List<Widget> _kycSummaryRows(Map<String, dynamic> kyc) {
    final rows = <Widget>[];
    void addRow(String label, String value) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ),
      );
    }

    // ID authenticity
    final idAuthenticity = _kycString(
      kyc,
      ['id_authenticity', 'idAuthenticity'],
    );
    if (idAuthenticity != null) {
      addRow('ID authenticity', _idAuthenticityLabel(idAuthenticity));
    }

    // ID type guess/match
    final idTypeGuess = _kycString(
      kyc,
      ['id_type_guess', 'idTypeGuess'],
    );
    final idTypeMatch = _kycString(
      kyc,
      ['id_type_match', 'idTypeMatch'],
    );
    if (idTypeGuess != null) {
      addRow('ID type detected', _idTypeGuessLabel(idTypeGuess));
    }
    if (idTypeMatch != null) {
      addRow('Type match', idTypeMatch == 'true' ? 'Matches declared type' : 'Does not match declared type');
    }

    // Selfie quality
    final selfieQuality = _kycString(
      kyc,
      ['selfie_quality', 'selfieQuality'],
    );
    if (selfieQuality != null) {
      addRow('Selfie quality', _selfieQualityLabel(selfieQuality));
    }

    // Liveness spoof signal
    final liveness = _kycMap(kyc, ['liveness']);
    final spoofSignal = liveness != null
        ? _kycString(liveness, ['spoof_signal', 'spoofSignal'])
        : _kycString(kyc, ['liveness_spoof_signal']);
    if (spoofSignal != null) {
      addRow('Liveness signal', _spoofSignalLabel(spoofSignal));
    }

    // Liveness notes
    final livenessNotes = liveness != null
        ? _kycString(liveness, ['notes'])
        : _kycString(kyc, ['liveness_notes']);
    if (livenessNotes != null) {
      addRow('Liveness notes', livenessNotes);
    }

    // Field checks
    final fieldChecks = _kycMap(kyc, ['field_checks', 'fieldChecks']);
    if (fieldChecks != null) {
      fieldChecks.forEach((key, value) {
        addRow(_fieldCheckLabel(key), _fieldCheckValue(value));
      });
    }

    // Recommendation
    final recommendation = _kycString(kyc, ['recommendation']);
    if (recommendation != null) {
      addRow('Recommendation', _recommendationLabel(recommendation));
    }

    // Reasons
    final reasons = _kycReasons(kyc, ['reasons']);
    if (reasons.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 126, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: reasons
                .take(4)
                .map(
                  (r) => Text(
                    '• $r',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    // Prompt version
    final promptVersion = _kycString(kyc, ['prompt_version', 'promptVersion']);
    if (promptVersion != null) {
      addRow('Check version', promptVersion);
    }

    return rows;
  }

  String? _kycString(Map<String, dynamic> kyc, List<String> keys) {
    for (final key in keys) {
      final value = kyc[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic>? _kycMap(Map<String, dynamic> kyc, List<String> keys) {
    for (final key in keys) {
      final value = kyc[key];
      if (value is Map<String, dynamic>) return value;
    }
    return null;
  }

  List<String> _kycReasons(Map<String, dynamic> kyc, List<String> keys) {
    for (final key in keys) {
      final value = kyc[key];
      if (value is List) return value.whereType<String>().toList();
    }
    return const [];
  }

  String _idAuthenticityLabel(String value) {
    switch (value) {
      case 'authentic':
        return 'Looks authentic';
      case 'suspicious':
        return 'Suspicious — needs closer look';
      case 'unreadable':
        return 'Unreadable';
      case 'uncertain':
        return 'Uncertain';
      default:
        return value;
    }
  }

  String _idTypeGuessLabel(String value) {
    switch (value) {
      case 'barangay_id':
        return 'Barangay ID';
      case 'drivers_license':
        return "Driver's License";
      case 'passport':
        return 'Passport';
      case 'national_id':
        return 'National ID';
      case 'umid':
        return 'UMID';
      case 'prc':
        return 'PRC ID';
      case 'sss':
        return 'SSS ID';
      case 'philhealth':
        return 'PhilHealth ID';
      case 'postal_id':
        return 'Postal ID';
      case 'voters_id':
        return "Voter's ID";
      case 'other':
        return 'Other';
      case 'unknown':
        return 'Unknown';
      default:
        return value;
    }
  }

  String _selfieQualityLabel(String value) {
    switch (value) {
      case 'good':
        return 'Good quality';
      case 'poor':
        return 'Poor quality';
      case 'no_face':
        return 'No face detected';
      case 'uncertain':
        return 'Uncertain';
      default:
        return value;
    }
  }

  String _spoofSignalLabel(String value) {
    switch (value) {
      case 'live_looking':
        return 'Live-looking';
      case 'spoof_suspected':
        return 'Spoof suspected';
      case 'uncertain':
        return 'Uncertain';
      default:
        return value;
    }
  }

  String _fieldCheckLabel(String key) {
    switch (key) {
      case 'full_name':
        return 'Name check';
      case 'date_of_birth':
      case 'birth_date':
        return 'Birth date check';
      case 'address':
        return 'Address check';
      case 'gender':
        return 'Gender check';
      default:
        return key;
    }
  }

  String _fieldCheckValue(Object? value) {
    if (value == 'match') return 'Matches';
    if (value == 'mismatch') return 'Does not match';
    if (value == 'unverifiable') return 'Unverifiable';
    return value.toString();
  }

  String _recommendationLabel(String value) {
    switch (value) {
      case 'looks_ok':
        return 'Looks OK — advisory only';
      case 'needs_review':
        return 'Needs review — advisory only';
      default:
        return value;
    }
  }

  // ── All Users tab ────────────────────────────────────────────────────────

  Widget _buildAllUsersTab(UserProvider userProvider) {
    final filtered = userProvider.allUsers.where((u) {
      final matchSearch =
          _searchQuery.isEmpty ||
          u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.username.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchRole = _roleFilter == 'all' || u.role == _roleFilter;
      return matchSearch && matchRole;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => userProvider.loadAllUsers(),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, username...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'all',
                          'citizen',
                          'secretary',
                          'treasurer',
                          'kagawad_representative',
                          'barangay_tanod',
                          'captain',
                          'admin',
                        ].map((r) {
                          final selected = _roleFilter == r;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(
                                r == 'all' ? 'All' : AppRoles.displayName(r),
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _roleFilter = r),
                              selectedColor: const Color(
                                0xFF1976D2,
                              ).withValues(alpha: 0.15),
                              checkmarkColor: const Color(0xFF1976D2),
                              labelStyle: TextStyle(
                                color: selected
                                    ? const Color(0xFF1976D2)
                                    : Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _emptyState('No users found', Icons.search_off, Colors.grey)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildUserTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserProfile user) {
    final roleColor = _roleColor(user.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: user.profilePhotoUrl != null
                  ? NetworkImage(user.profilePhotoUrl!)
                  : null,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: user.profilePhotoUrl == null
                  ? Icon(Icons.person, color: roleColor, size: 24)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: user.registrationStatus == 'approved'
                      ? Colors.green
                      : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppRoles.displayName(user.role),
                    style: TextStyle(
                      fontSize: 11,
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.registrationStatus == 'approved'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.registrationStatus,
                    style: TextStyle(
                      fontSize: 10,
                      color: user.registrationStatus == 'approved'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'role') _handleChangeRole(user);
            if (action == 'delete') _handleDeleteUser(user);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'role',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 18),
                  SizedBox(width: 8),
                  Text('Change Role'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: const Icon(Icons.more_vert, color: Colors.grey),
        ),
      ),
    ),
  );
}

  Widget _emptyState(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'captain':
        return Colors.blue[800]!;
      case 'secretary':
        return Colors.indigo;
      case 'treasurer':
        return Colors.teal;
      case 'kagawad_representative':
        return Colors.orange[800]!;
      case 'barangay_tanod':
        return Colors.brown;
      default:
        return Colors.blueGrey;
    }
  }
}
