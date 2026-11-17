import 'package:flutter/material.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/residency_proof.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/services/residency_proof_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

/// Admin screen to review pending residency proofs.
///
/// Only proofs with status == 'pending' are shown. Each card displays the
/// citizen's name (via UserService), date, notes, and the proof image in a
/// full-screen viewer (copied from user_registration_detail_screen.dart).
/// Officers may Confirm (flips status to 'confirmed' and
/// users_profile.is_poblacion_resident = true) or Reject (status → 'rejected',
/// profile flag unchanged) with optional auditor notes.
class ResidencyProofsScreen extends StatefulWidget {
  const ResidencyProofsScreen({super.key});

  @override
  State<ResidencyProofsScreen> createState() => _ResidencyProofsScreenState();
}

class _ResidencyProofsScreenState extends State<ResidencyProofsScreen> {
  final ResidencyProofService _proofService = ResidencyProofService();
  final UserService _userService = UserService();

  List<ResidencyProof> _proofs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final proofs = await _proofService.getPendingProofs();
      setState(() {
        _proofs = proofs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = Helpers.parseSupabaseError(e);
        _loading = false;
      });
    }
  }

  Future<void> _confirm(ResidencyProof proof) async {
    final l10n = AppLocalizations.of(context);
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.verifyResidencyReviewConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.verifyResidencyReviewConfirmBody),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.verifyResidencyReviewNotesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.verifyResidencyReviewConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    Helpers.showLoadingDialog(context, l10n.verifyResidencyReviewConfirming);
    try {
      await _proofService.confirmProof(
        proofId: proof.id,
        userId: proof.userId,
        auditorNotes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      if (!context.mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        l10n.verifyResidencyReviewConfirmed,
      );
      _load();
    } catch (e) {
      if (!context.mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        l10n.verifyResidencyReviewLoadError,
      );
    }
  }

  Future<void> _reject(ResidencyProof proof) async {
    final l10n = AppLocalizations.of(context);
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.verifyResidencyReviewRejectTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.verifyResidencyReviewRejectBody),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.verifyResidencyReviewNotesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.verifyResidencyReviewReject),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    Helpers.showLoadingDialog(context, l10n.verifyResidencyReviewRejecting);
    try {
      await _proofService.rejectProof(
        proofId: proof.id,
        userId: proof.userId,
        auditorNotes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      if (!context.mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        l10n.verifyResidencyReviewRejected,
      );
      _load();
    } catch (e) {
      if (!context.mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        l10n.verifyResidencyReviewLoadError,
      );
    }
  }

  Future<void> _viewProof(ResidencyProof proof) async {
    final l10n = AppLocalizations.of(context);
    final user = await _userService.getUserProfile(proof.userId);
    final title =
        '${l10n.verifyResidencyReviewProofBy} ${user?.fullName ?? l10n.atreasUnknownUser}';

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(title: title, url: proof.proofUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyResidencyReviewTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(l10n.verifyResidencyReviewLoadError),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  )
                : _proofs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.badge_outlined,
                                size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(l10n.verifyResidencyReviewEmpty),
                            const SizedBox(height: 8),
                            Text(
                              l10n.verifyResidencyReviewEmptyHint,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _proofs.length,
                        itemBuilder: (_, index) {
                          final proof = _proofs[index];
                          return _ProofCard(
                            proof: proof,
                            onConfirm: () => _confirm(proof),
                            onReject: () => _reject(proof),
                            onViewProof: () => _viewProof(proof),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  final ResidencyProof proof;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onViewProof;

  const _ProofCard({
    required this.proof,
    required this.onConfirm,
    required this.onReject,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<UserProfile?>(
              future: UserService().getUserProfile(proof.userId),
              builder: (_, snapshot) {
                final user = snapshot.data;
                final name = user?.fullName ?? l10n.atreasUnknownUser;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.verifyResidencyReviewProofBy} $name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${l10n.verifyResidencyReviewProofDate} '
                          '${Helpers.formatDate(proof.createdAt)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.verifyResidencyReviewProofStatus,
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (proof.auditorNotes != null &&
                proof.auditorNotes!.trim().isNotEmpty) ...[
              Text(
                '${l10n.verifyResidencyReviewProofNotes} ${proof.auditorNotes}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                '${l10n.verifyResidencyReviewProofNotes} ${l10n.verifyResidencyReviewNoNotes}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],
            InkWell(
              onTap: onViewProof,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  proof.proofUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image,
                            color: Colors.grey, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          l10n.auregImageFailed,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                OutlinedButton.icon(
                  onPressed: onViewProof,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text(l10n.verifyResidencyReviewViewProof),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l10n.verifyResidencyReviewConfirm),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(l10n.verifyResidencyReviewReject),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen image viewer copied from user_registration_detail_screen.dart
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