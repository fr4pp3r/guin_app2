import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/validators.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gcashNameController = TextEditingController();
  final _gcashNumberController = TextEditingController();
  final _barangayNameController = TextEditingController();
  final _barangayAddressController = TextEditingController();
  final _barangayCaptainController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _logoUrlController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _gcashNameController.dispose();
    _gcashNumberController.dispose();
    _barangayNameController.dispose();
    _barangayAddressController.dispose();
    _barangayCaptainController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final barangayProvider = context.read<BarangayProvider>();

    try {
      await barangayProvider.loadConfig();

      final config = barangayProvider.config;
      if (config != null) {
        setState(() {
          _gcashNameController.text = config.gcashName;
          _gcashNumberController.text = config.gcashNumber;
          _barangayNameController.text = config.barangayName;
          _barangayAddressController.text = config.barangayAddress;
          _barangayCaptainController.text = config.barangayCaptain ?? '';
          _contactNumberController.text = config.contactNumber ?? '';
          _emailController.text = config.email ?? '';
          _logoUrlController.text = config.logoUrl ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showErrorSnackBar(context, l10n.asetLoadFailed);
      }
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final barangayProvider = context.read<BarangayProvider>();
    final config = barangayProvider.config;

    if (config == null) {
      Helpers.showErrorSnackBar(context, l10n.asetConfigNotLoaded);
      return;
    }

    Helpers.showLoadingDialog(context, l10n.asetSaving);

    try {
      await barangayProvider.updateConfig(
        id: config.id,
        gcashName: _gcashNameController.text.trim(),
        gcashNumber: _gcashNumberController.text.trim(),
        barangayName: _barangayNameController.text.trim(),
        barangayAddress: _barangayAddressController.text.trim(),
        barangayCaptain: _barangayCaptainController.text.trim().isEmpty
            ? null
            : _barangayCaptainController.text.trim(),
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
      );

      if (!mounted) return;
      Helpers.dismissDialog(context);

      setState(() => _isEditing = false);

      Helpers.showSuccessSnackBar(context, l10n.asetUpdated);
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(e.toString()),
      );
    }
  }

  Future<void> _uploadLogo() async {
    if (!_isEditing) return;

    final l10n = AppLocalizations.of(context);
    Helpers.showLoadingDialog(context, l10n.asetUploadingLogo);

    try {
      // Pick image file (returns List<PlatformFile> in newer versions)
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result == null || result.isEmpty) {
        if (!mounted) return;
        Helpers.dismissDialog(context);
        return;
      }

      final file = result.first;
      Uint8List fileBytes;
      if (file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
        if (fileBytes.isEmpty) {
          if (!mounted) return;
          Helpers.dismissDialog(context);
          Helpers.showErrorSnackBar(context, l10n.asetCouldNotReadFile);
          return;
        }
      } else {
        if (!mounted) return;
        Helpers.dismissDialog(context);
        Helpers.showErrorSnackBar(
          context,
          l10n.asetCouldNotReadFileNoPath,
        );
        return;
      };
      final extension = file.extension ?? 'png';
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      final bucket = 'barangay-assets';

      await supabase.storage.from(bucket).uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(
          contentType: 'image/png',
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);

      // Update controller and show success
      if (!mounted) return;
      Helpers.dismissDialog(context);

      setState(() {
        _logoUrlController.text = publicUrl;
      });

      Helpers.showSuccessSnackBar(context, l10n.asetLogoUploaded);
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        l10n.asetUploadFailed(Helpers.parseSupabaseError(e.toString())),
      );
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _loadConfig();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.asetTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.asetSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEditing && !_isLoading)
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                        ),
                        tooltip: l10n.asetEditSettingsTooltip,
                        onPressed: _toggleEdit,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // GCash Payment Section
                          _buildSectionHeader(
                            l10n.asetGcashSection,
                            Icons.payment,
                            Colors.blue,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          Container(
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
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.paddingL),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _gcashNameController,
                                    enabled: _isEditing,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetGcashAccountName,
                                      hintText: 'Juan Dela Cruz',
                                      prefixIcon: const Icon(Icons.person),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.asetGcashNameRequired;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  TextFormField(
                                    controller: _gcashNumberController,
                                    enabled: _isEditing,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetGcashNumber,
                                      hintText: '09171234567',
                                      prefixIcon: const Icon(Icons.phone),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.asetGcashNumberRequired;
                                      }
                                      if (!RegExp(
                                        r'^09\d{9}$',
                                      ).hasMatch(value.trim())) {
                                        return l10n.asetInvalidPhMobile;
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSizes.paddingXL),

                          // Barangay Information Section
                          _buildSectionHeader(
                            l10n.asetBarangaySection,
                            Icons.location_city,
                            Colors.green,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          Container(
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
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.paddingL),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _barangayNameController,
                                    enabled: _isEditing,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetBarangayName,
                                      hintText: 'Barangay San Antonio',
                                      prefixIcon: const Icon(Icons.location_on),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.asetBarangayNameRequired;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  TextFormField(
                                    controller: _barangayAddressController,
                                    enabled: _isEditing,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetBarangayAddress,
                                      hintText: l10n.asetCompleteAddressHint,
                                      prefixIcon: const Icon(Icons.home),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.asetBarangayAddressRequired;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  TextFormField(
                                    controller: _barangayCaptainController,
                                    enabled: _isEditing,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetBarangayCaptain,
                                      hintText: l10n.commonOptional,
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  TextFormField(
                                    controller: _contactNumberController,
                                    enabled: _isEditing,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetContactNumber,
                                      hintText: l10n.commonOptional,
                                      prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  const SizedBox(height: AppSizes.paddingM),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _logoUrlController,
                                          enabled: _isEditing,
                                          keyboardType: TextInputType.url,
                                          decoration: InputDecoration(
                                            labelText: l10n.asetBarangayLogoUrl,
                                            hintText: 'https://example.com/logo.png',
                                            prefixIcon: const Icon(Icons.image_outlined),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.paddingS),
                                      if (_isEditing)
                                        OutlinedButton.icon(
                                          onPressed: _uploadLogo,
                                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                                          label: Text(l10n.commonUpload),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSizes.paddingM),
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: _isEditing,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: l10n.asetEmailAddress,
                                      hintText: l10n.commonOptional,
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != null &&
                                          value.trim().isNotEmpty) {
                                        return Validators.validateEmail(value);
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSizes.paddingXL),

                          // Action Buttons
                          if (_isEditing) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _toggleEdit,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSizes.paddingM,
                                      ),
                                      side: const BorderSide(
                                        color: Colors.grey,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(l10n.commonCancel),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.paddingM),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1976D2),
                                          Color(0xFF2196F3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _saveConfig,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSizes.paddingM,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        l10n.commonSaveChanges,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
