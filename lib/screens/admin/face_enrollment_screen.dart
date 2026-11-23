import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/face_gate.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/services/face_gate_service.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

/// Officials-only enrollment UI for the face gate: enroll a resident's face
/// sample so their sign-up can be auto-approved by face match.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _givenNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _faceGateService = FaceGateService();

  DateTime? _dob;
  File? _photo;
  bool _enrolling = false;
  List<FaceEnrollment> _enrollments = [];
  bool _loadingList = true;

  /// On-device embedding is native-only (same guard as FaceGateService).
  bool get _unsupportedPlatform =>
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_unsupportedPlatform) _loadEnrollments();
  }

  @override
  void dispose() {
    _givenNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadEnrollments() async {
    final list = await _faceGateService.listEnrollments();
    if (!mounted) return;
    setState(() {
      _enrollments = list;
      _loadingList = false;
    });
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    final l10n = AppLocalizations.of(context);
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.authSelectImageSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.authCameraOption),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.authGalleryOption),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _photo = File(picked.path));
    } catch (_) {
      if (mounted) {
        Helpers.showErrorSnackBar(
          context,
          AppLocalizations.of(context).authFailedPickImage,
        );
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _enroll() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dob = _dob;
    final photo = _photo;
    if (dob == null) {
      Helpers.showErrorSnackBar(context, l10n.reqDocPleaseSelectBirthDate);
      return;
    }
    if (photo == null) return;
    setState(() => _enrolling = true);
    final embedding = await _faceGateService.embedFromFile(photo);
    if (!mounted) return;
    if (embedding == null) {
      setState(() => _enrolling = false);
      Helpers.showErrorSnackBar(context, l10n.faceEnrollNoFace);
      return;
    }
    final ok = await _faceGateService.enroll(
      givenName: _givenNameController.text,
      middleName: _middleNameController.text,
      lastName: _lastNameController.text,
      dob: dob,
      photo: photo,
      embedding: embedding,
      enrolledBy: context.read<AuthProvider>().currentUserId,
    );
    if (!mounted) return;
    setState(() {
      _enrolling = false;
      if (ok) _photo = null;
    });
    if (ok) {
      Helpers.showSuccessSnackBar(context, l10n.faceEnrollSuccess);
      await _loadEnrollments();
    } else {
      Helpers.showErrorSnackBar(context, l10n.faceEnrollFailed);
    }
  }

  Future<void> _deleteEnrollment(FaceEnrollment enrollment) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.faceEnrollDeleteTitle,
      message: l10n.faceEnrollDeleteMessage,
    );
    if (!confirm || !mounted) return;
    final ok = await _faceGateService.deleteEnrollment(enrollment.id);
    if (!mounted) return;
    if (ok) {
      Helpers.showSuccessSnackBar(context, l10n.faceEnrollDeleteSuccess);
      await _loadEnrollments();
    } else {
      Helpers.showErrorSnackBar(context, l10n.utilErrorGeneric);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.faceEnrollTitle,
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
      body: _unsupportedPlatform
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.faceEnrollDesktopNotice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildFormCard(l10n),
                const SizedBox(height: 16),
                ..._buildEnrollmentList(l10n),
              ],
            ),
    );
  }

  Widget _buildFormCard(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.faceEnrollIntro,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _nameField(
                controller: _givenNameController,
                label: l10n.authGivenNameLabel,
                validator: l10n.authGivenNameRequired,
              ),
              const SizedBox(height: 12),
              _nameField(
                controller: _middleNameController,
                label: l10n.authMiddleNameLabel,
              ),
              const SizedBox(height: 12),
              _nameField(
                controller: _lastNameController,
                label: l10n.authLastNameLabel,
                validator: l10n.authLastNameRequired,
              ),
              const SizedBox(height: 12),
              // Date of birth
              GestureDetector(
                onTap: _enrolling ? null : _pickDob,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: _dob == null
                          ? l10n.acreateDobTapToSelect
                          : l10n.profileDateOfBirthSelected(
                              Helpers.formatDate(_dob!),
                            ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _enrolling ? null : _pickPhoto,
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: Text(l10n.faceEnrollPickPhoto),
                  ),
                  const SizedBox(width: 12),
                  if (_photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _photo!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.faceEnrollPhotoChosen,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_enrolling || _photo == null) ? null : _enroll,
                  icon: _enrolling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.face_retouching_natural),
                  label: Text(
                    _enrolling ? l10n.faceEnrollEnrolling : l10n.faceEnrollEnroll,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
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

  Widget _nameField({
    required TextEditingController controller,
    required String label,
    String? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator == null
          ? null
          : (v) => (v == null || v.trim().isEmpty) ? validator : null,
    );
  }

  List<Widget> _buildEnrollmentList(AppLocalizations l10n) {
    if (_loadingList) {
      return const [
        Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        )),
      ];
    }
    if (_enrollments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              l10n.faceEnrollEmpty,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ),
      ];
    }
    return _enrollments.map(_buildEnrollmentTile).toList();
  }

  Widget _buildEnrollmentTile(FaceEnrollment enrollment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: enrollment.photoUrl == null
                ? const Icon(Icons.person)
                : ClipOval(
                    // Signed URLs expire after 1 hour — degrade to the icon.
                    child: Image.network(
                      enrollment.photoUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.person),
                    ),
                  ),
          ),
          title: Text(
            enrollment.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            enrollment.dob,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteEnrollment(enrollment),
          ),
        ),
      ),
    );
  }
}
