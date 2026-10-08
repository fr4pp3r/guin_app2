import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Controllers
  final _fullNameController = TextEditingController();
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
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _placeOfBirthController.dispose();
    super.dispose();
  }

  void _populateFields(AuthProvider authProvider) {
    final profile = authProvider.userProfile;
    if (profile == null) return;

    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber;
    _addressController.text = profile.address;
    _placeOfBirthController.text = profile.placeOfBirth;
    _selectedDateOfBirth = profile.dateOfBirth;
    _selectedGender = profile.gender;
    _selectedCivilStatus = profile.civilStatus;
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
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
        Helpers.showErrorSnackBar(context, 'Failed to pick image');
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
        Helpers.showErrorSnackBar(context, 'Failed to pick ID image');
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
    if (_selectedDateOfBirth == null) {
      Helpers.showErrorSnackBar(context, 'Please select date of birth');
      return;
    }

    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Save Changes',
      message:
          'Are you sure you want to save these changes? They will be subject to admin review.',
    );

    if (!confirm || !mounted) return;

    Helpers.showLoadingDialog(context, 'Saving changes...');

    final authProvider = context.read<AuthProvider>();
    final age = _calculateAge(_selectedDateOfBirth!);

    final success = await authProvider.updateProfile(
      fullName: _fullNameController.text.trim(),
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
        'Profile updated successfully. Changes are subject to admin review.',
      );
      setState(() {
        _isEditMode = false;
        _profilePhoto = null;
        _validId = null;
      });
    } else {
      Helpers.showErrorSnackBar(
        context,
        authProvider.error ?? 'Failed to update profile',
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
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
                        labelText: 'New Password',
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
                        labelText: 'Confirm New Password',
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (currentPasswordController.text.isEmpty) {
                      Helpers.showErrorSnackBar(
                        context,
                        'Please enter current password',
                      );
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      Helpers.showErrorSnackBar(
                        context,
                        'New password must be at least 6 characters',
                      );
                      return;
                    }
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      Helpers.showErrorSnackBar(
                        context,
                        'Passwords do not match',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    Helpers.showLoadingDialog(context, 'Updating password...');

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updatePassword(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (success) {
      Helpers.showSuccessSnackBar(context, 'Password updated successfully');
    } else {
      Helpers.showErrorSnackBar(
        context,
        authProvider.error ?? 'Failed to update password',
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
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;

    if (userProfile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Profile'),
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
        _fullNameController.text.isEmpty &&
        userProfile.fullName.isNotEmpty) {
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
                        const Expanded(
                          child: Text(
                            'My Profile',
                            style: TextStyle(
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
                            label: const Text(
                              'Edit',
                              style: TextStyle(
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
                                'Profile Photo',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Information Section
        _buildSectionHeader('Personal Information', AppColors.primary),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: userProfile.fullName,
          ),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: userProfile.email,
          ),
          _buildInfoRow(
            icon: Icons.alternate_email,
            label: 'Username',
            value: userProfile.username,
          ),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: userProfile.phoneNumber,
          ),
          _buildInfoRow(
            icon: Icons.home_outlined,
            label: 'Address',
            value: userProfile.address,
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Additional Details Section
        _buildSectionHeader('Additional Details', AppColors.secondary),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: '${userProfile.age} years old',
          ),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Date of Birth',
            value: Helpers.formatDate(userProfile.dateOfBirth),
          ),
          _buildInfoRow(
            icon: Icons.place_outlined,
            label: 'Place of Birth',
            value: userProfile.placeOfBirth,
          ),
          _buildInfoRow(
            icon: Icons.family_restroom,
            label: 'Civil Status',
            value: userProfile.civilStatus,
          ),
          _buildInfoRow(
            icon: Icons.wc,
            label: 'Gender',
            value: userProfile.gender,
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Documents Section
        _buildSectionHeader('Documents', AppColors.accent),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildDocumentRow(
            label: 'Profile Photo',
            networkUrl: userProfile.profilePhotoUrl,
            onTap: () => _viewImage(
              'Profile Photo',
              userProfile.profilePhotoUrl,
              null,
            ),
          ),
          _buildDocumentRow(
            label: 'Valid ID',
            networkUrl: userProfile.validIdUrl,
            onTap: () => _viewImage(
              'Valid ID',
              userProfile.validIdUrl,
              null,
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Account Section
        _buildSectionHeader('Account', AppColors.success),
        const SizedBox(height: AppSizes.paddingM),
        _buildInfoCard([
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: _getRoleDisplayName(userProfile.role),
          ),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Member Since',
            value: Helpers.formatDate(userProfile.createdAt),
          ),
        ]),
        const SizedBox(height: AppSizes.paddingL),

        // Change Password Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showChangePasswordDialog,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Change Password'),
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Section
          _buildSectionHeader('Personal Information', AppColors.primary),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            // Email (read-only)
            TextFormField(
              initialValue: userProfile.email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            // Username (read-only)
            TextFormField(
              initialValue: userProfile.username,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Phone number is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Complete Address',
                prefixIcon: Icon(Icons.home_outlined),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Address is required' : null,
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Additional Details Section
          _buildSectionHeader('Additional Details', AppColors.secondary),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            // Age (read-only, auto-calapsed)
            TextFormField(
              initialValue: '${userProfile.age}',
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Age (auto-calculated)',
                prefixIcon: Icon(Icons.cake_outlined),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
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
                        ? 'Date of Birth (tap to select)'
                        : 'Date of Birth: ${Helpers.formatDate(_selectedDateOfBirth!)}',
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _placeOfBirthController,
              decoration: const InputDecoration(
                labelText: 'Place of Birth',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Place of birth is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCivilStatus,
              decoration: const InputDecoration(
                labelText: 'Civil Status',
                prefixIcon: Icon(Icons.family_restroom),
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
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.wc),
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
          _buildSectionHeader('Documents', AppColors.accent),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            _buildImageUploadRow(
              label: 'Profile Photo',
              file: _profilePhoto,
              networkUrl: userProfile.profilePhotoUrl,
              onTap: _pickProfilePhoto,
            ),
            const SizedBox(height: 16),
            _buildImageUploadRow(
              label: 'Valid ID',
              file: _validId,
              networkUrl: userProfile.validIdUrl,
              onTap: _pickValidId,
            ),
          ]),
          const SizedBox(height: AppSizes.paddingL),

          // Account Section (read-only)
          _buildSectionHeader('Account', AppColors.success),
          const SizedBox(height: AppSizes.paddingM),
          _buildFormCard([
            TextFormField(
              initialValue: _getRoleDisplayName(userProfile.role),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: Helpers.formatDate(userProfile.createdAt),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Member Since',
                prefixIcon: Icon(Icons.access_time),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
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
                  child: const Text('Cancel'),
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
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
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

  Widget _buildDocumentRow({
    required String label,
    required String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasImage = networkUrl != null;
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
                  hasImage ? 'Tap to view' : 'Not uploaded',
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
              child: const Text('View'),
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
                    'Tap to upload',
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
    switch (role) {
      case 'captain':
        return 'Barangay Captain';
      case 'secretary':
        return 'Secretary';
      case 'treasurer':
        return 'Treasurer';
      case 'kagawad_representative':
        return 'Kagawad Representative';
      case 'barangay_tanod':
        return 'Barangay Tanod';
      case 'admin':
        return 'Administrator';
      case 'citizen':
      default:
        return 'Citizen';
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
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No image available',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
