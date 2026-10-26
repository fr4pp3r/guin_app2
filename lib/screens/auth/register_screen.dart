import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/services/ai_id_verifier.dart';
import 'package:guin_app/services/captcha_service.dart';
import 'package:guin_app/services/captcha_widget.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/image_compressor.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Form keys
  final _accountFormKey = GlobalKey<FormState>();
  final _personalFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _documentsFormKey = GlobalKey<FormState>();

  // Account Info Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  // Personal Info Controllers
  final _givenNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  String _selectedGender = 'Male';
  String _selectedCivilStatus = 'Single';
  final _phoneController = TextEditingController();

  // Address Controllers
  final _addressController = TextEditingController();

  // Documents
  File? _profilePhoto;
  File? _validIdFront;
  File? _validIdBack;
  File? _selfiePhoto;

  // ID details
  String? _selectedIdType;
  final _idNumberController = TextEditingController();
  DateTime? _idIssuedAt;
  DateTime? _idExpiryAt;

  // Indigent registration path (no valid government ID)
  bool _isIndigent = false;
  final _indigencyReasonController = TextEditingController();
  UserProfile? _selectedGuarantor;
  final _guarantorRelationshipController = TextEditingController();
  List<UserProfile> _approvedCitizens = [];
  bool _loadingCitizens = false;

  // AI pre-check
  bool _idPreCheckRunning = false;

  // reCAPTCHA
  String? _captchaToken;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _givenNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _placeOfBirthController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _indigencyReasonController.dispose();
    _guarantorRelationshipController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required Function(File) onImagePicked,
    double maxWidth = 1200,
    double maxHeight = 1200,
    int imageQuality = 85,
  }) async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (pickedFile != null) {
        onImagePicked(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authFailedPickImage)),
        );
      }
    }
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

  Future<void> _pickProfilePhoto() async {
    await _pickImage(
      onImagePicked: (file) => setState(() => _profilePhoto = file),
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
  }

  Future<void> _pickValidIdSide({required bool front}) async {
    await _pickImage(
      onImagePicked: (file) => setState(() {
        if (front) {
          _validIdFront = file;
        } else {
          _validIdBack = file;
        }
      }),
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
  }

  Future<void> _captureSelfie() async {
    // Try camera first, fall back to gallery
    final cameraAvailable = await _isCameraAvailable();
    if (cameraAvailable && mounted) {
      final result = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => const LivenessCaptureScreen(),
        ),
      );
      if (result != null) {
        setState(() => _selfiePhoto = result);
        return;
      }
    }
    // Fallback to gallery
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _selfiePhoto = File(pickedFile.path));
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.authCameraUnavailableGallery),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authFailedPickImage)),
        );
      }
    }
  }

  Future<bool> _isCameraAvailable() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (!result.isGranted) return false;
      }
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadApprovedCitizens() async {
    if (_approvedCitizens.isNotEmpty) return;
    setState(() => _loadingCitizens = true);
    try {
      final userService = UserService();
      final allUsers = await userService.getAllUsers();
      setState(() {
        _approvedCitizens = allUsers
            .where((u) => u.isApproved && u.isCitizen)
            .toList();
        _loadingCitizens = false;
      });
    } catch (e) {
      setState(() => _loadingCitizens = false);
    }
  }

  void _nextStep() {
    final l10n = AppLocalizations.of(context);
    bool isValid = false;
    switch (_currentStep) {
      case 0:
        isValid = _accountFormKey.currentState?.validate() ?? false;
        if (isValid &&
            _passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authPasswordsDoNotMatch)),
          );
          return;
        }
        break;
      case 1:
        isValid = _personalFormKey.currentState?.validate() ?? false;
        if (isValid && _selectedDateOfBirth == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authPleaseSelectDob)),
          );
          return;
        }
        break;
      case 2:
        isValid = _addressFormKey.currentState?.validate() ?? false;
        break;
      case 3:
        isValid = _documentsFormKey.currentState?.validate() ?? false;
        if (isValid && _profilePhoto == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authPleaseUploadProfilePhoto)),
          );
          return;
        }
        if (isValid && _selfiePhoto == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.authPleaseCaptureSelfie),
            ),
          );
          return;
        }
        if (isValid && !_isIndigent) {
          if (_selectedIdType == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.authPleaseSelectIdType)),
            );
            return;
          }
          if (_idNumberController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.authPleaseEnterIdNumber)),
            );
            return;
          }
          if (_validIdFront == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authPleaseUploadIdFront),
              ),
            );
            return;
          }
        }
        if (isValid && _isIndigent) {
          if (_indigencyReasonController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authPleaseDescribeReason),
              ),
            );
            return;
          }
          if (_selectedGuarantor == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authPleaseSelectGuarantor),
              ),
            );
            return;
          }
          if (_guarantorRelationshipController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authPleaseEnterGuarantorRelationship),
              ),
            );
            return;
          }
        }
        break;
    }

    if (isValid) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _handleRegister();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<IdVerificationSuggestion?> _runIdPreCheck() async {
    final selfie = _selfiePhoto;
    final validIdFront = _validIdFront;
    if (selfie == null || validIdFront == null || _selectedIdType == null) {
      return null;
    }

    setState(() => _idPreCheckRunning = true);
    try {
      final selfieB64 = await ImageCompressor.toBase64Png(selfie);
      final idFrontB64 = await ImageCompressor.toBase64Png(validIdFront);
      final idBackB64 = _validIdBack != null
          ? await ImageCompressor.toBase64Png(_validIdBack!)
          : null;
      if (selfieB64 == null || idFrontB64 == null) {
        debugPrint('ID pre-check: image compression failed');
        return null;
      }
      final fullNameForAi = [_givenNameController.text.trim(), if (_middleNameController.text.trim().isNotEmpty) _middleNameController.text.trim(), _lastNameController.text.trim()].join(' ');
      return await AiIdVerifier().verify(
        idType: _selectedIdType!,
        idFrontB64: idFrontB64,
        idBackB64: idBackB64,
        selfieB64: selfieB64,
        formFields: {
          'full_name': fullNameForAi,
          'date_of_birth': _selectedDateOfBirth == null
              ? ''
              : _selectedDateOfBirth!.toIso8601String().split('T').first,
          'address': _addressController.text.trim(),
          'gender': _selectedGender,
        },
      );
    } catch (e) {
      debugPrint('ID pre-check failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _idPreCheckRunning = false);
    }
  }

  Future<void> _handleRegister() async {
    final authProvider = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context);

    // reCAPTCHA is a hard gate — must be solved before submission.
    if (_captchaToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captchaRequired)),
      );
      return;
    }

    final captchaVerified = await CaptchaService().verify(_captchaToken!);
    if (captchaVerified != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.captchaFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _captchaToken = null);
      return;
    }

    final now = DateTime.now();
    final age =
        now.year -
        _selectedDateOfBirth!.year -
        (now.month < _selectedDateOfBirth!.month ||
                (now.month == _selectedDateOfBirth!.month &&
                    now.day < _selectedDateOfBirth!.day)
            ? 1
            : 0);

    Map<String, dynamic>? kycAiResult;
    var preCheckUnavailable = false;

    if (!_isIndigent) {
      final suggestion = await _runIdPreCheck();
      if (suggestion == null) {
        preCheckUnavailable = true;
      } else {
        kycAiResult = suggestion.toStoredJson();
      }
    }

    final fullNameForAi = [_givenNameController.text.trim(), if (_middleNameController.text.trim().isNotEmpty) _middleNameController.text.trim(), _lastNameController.text.trim()].join(' ');

    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      givenName: _givenNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      address: _addressController.text.trim(),
      age: age,
      phoneNumber: _phoneController.text.trim(),
      dateOfBirth: _selectedDateOfBirth!,
      placeOfBirth: _placeOfBirthController.text.trim(),
      civilStatus: _selectedCivilStatus,
      gender: _selectedGender,
      profilePhoto: _profilePhoto,
      validIdFront: _validIdFront,
      validIdBack: _validIdBack,
      idType: _selectedIdType,
      idNumber: _idNumberController.text.trim(),
      idIssuedAt: _idIssuedAt,
      idExpiryAt: _idExpiryAt,
      livenessVerified: _selfiePhoto != null,
      kycAiResult: kycAiResult,
      isIndigent: _isIndigent,
      indigencyReason: _isIndigent
          ? _indigencyReasonController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preCheckUnavailable
                ? l10n.authAiPrecheckUnavailable
                : l10n.authRegistrationSuccessful,
          ),
          backgroundColor: preCheckUnavailable ? null : Colors.green,
        ),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.error ?? l10n.authRegistrationFailed,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static const _kBlue = Color(0xFF1976D2);
  static const _kBlueDark = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      l10n.authStepAccountLabel,
      l10n.authStepPersonalLabel,
      l10n.commonAddress,
      l10n.commonDocuments,
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBlueDark, _kBlue, Color(0xFF42A5F5)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (_currentStep > 0) {
                              _previousStep();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            l10n.authCreateAccountTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          l10n.authStepProgress(_currentStep + 1, 4),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: List.generate(steps.length * 2 - 1, (i) {
                        if (i.isOdd) {
                          final stepIdx = i ~/ 2;
                          return Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.only(bottom: 18),
                              color: _currentStep > stepIdx
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          );
                        }
                        final step = i ~/ 2;
                        final isActive = _currentStep >= step;
                        final isDone = _currentStep > step;
                        return Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: _kBlue,
                                      )
                                    : Text(
                                        '${step + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? _kBlue
                                              : Colors.white70,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              steps[step],
                              style: TextStyle(
                                fontSize: 10,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAccountStep(),
                _buildPersonalStep(),
                _buildAddressStep(),
                _buildDocumentsStep(),
              ],
            ),
          ),
          if (_currentStep == 3 && _captchaToken == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.captchaTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.captchaSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CaptchaWidget(
                    onSolved: (token) => setState(() => _captchaToken = token),
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBlue,
                        side: const BorderSide(color: _kBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.commonBack,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Consumer<AuthProvider>(
                    builder: (context, authProvider, _) => ElevatedButton(
                      onPressed:
                          (authProvider.isLoading || _idPreCheckRunning)
                              ? null
                              : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
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
                          : _idPreCheckRunning
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.authCheckingId,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _currentStep == 3
                                  ? l10n.authSubmitRegistration
                                  : l10n.commonContinue,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(
              l10n.authAccountInfoTitle,
              l10n.authAccountInfoSubtitle,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.commonEmail,
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authEmailRequired;
                if (!v.contains('@')) return l10n.authEmailInvalid;
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.commonUsername,
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authUsernameRequired;
                if (v.length < 3) return l10n.authUsernameMinLength(3);
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l10n.commonPassword,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authPasswordRequired;
                if (v.length < 6) return l10n.authPasswordMinLength(6);
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: l10n.authConfirmPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authConfirmPasswordRequired;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(
              l10n.authPersonalInfoTitle,
              l10n.authPersonalInfoSubtitle,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _givenNameController,
              decoration: InputDecoration(
                labelText: l10n.authGivenNameLabel,
                prefixIcon: Icon(Icons.person_outline),
                hintText: l10n.authGivenNameHint,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.authGivenNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _middleNameController,
              decoration: InputDecoration(
                labelText: l10n.authMiddleNameLabel,
                prefixIcon: Icon(Icons.person_outline),
                hintText: l10n.authMiddleNameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: l10n.authLastNameLabel,
                prefixIcon: Icon(Icons.person_outline),
                hintText: l10n.authLastNameHint,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.authLastNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDateOfBirth = date);
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: _selectedDateOfBirth == null
                        ? l10n.authDateOfBirthTapToSelect
                        : l10n.authDateOfBirthSelected(
                            _selectedDateOfBirth!.day,
                            _selectedDateOfBirth!.month,
                            _selectedDateOfBirth!.year,
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
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authPlaceOfBirthRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: l10n.commonGender,
                prefixIcon: Icon(Icons.wc),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Male',
                  child: Text(l10n.commonMale),
                ),
                DropdownMenuItem(
                  value: 'Female',
                  child: Text(l10n.commonFemale),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text(l10n.commonOther),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGender = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCivilStatus,
              decoration: InputDecoration(
                labelText: l10n.commonCivilStatus,
                prefixIcon: Icon(Icons.family_restroom),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Single',
                  child: Text(l10n.commonSingle),
                ),
                DropdownMenuItem(
                  value: 'Married',
                  child: Text(l10n.commonMarried),
                ),
                DropdownMenuItem(
                  value: 'Widowed',
                  child: Text(l10n.commonWidowed),
                ),
                DropdownMenuItem(
                  value: 'Divorced',
                  child: Text(l10n.commonDivorced),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCivilStatus = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.commonPhoneNumber,
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authPhoneRequired
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressStep() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(
              l10n.authAddressInfoTitle,
              l10n.authAddressInfoSubtitle,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.authAddressNotice,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _addressController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.authCompleteAddressLabel,
                prefixIcon: Icon(Icons.home_outlined),
                hintText: l10n.authAddressHint,
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authAddressRequired
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsStep() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _documentsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(
              l10n.authIdentityVerificationTitle,
              l10n.authIdentityVerificationSubtitle,
            ),
            const SizedBox(height: 24),
            _indigentOptionTile(),
            const SizedBox(height: 16),
            _uploadCard(
              label: l10n.commonProfilePhoto,
              subtitle: l10n.authProfilePhotoSubtitle,
              icon: Icons.add_a_photo_outlined,
              file: _profilePhoto,
              onTap: _pickProfilePhoto,
            ),
            const SizedBox(height: 16),
            _selfieCard(),
            const SizedBox(height: 16),
            if (!_isIndigent) ...[
              _idTypeDropdown(),
              const SizedBox(height: 16),
              _idNumberField(),
              const SizedBox(height: 16),
              _idDatePickers(),
              const SizedBox(height: 16),
              _idSideCards(),
            ] else ...[
              _indigentSection(),
            ],
            const SizedBox(height: 16),
            _infoBox(),
          ],
        ),
      ),
    );
  }

  Widget _indigentOptionTile() {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => setState(() {
        _isIndigent = !_isIndigent;
        if (_isIndigent) {
          _validIdFront = null;
          _validIdBack = null;
          _selectedIdType = null;
          _idNumberController.clear();
          _idIssuedAt = null;
          _idExpiryAt = null;
        } else {
          _indigencyReasonController.clear();
          _selectedGuarantor = null;
          _guarantorRelationshipController.clear();
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isIndigent
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
            width: _isIndigent ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isIndigent
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isIndigent
                  ? const Color(0xFF1976D2)
                  : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authIndigentOptionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.authIndigentOptionSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selfieCard() {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _captureSelfie,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selfiePhoto != null
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
            width: _selfiePhoto != null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _selfiePhoto == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      size: 32,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.authLiveSelfieLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.authLiveSelfieSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.authTapToCapture,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      _selfiePhoto!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.authLivenessSelfieBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _idTypeDropdown() {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      value: _selectedIdType,
      decoration: InputDecoration(
        labelText: l10n.authIdTypeLabel,
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: KycIdTypes.values
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(KycIdTypes.labels[t] ?? t),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedIdType = v),
      validator: (v) => v == null ? l10n.authPleaseSelectIdType : null,
    );
  }

  Widget _idNumberField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _idNumberController,
      decoration: InputDecoration(
        labelText: l10n.authIdNumberLabel,
        prefixIcon: Icon(Icons.numbers),
        hintText: l10n.authIdNumberHint,
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? l10n.authIdNumberRequired
          : null,
    );
  }

  Widget _idDatePickers() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _idIssuedAt = date);
            },
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: _idIssuedAt == null
                      ? l10n.authDateIssuedOptional
                      : l10n.authIdIssuedSelected(
                          _idIssuedAt!.day,
                          _idIssuedAt!.month,
                          _idIssuedAt!.year,
                        ),
                  prefixIcon: const Icon(Icons.event_available),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => _idExpiryAt = date);
            },
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: _idExpiryAt == null
                      ? l10n.authExpiryDateOptional
                      : l10n.authIdExpirySelected(
                          _idExpiryAt!.day,
                          _idExpiryAt!.month,
                          _idExpiryAt!.year,
                        ),
                  prefixIcon: const Icon(Icons.event_busy),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _idSideCards() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _idSideCard(
            label: l10n.authIdFrontLabel,
            subtitle: l10n.authIdFrontSubtitle,
            file: _validIdFront,
            onTap: () => _pickValidIdSide(front: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _idSideCard(
            label: l10n.authIdBackLabel,
            subtitle: l10n.authIdBackSubtitle,
            file: _validIdBack,
            onTap: () => _pickValidIdSide(front: false),
          ),
        ),
      ],
    );
  }

  Widget _indigentSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _indigencyReasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.authReasonSituationLabel,
            hintText: l10n.authReasonSituationHint,
            prefixIcon: Icon(Icons.speaker_notes_outlined),
            alignLabelWithHint: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.authPleaseDescribeReason
              : null,
        ),
        const SizedBox(height: 16),
        _guarantorPicker(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _guarantorRelationshipController,
          decoration: InputDecoration(
            labelText: l10n.authGuarantorRelationshipLabel,
            hintText: l10n.authGuarantorRelationshipHint,
            prefixIcon: Icon(Icons.people_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.authPleaseEnterGuarantorRelationship
              : null,
        ),
      ],
    );
  }

  Widget _guarantorPicker() {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () async {
        await _loadApprovedCitizens();
        if (!mounted) return;
        final selected = await showDialog<UserProfile>(
          context: context,
          builder: (ctx) => _GuarantorSearchDialog(
            citizens: _approvedCitizens,
            loading: _loadingCitizens,
          ),
        );
        if (selected != null) {
          setState(() => _selectedGuarantor = selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedGuarantor != null
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
            width: _selectedGuarantor != null ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedGuarantor != null
                  ? Icons.check_circle
                  : Icons.person_search,
              color: _selectedGuarantor != null
                  ? const Color(0xFF1976D2)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedGuarantor == null
                  ? Text(
                      l10n.authSelectGuarantorLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedGuarantor!.fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '@${_selectedGuarantor!.username}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _infoBox() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_outlined,
            color: Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isIndigent
                  ? l10n.authInfoBoxIndigent
                  : l10n.authInfoBoxStandard,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _uploadCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
            width: file != null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 32, color: const Color(0xFF1976D2)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.commonTapToUpload,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
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
              ),
      ),
    );
  }

  Widget _idSideCard({
    required String label,
    required String subtitle,
    required File? file,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
            width: file != null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      size: 26,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.commonTapToUpload,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Liveness Capture Screen ──────────────────────────────────────────────────

class LivenessCaptureScreen extends StatefulWidget {
  const LivenessCaptureScreen({super.key});

  @override
  State<LivenessCaptureScreen> createState() => _LivenessCaptureScreenState();
}

class _LivenessCaptureScreenState extends State<LivenessCaptureScreen> {
  CameraController? _controller;
  bool _initialized = false;
  bool _capturing = false;
  String _challenge = '';
  final _random = Random();

  static const _challenges = [
    'Blink your eyes',
    'Turn your head left',
    'Turn your head right',
    'Look up',
    'Smile',
  ];

  static const _challengeIcons = [
    Icons.visibility,
    Icons.arrow_back,
    Icons.arrow_forward,
    Icons.keyboard_arrow_up,
    Icons.sentiment_very_satisfied,
  ];

  @override
  void initState() {
    super.initState();
    _challenge = _challenges[_random.nextInt(_challenges.length)];
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authNoCameraAvailable)),
          );
          Navigator.pop(context);
        }
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authCameraError(e))),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_initialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(image.path));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authCaptureFailed(e))),
        );
      }
    }
  }

  void _newChallenge() {
    setState(() {
      _challenge = _challenges[_random.nextInt(_challenges.length)];
    });
  }

  String _localizedChallenge(String challenge, AppLocalizations l10n) {
    switch (challenge) {
      case 'Blink your eyes':
        return l10n.authChallengeBlink;
      case 'Turn your head left':
        return l10n.authChallengeTurnLeft;
      case 'Turn your head right':
        return l10n.authChallengeTurnRight;
      case 'Look up':
        return l10n.authChallengeLookUp;
      case 'Smile':
        return l10n.authChallengeSmile;
    }
    return challenge;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.authLivenessVerificationTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _initialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CameraPreview(_controller!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _challengeIcons[_challenges.indexOf(_challenge)],
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _localizedChallenge(_challenge, l10n),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authFollowChallengeHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _newChallenge,
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        label: Text(
                          l10n.authNewChallenge,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: _capturing
                              ? const CircularProgressIndicator(
                                  color: Color(0xFF1976D2),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Color(0xFF1976D2),
                                  size: 32,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guarantor Search Dialog ───────────────────────────────────────────────────

class _GuarantorSearchDialog extends StatefulWidget {
  final List<UserProfile> citizens;
  final bool loading;

  const _GuarantorSearchDialog({
    required this.citizens,
    required this.loading,
  });

  @override
  State<_GuarantorSearchDialog> createState() => _GuarantorSearchDialogState();
}

class _GuarantorSearchDialogState extends State<_GuarantorSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.citizens.where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              l10n.authSelectGuarantorDialogTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.authGuarantorSearchHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.authNoApprovedCitizens,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: u.profilePhotoUrl != null
                                ? NetworkImage(u.profilePhotoUrl!)
                                : null,
                            child: u.profilePhotoUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(u.fullName),
                          subtitle: Text('@${u.username}'),
                          onTap: () => Navigator.pop(context, u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
