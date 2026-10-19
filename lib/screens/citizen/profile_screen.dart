import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/locale_provider.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Controllers
  final _givenNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _placeOfBirthController = TextEditingController();

  // Form values
  DateTime? _selectedDateOfBirth;
  String _selectedGender = 'Male';
  String _selectedCivilStatus = 'Single';

  // Images
  File? _profilePhoto;
  File? _validId;

  // State
  bool _isEditMode = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _givenNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _placeOfBirthController.dispose();
    super.dispose();
  }

  void _populateFields(AuthProvider authProvider) {
    final profile = authProvider.userProfile;
    if (profile == null) return;

    _givenNameController.text = profile.givenName;
    _middleNameController.text = profile.middleName;
    _lastNameController.text = profile.lastName;
    _phoneController.text = profile.phoneNumber;
    _addressController.text = profile.address;
    _placeOfBirthController.text = profile.placeOfBirth;
    _selectedDateOfBirth = profile.dateOfBirth;
    _selectedGender = profile.gender;
    _selectedCivilStatus = profile.civilStatus;
  }

  int _calculateAge(DateTime birthDate) {
    final now = Helpers.now();
    return now.year -
        birthDate.year -
        (now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day)
            ? 1
            : 0);
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _profilePhoto = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        Helpers.showErrorSnackBar(context, l10n.authFailedPickImage);
      }
    }
  }

  Future<void> _pickValidId() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          _validId = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        Helpers.showErrorSnackBar(context, l10n.profileFailedPickIdImage);
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDateOfBirth = date;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    if (_selectedDateOfBirth == null) {
      Helpers.showErrorSnackBar(context, l10n.authPleaseSelectDob);
      return;
    }

    final confirm = await Helpers.showConfirmDialog(
      context,
      title: l10n.commonSaveChanges,
      message: l10n.profileSaveChangesConfirm,
    );

    if (!confirm || !mounted) return;

    Helpers.showLoadingDialog(context, l10n.profileSavingChanges);

    final authProvider = context.read<AuthProvider>();
    final age = _calculateAge(_selectedDateOfBirth!);

    final success = await authProvider.updateProfile(
      givenName: _givenNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      address: _addressController.text.trim(),
      age: age,
      dateOfBirth: _selectedDateOfBirth,
      placeOfBirth: _placeOfBirthController.text.trim(),
      civilStatus: _selectedCivilStatus,
      gender: _selectedGender,
      phoneNumber: _phoneController.text.trim(),
      profilePhoto: _profilePhoto,
      validId: _validId,
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (success) {
      Helpers.showSuccessSnackBar(
        context,
        l10n.profileUpdateSuccess,
      );
      setState(() {
        _isEditMode = false;
        _profilePhoto = null;
        _validId = null;
      });
    } else {
      Helpers.showErrorSnackBar(
        context,
        authProvider.error != null
            ? Helpers.parseSupabaseError(authProvider.error)
            : l10n.profileUpdateFailed,
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final l10n = AppLocalizations.of(context);
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.profileChangePassword),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: l10n.profileCurrentPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: l10n.profileNewPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: l10n.profileConfirmNewPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (currentPasswordController.text.isEmpty) {
                      Helpers.showErrorSnackBar(
                        context,
                        l10n.profileCurrentPasswordRequired,
                      );
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      Helpers.showErrorSnackBar(
                        context,
                        l10n.profilePasswordMinLength(6),
                      );
                      return;
                    }
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      Helpers.showErrorSnackBar(
                        context,
                        l10n.authPasswordsDoNotMatch,
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(l10n.commonUpdate),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    Helpers.showLoadingDialog(context, l10n.profileUpdatingPassword);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updatePassword(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (success) {
      Helpers.showSuccessSnackBar(context, l10n.profilePasswordUpdated);
    } else {
      Helpers.showErrorSnackBar(
        context,
        authProvider.error ?? l10n.profilePasswordUpdateFailed,
      );
    }
  }

  void _viewImage(String title, String? networkUrl, File? localFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          title: title,
          networkUrl: networkUrl,
          localFile: localFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;

    if (userProfile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(l10n.profileTitle),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Populate fields when entering edit mode
    if (_isEditMode &&
        _givenNameController.text.isEmpty &&
        userProfile.givenName.isNotEmpty) {
      _populateFields(authProvider);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                  Color(0xFF42A5F5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            l10n.profileMyProfile,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!_isEditMode)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditMode = true;
                              });
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              l10n.commonEdit,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Profile photo
                    GestureDetector(
                      onTap: _isEditMode
                          ? _pickProfilePhoto
                          : () => _viewImage(
                                l10n.commonProfilePhoto,
                                userProfile.profilePhotoUrl,
                                _profilePhoto,
                              ),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFF0F4FF),
                              backgroundImage: _profilePhoto != null
                                  ? FileImage(_profilePhoto!)
                                  : userProfile.profilePhotoUrl != null
                                      ? NetworkImage(
                                          userProfile.profilePhotoUrl!,
                                        )
                                      : null,
                              child: _profilePhoto == null &&
                                      userProfile.profilePhotoUrl == null
                                  ? Text(
                                      Helpers.getInitials(
                                        userProfile.fullName,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (_isEditMode)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userProfile.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${userProfile.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingM,
                AppSizes.paddingL,
                AppSizes.paddingM,
                AppSizes.paddingXL,
              ),
              child: _isEditMode
                  ? _buildEditMode(userProfile)
                  : _buildViewMode(userProfile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(UserProfile userProfile) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Information Section
        _buildSectionHeader(l10n.authPersonalInfoTitle, AppColors.primary),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.person_outline,
            label: l10n.commonFullName,
            value: userProfile.fullName,
          ),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: l10n.commonEmail,
            value: userProfile.email,
          ),
          _buildInfoRow(
            icon: Icons.alternate_email,
            label: l10n.commonUsername,
            value: userProfile.username,
          ),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: l10n.commonPhoneNumber,
            value: userProfile.phoneNumber,
          ),
          _buildInfoRow(
            icon: Icons.home_outlined,
            label: l10n.commonAddress,
            value: userProfile.address,
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Additional Details Section
        _buildSectionHeader(l10n.profileAdditionalDetails, AppColors.secondary),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.cake_outlined,
            label: l10n.commonAge,
            value: l10n.profileAgeYearsOld(userProfile.age),
          ),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: l10n.commonDateOfBirth,
            value: Helpers.formatDate(userProfile.dateOfBirth),
          ),
          _buildInfoRow(
            icon: Icons.place_outlined,
            label: l10n.commonPlaceOfBirth,
            value: userProfile.placeOfBirth,
          ),
          _buildInfoRow(
            icon: Icons.family_restroom,
            label: l10n.commonCivilStatus,
            value: userProfile.civilStatus,
          ),
          _buildInfoRow(
            icon: Icons.wc,
            label: l10n.commonGender,
            value: userProfile.gender,
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Documents Section
        _buildSectionHeader(l10n.commonDocuments, AppColors.accent),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildDocumentRow(
            label: l10n.commonProfilePhoto,
            networkUrl: userProfile.profilePhotoUrl,
            onTap: () => _viewImage(
              l10n.commonProfilePhoto,
              userProfile.profilePhotoUrl,
              null,
            ),
          ),
          _buildDocumentRow(
            label: l10n.commonValidId,
            networkUrl: userProfile.validIdUrl,
            onTap: () => _viewImage(
              l10n.commonValidId,
              userProfile.validIdUrl,
              null,
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Account Section
        _buildSectionHeader(l10n.authStepAccountLabel, AppColors.success),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: l10n.commonRole,
            value: _getRoleDisplayName(userProfile.role),
          ),
          _buildInfoRow(
            icon: Icons.access_time,
            label: l10n.commonMemberSince,
            value: Helpers.formatDate(userProfile.createdAt),
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Language Section
        _buildLanguageSection(),
        const SizedBox(height: AppSizes.paddingL),

        // Change Password Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showChangePasswordDialog,
            icon: const Icon(Icons.lock_outline),
            label: Text(l10n.profileChangePassword),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(UserProfile userProfile) {
    final authProvider = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Section
          _buildSectionHeader(l10n.authPersonalInfoTitle, AppColors.primary),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            TextFormField(
              controller: _givenNameController,
              decoration: InputDecoration(
                labelText: l10n.authGivenNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.authGivenNameRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _middleNameController,
              decoration: InputDecoration(
                labelText: l10n.authMiddleNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: l10n.authLastNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.authLastNameRequired : null,
            ),
            const SizedBox(height: 16),
            // Email (read-only)
            TextFormField(
              initialValue: userProfile.email,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.commonEmail,
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            // Username (read-only)
            TextFormField(
              initialValue: userProfile.username,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.commonUsername,
                prefixIcon: const Icon(Icons.alternate_email),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.commonPhoneNumber,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authPhoneRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.authCompleteAddressLabel,
                prefixIcon: const Icon(Icons.home_outlined),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.authAddressRequired : null,
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Additional Details Section
          _buildSectionHeader(l10n.profileAdditionalDetails, AppColors.secondary),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            // Age (read-only, auto-calapsed)
            TextFormField(
              initialValue: '${userProfile.age}',
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.profileAgeAutoCalculated,
                prefixIcon: const Icon(Icons.cake_outlined),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            // Date of Birth picker
            GestureDetector(
              onTap: _selectDateOfBirth,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: _selectedDateOfBirth == null
                        ? l10n.authDateOfBirthTapToSelect
                        : l10n.profileDateOfBirthSelected(
                            Helpers.formatDate(_selectedDateOfBirth!),
                          ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _placeOfBirthController,
              decoration: InputDecoration(
                labelText: l10n.commonPlaceOfBirth,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authPlaceOfBirthRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCivilStatus,
              decoration: InputDecoration(
                labelText: l10n.commonCivilStatus,
                prefixIcon: const Icon(Icons.family_restroom),
              ),
              items: [
                'Single',
                'Married',
                'Widowed',
                'Divorced',
              ]
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCivilStatus = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: l10n.commonGender,
                prefixIcon: const Icon(Icons.wc),
              ),
              items: [
                'Male',
                'Female',
                'Other',
              ]
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text(g)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedGender = v!),
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Documents Section
          _buildSectionHeader(l10n.commonDocuments, AppColors.accent),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            _buildImageUploadRow(
              label: l10n.commonProfilePhoto,
              file: _profilePhoto,
              networkUrl: userProfile.profilePhotoUrl,
              onTap: _pickProfilePhoto,
            ),
            const SizedBox(height: 16),
            _buildImageUploadRow(
              label: l10n.commonValidId,
              file: _validId,
              networkUrl: userProfile.validIdUrl,
              onTap: _pickValidId,
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Account Section (read-only)
          _buildSectionHeader(l10n.authStepAccountLabel, AppColors.success),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            TextFormField(
              initialValue: _getRoleDisplayName(userProfile.role),
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.commonRole,
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: Helpers.formatDate(userProfile.createdAt),
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.commonMemberSince,
                prefixIcon: const Icon(Icons.access_time),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _profilePhoto = null;
                      _validId = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.commonSaveChanges,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    final l10n = AppLocalizations.of(context);
    final currentCode = context.watch<LocaleProvider>().languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.languageSectionTitle, AppColors.primary),
        const SizedBox(height: 6),
        // Aligns with the header text (4px bar + 12px gap).
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            l10n.languageSectionSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                _buildLanguageOption(
                  name: l10n.languageEnglish,
                  code: 'en',
                  currentCode: currentCode,
                ),
                _buildLanguageOption(
                  name: l10n.languageTagalog,
                  code: 'fil',
                  currentCode: currentCode,
                ),
                _buildLanguageOption(
                  name: l10n.languageCebuano,
                  code: 'ceb',
                  currentCode: currentCode,
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildLanguageOption({
    required String name,
    required String code,
    required String currentCode,
  }) {
    final isActive = code == currentCode;

    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _changeLanguage(code),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS + 4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.translate,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color:
                        isActive ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.check,
                  size: 20,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeLanguage(String code) {
    context.read<LocaleProvider>().setLanguage(code);

    // The confirmation has to be built with the locale that was just applied,
    // so resolve it on the frame after MaterialApp picks up the new locale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final name = switch (code) {
        'fil' => l10n.languageTagalog,
        'ceb' => l10n.languageCebuano,
        _ => l10n.languageEnglish,
      };
      Helpers.showSuccessSnackBar(context, l10n.languageChanged(name));
    });
    // Guarantee a frame runs so the callback above always fires, even when
    // the locale (and therefore the tree) did not change.
    WidgetsBinding.instance.scheduleFrame();
  }

  Widget _buildDocumentRow({
    required String label,
    required String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasImage = networkUrl != null;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS + 4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasImage ? l10n.commonTapToView : l10n.commonNotUploaded,
                  style: TextStyle(
                    fontSize: 15,
                    color: hasImage
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasImage)
            TextButton(
              onPressed: onTap,
              child: Text(l10n.commonView),
            ),
        ],
      ),
    );
  }

  Widget _buildImageUploadRow({
    required String label,
    required File? file,
    required String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasLocalFile = file != null;
    final hasNetworkImage = networkUrl != null;
    final hasAnyImage = hasLocalFile || hasNetworkImage;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAnyImage ? AppColors.primary : Colors.grey.shade300,
            width: hasAnyImage ? 2 : 1.5,
          ),
        ),
        child: hasAnyImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: hasLocalFile
                        ? Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.network(
                            networkUrl ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.commonTapToUpload,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    final l10n = AppLocalizations.of(context);
    switch (role) {
      case 'captain':
        return l10n.roleCaptain;
      case 'secretary':
        return l10n.roleSecretary;
      case 'treasurer':
        return l10n.roleTreasurer;
      case 'kagawad_representative':
        return l10n.roleKagawad;
      case 'barangay_tanod':
        return l10n.roleTanod;
      case 'admin':
        return l10n.roleAdmin;
      case 'citizen':
      default:
        return l10n.roleCitizen;
    }
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String title;
  final String? networkUrl;
  final File? localFile;

  const _FullScreenImageViewer({
    required this.title,
    this.networkUrl,
    this.localFile,
  });

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
          child: localFile != null
              ? Image.file(localFile!, fit: BoxFit.contain)
              : networkUrl != null
                  ? Image.network(
                      networkUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.profileFailedLoadImage,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.profileNoImageAvailable,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
