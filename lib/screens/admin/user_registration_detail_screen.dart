import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/screens/admin/edit_user_screen.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Full-page review of a single user registration.
///
/// This is the only place where an officer can Approve or Reject a pending
/// registration — the pending list cards navigate here instead of carrying
/// their own action buttons, so every decision is made with the complete
/// picture (personal details, ID, liveness, AI advisory) in front of them.
class UserRegistrationDetailScreen extends StatefulWidget {
  final UserProfile user;

  const UserRegistrationDetailScreen({super.key, required this.user});

  @override
  State<UserRegistrationDetailScreen> createState() =>
      _UserRegistrationDetailScreenState();
}

class _UserRegistrationDetailScreenState
    extends State<UserRegistrationDetailScreen> {
  /// The registration shown on screen. Starts as the snapshot passed in and
  /// is refreshed from the DB so a registration decided elsewhere (e.g. by
  /// another officer while this page was open) flips to read-only.
  late UserProfile _user;

  /// Whether this registration was still present in the provider's pending
  /// list at some point while the page was open — used to tell "removed by a
  /// realtime refresh" apart from "the list simply isn't loaded".
  bool _wasInPendingList = false;
  bool _syncing = false;

  bool get _canDecide => _user.registrationStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _syncStatus();
  }

  /// Re-read the registration row. Silent on failure: we keep the snapshot we
  /// were opened with rather than blocking the review.
  Future<void> _syncStatus() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final fresh = await UserService().getUserProfile(widget.user.id);
      if (mounted && fresh != null) {
        if (fresh.registrationStatus != _user.registrationStatus) {
          setState(() => _user = fresh);
        }
      }
    } catch (_) {
      // Offline or transient failure — fall back to the snapshot we have.
    } finally {
      _syncing = false;
    }
  }

  // ── Decisions ────────────────────────────────────────────────────────────

  Future<void> _handleApprove() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.auserApproveUserTitle,
      message: l10n.auserApproveConfirm(_user.fullName),
    );
    if (!confirm || !mounted) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, l10n.auserApproving);
    final ok = await userProvider.approveUser(_user.id);
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Navigator.pop(context, l10n.auserApprovedSnackbar);
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  Future<void> _handleReject() async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.auserRejectUserTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.auserRejectingName(_user.fullName)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.commonRejectionReason,
                hintText: l10n.auserRejectReasonHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, l10n.commonPleaseProvideReason);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonReject),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final userProvider = context.read<UserProvider>();
    Helpers.showLoadingDialog(context, l10n.auserRejecting);
    final ok = await userProvider.rejectUser(
      _user.id,
      reasonController.text.trim(),
    );
    if (!mounted) return;
    Helpers.dismissDialog(context);
    if (ok) {
      Navigator.pop(context, l10n.auserRegistrationRejected);
    } else {
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage),
      );
    }
  }

  Future<void> _handleEditUserInfo() async {
    final l10n = AppLocalizations.of(context);
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditUserScreen(user: _user)),
    );
    if (edited != true || !mounted) return;
    final fresh = await UserService().getUserProfile(widget.user.id);
    if (mounted && fresh != null) setState(() => _user = fresh);
    if (mounted) Helpers.showSuccessSnackBar(context, l10n.auserInfoUpdated);
  }

  void _openViewer(String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(title: title, url: url),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEditUserInfo = AppRoles.canEditUserInfo(
      context.read<AuthProvider>().userProfile?.role ?? '',
    );
    // If a realtime refresh drops this registration from the pending list
    // while we're looking at it, re-read it — the officer must not be able to
    // approve something that was already decided elsewhere.
    final pending = context.watch<UserProvider>().pendingUsers;
    final inList = pending.any((u) => u.id == widget.user.id);
    if (inList) {
      _wasInPendingList = true;
    } else if (_wasInPendingList && _canDecide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncStatus());
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.auregTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (canEditUserInfo)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.auserEditInfo,
              onPressed: _handleEditUserInfo,
            ),
        ],
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
      bottomNavigationBar: _canDecide ? _buildActionBar() : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(),
          if (!_canDecide) _buildDecisionBanner(),
          _buildPersonalSection(),
          _buildIdentitySection(),
          _buildDocumentsSection(),
          if (_user.kycAiResult != null) _buildAiSection(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final badge = _kycBadgeData(_user);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1976D2).withValues(alpha: 0.08),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user.fullName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${_user.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _user.email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (badge != null) _kycBadge(badge),
                _statusChip(_user.registrationStatus),
                _roleChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerAvatar() {
    final l10n = AppLocalizations.of(context);
    final photo = _user.profilePhotoUrl;
    const fallback = Color(0xFF1976D2);
    final Widget inner;
    if (photo == null) {
      inner = Container(
        color: fallback.withValues(alpha: 0.08),
        child: const Icon(Icons.person, size: 44, color: fallback),
      );
    } else {
      inner = Image.network(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: fallback.withValues(alpha: 0.08),
          child: const Icon(Icons.person, size: 44, color: fallback),
        ),
      );
    }
    return InkWell(
      onTap: photo == null ? null : () => _openViewer(l10n.commonProfilePhoto, photo),
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(child: SizedBox(width: 86, height: 86, child: inner)),
      ),
    );
  }

  // ── Read-only decision banner ──────────────────────────────────────────

  Widget _buildDecisionBanner() {
    final l10n = AppLocalizations.of(context);
    final status = _user.registrationStatus;
    final ({String label, Color color, IconData icon}) data = switch (status) {
      'approved' => (
        label: l10n.auregRegistrationApproved,
        color: Colors.green[700]!,
        icon: Icons.verified,
      ),
      'rejected' => (
        label: l10n.auserRegistrationRejected,
        color: AppColors.error,
        icon: Icons.cancel_outlined,
      ),
      _ => (
        label: l10n.auregAwaitingReview,
        color: Colors.orange[800]!,
        icon: Icons.hourglass_top,
      ),
    };
    final reason = _user.rejectionReason ?? _user.kycRejectionReason;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: data.color,
                  ),
                ),
                if (status == 'approved' && _user.kycVerifiedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.auregApprovedOn(
                      Helpers.formatDate(_user.kycVerifiedAt!),
                    ) +
                        (_user.kycReviewedBy != null
                            ? l10n.auregReviewedBy(_user.kycReviewedBy!)
                            : ''),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if ((status == 'rejected' || status == 'approved') &&
                    (reason?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  Text(
                    status == 'rejected'
                        ? l10n.auregRejectionReason
                        : l10n.auregReviewNotes,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(reason!, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────

  Widget _buildPersonalSection() {
    final l10n = AppLocalizations.of(context);
    return _sectionCard(
      icon: Icons.person_outline,
      title: l10n.auregPersonalDetails,
      children: [
        _detailRow(l10n.commonAddress, _user.address),
        _detailRow(l10n.commonAge, l10n.apendYearsOld(_user.age)),
        _detailRow(l10n.commonDateOfBirth, Helpers.formatDate(_user.dateOfBirth)),
        _detailRow(l10n.commonPlaceOfBirth, _user.placeOfBirth),
        _detailRow(l10n.commonCivilStatus, _user.civilStatus),
        _detailRow(l10n.commonGender, _user.gender),
        _detailRow(l10n.commonPhoneNumber, _user.phoneNumber),
        _detailRow(l10n.auregRegisteredLabel, Helpers.formatDate(_user.createdAt)),
        _detailRow(l10n.commonRole, AppRoles.displayName(_user.role)),
      ],
    );
  }

  Widget _buildIdentitySection() {
    final l10n = AppLocalizations.of(context);
    return _sectionCard(
      icon: Icons.fact_check_outlined,
      title: l10n.auregIdentityVerification,
      children: [
        if (_user.kycIdType != null) ...[
          _detailRow(l10n.auregIdTypeLabel, KycIdTypes.label(_user.kycIdType)),
          _detailRow(
            l10n.auregIdNumberLabel,
            _user.kycIdNumber ?? l10n.auregNotProvided,
          ),
          if (_user.idIssuedAt != null)
            _detailRow(
              l10n.auregIdIssuedLabel,
              Helpers.formatDate(_user.idIssuedAt!),
            ),
          if (_user.idExpiryAt != null)
            _detailRow(
              l10n.auregIdExpiresLabel,
              Helpers.formatDate(_user.idExpiryAt!),
            ),
        ] else
          _detailRow(l10n.auregGovernmentId, l10n.auregNotProvided),
        _detailRow(
          l10n.auregLivenessCheck,
          _user.livenessVerified
              ? (_user.livenessVerifiedAt != null
                    ? l10n.auregVerifiedOn(
                        Helpers.formatDate(_user.livenessVerifiedAt!),
                      )
                    : l10n.auregVerified)
              : l10n.auregNotCompleted,
        ),
        _detailRow(
          l10n.auregIndigentRegistration,
          _user.isIndigent ? l10n.commonYes : l10n.commonNo,
        ),
        if (_user.isIndigent && (_user.indigencyReason?.isNotEmpty ?? false))
          _detailRow(l10n.auregIndigencyReasonLabel, _user.indigencyReason!),
        if (_user.kycVerifiedAt != null)
          _detailRow(
            l10n.auregKycVerifiedLabel,
            Helpers.formatDate(_user.kycVerifiedAt!),
          ),
        if ((_user.kycReviewedBy ?? '').isNotEmpty)
          _detailRow(l10n.auregKycReviewedByLabel, _user.kycReviewedBy!),
        if ((_user.kycRejectionReason ?? '').isNotEmpty)
          _detailRow(
            l10n.auregKycRejectionReasonLabel,
            _user.kycRejectionReason!,
          ),
        if ((_user.rejectionReason ?? '').isNotEmpty)
          _detailRow(l10n.auregRejectionReason, _user.rejectionReason!),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    final l10n = AppLocalizations.of(context);
    final idLabel = _user.isIndigent ? 'Certificate of Indigency' : l10n.commonValidId;
    return _sectionCard(
      icon: Icons.photo_library_outlined,
      title: l10n.auregDocumentsPhotos,
      children: [
        Row(
          children: [
            Expanded(
              child: _docTile(_user.profilePhotoUrl, l10n.commonProfilePhoto),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _docTile(
                _user.validIdUrl,
                l10n.auserKycPhotoFront(idLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _docTile(
                _user.validIdBackUrl,
                l10n.auserKycPhotoBack(idLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _zoomHintTile()),
          ],
        ),
      ],
    );
  }

  Widget _docTile(String? url, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: url == null
              ? _missingImage(label)
              : InkWell(
                  onTap: () => _openViewer(label, url),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _missingImage(label),
                      ),
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: _ZoomBadge(),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _missingImage(String label) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade400,
          size: 30,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.auregNotProvided,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _zoomHintTile() {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.zoom_in_map, size: 26, color: Color(0xFF1976D2)),
          const SizedBox(height: 8),
          Text(
            l10n.auregTapPhotoHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: Color(0xFF1976D2),
            ),
          ),
          title: Text(
            l10n.auserAiAdvisorySummary,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          children: [
            ..._kycSummaryRows(_user.kycAiResult!),
            const SizedBox(height: 4),
            Text(
              l10n.auserAiAdvisoryNote,
              style: const TextStyle(
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

  // ── Section scaffolding ────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF1976D2)),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chips & badges ─────────────────────────────────────────────────────

  ({String label, Color color, IconData icon})? _kycBadgeData(
    UserProfile user,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (user.kycMethod) {
      case 'ai_verified':
        return (
          label: l10n.auserKycAiPrechecked,
          color: const Color(0xFF1976D2),
          icon: Icons.auto_awesome,
        );
      case 'indigent_bypass':
        return (
          label: l10n.auserKycIndigentBypass,
          color: Colors.orange[800]!,
          icon: Icons.priority_high,
        );
      case 'guarantor_verified':
        return (
          label: l10n.auserKycGuarantorBacked,
          color: Colors.teal[700]!,
          icon: Icons.verified_user,
        );
      default:
        return null;
    }
  }

  Widget _kycBadge(({String label, Color color, IconData icon}) data) {
    return _pill(
      color: data.color,
      icon: data.icon,
      label: data.label,
      outlined: true,
    );
  }

  ({String label, Color color, IconData icon}) _statusChipData(String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'approved':
        return (
          label: l10n.auregStatusApproved,
          color: Colors.green[700]!,
          icon: Icons.check_circle,
        );
      case 'rejected':
        return (
          label: l10n.auregStatusRejected,
          color: AppColors.error,
          icon: Icons.cancel,
        );
      case 'pending':
        return (
          label: l10n.auregStatusPendingReview,
          color: Colors.orange[800]!,
          icon: Icons.hourglass_top,
        );
      default:
        return (
          label: status,
          color: Colors.blueGrey,
          icon: Icons.info_outline,
        );
    }
  }

  Widget _statusChip(String status) {
    final data = _statusChipData(status);
    return _pill(color: data.color, icon: data.icon, label: data.label);
  }

  Widget _roleChip() {
    return _pill(
      color: const Color(0xFF1976D2),
      icon: Icons.badge_outlined,
      label: AppRoles.displayName(_user.role),
    );
  }

  Widget _pill({
    required Color color,
    required IconData icon,
    required String label,
    bool outlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined
            ? color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom action bar ──────────────────────────────────────────────────

  Widget _buildActionBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleReject,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.commonReject),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleApprove,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.commonApprove),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  // ── AI advisory rows (read-only copy of the pending-card renderer) ─────

  List<Widget> _kycSummaryRows(Map<String, dynamic> kyc) {
    final l10n = AppLocalizations.of(context);
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
    final idAuthenticity = _kycString(kyc, [
      'id_authenticity',
      'idAuthenticity',
    ]);
    if (idAuthenticity != null) {
      addRow(l10n.auserKycIdAuthenticity, _idAuthenticityLabel(idAuthenticity));
    }

    // ID type guess/match
    final idTypeGuess = _kycString(kyc, ['id_type_guess', 'idTypeGuess']);
    final idTypeMatch = _kycString(kyc, ['id_type_match', 'idTypeMatch']);
    if (idTypeGuess != null) {
      addRow(l10n.auserKycIdTypeDetected, _idTypeGuessLabel(idTypeGuess));
    }
    if (idTypeMatch != null) {
      addRow(
        l10n.auserKycTypeMatch,
        idTypeMatch == 'true'
            ? l10n.auserKycMatchesDeclared
            : l10n.auserKycDoesNotMatchDeclared,
      );
    }

    // Selfie quality
    final selfieQuality = _kycString(kyc, ['selfie_quality', 'selfieQuality']);
    if (selfieQuality != null) {
      addRow(l10n.auserKycSelfieQuality, _selfieQualityLabel(selfieQuality));
    }

    // Liveness spoof signal
    final liveness = _kycMap(kyc, ['liveness']);
    final spoofSignal = liveness != null
        ? _kycString(liveness, ['spoof_signal', 'spoofSignal'])
        : _kycString(kyc, ['liveness_spoof_signal']);
    if (spoofSignal != null) {
      addRow(l10n.auserKycLivenessSignal, _spoofSignalLabel(spoofSignal));
    }

    // Liveness notes
    final livenessNotes = liveness != null
        ? _kycString(liveness, ['notes'])
        : _kycString(kyc, ['liveness_notes']);
    if (livenessNotes != null) {
      addRow(l10n.auserKycLivenessNotes, livenessNotes);
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
      addRow(l10n.auserKycRecommendation, _recommendationLabel(recommendation));
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
      addRow(l10n.auserKycCheckVersion, promptVersion);
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
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'authentic':
        return l10n.auserKycLooksAuthentic;
      case 'suspicious':
        return l10n.auserKycSuspicious;
      case 'unreadable':
        return l10n.auserKycUnreadable;
      case 'uncertain':
        return l10n.auserKycUncertain;
      default:
        return value;
    }
  }

  String _idTypeGuessLabel(String value) {
    final l10n = AppLocalizations.of(context);
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
        return l10n.commonOther;
      case 'unknown':
        return l10n.auserUnknown;
      default:
        return value;
    }
  }

  String _selfieQualityLabel(String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'good':
        return l10n.auserKycGoodQuality;
      case 'poor':
        return l10n.auserKycPoorQuality;
      case 'no_face':
        return l10n.auserKycNoFaceDetected;
      case 'uncertain':
        return l10n.auserKycUncertain;
      default:
        return value;
    }
  }

  String _spoofSignalLabel(String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'live_looking':
        return l10n.auserKycLiveLooking;
      case 'spoof_suspected':
        return l10n.auserKycSpoofSuspected;
      case 'uncertain':
        return l10n.auserKycUncertain;
      default:
        return value;
    }
  }

  String _fieldCheckLabel(String key) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'full_name':
        return l10n.auserKycNameCheck;
      case 'date_of_birth':
      case 'birth_date':
        return l10n.auserKycBirthDateCheck;
      case 'address':
        return l10n.auserKycAddressCheck;
      case 'gender':
        return l10n.auserKycGenderCheck;
      default:
        return key;
    }
  }

  String _fieldCheckValue(Object? value) {
    final l10n = AppLocalizations.of(context);
    if (value == 'match') return l10n.auserKycMatches;
    if (value == 'mismatch') return l10n.auserKycDoesNotMatch;
    if (value == 'unverifiable') return l10n.auserKycUnverifiable;
    return value.toString();
  }

  String _recommendationLabel(String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'looks_ok':
        return l10n.auserKycLooksOk;
      case 'needs_review':
        return l10n.auserKycNeedsReview;
      default:
        return value;
    }
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.zoom_in, size: 15, color: Colors.white),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String title;
  final String url;

  const _FullScreenImageViewer({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, _, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.auregImageFailed,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
