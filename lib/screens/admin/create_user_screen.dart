import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Form keys
  final _accountFormKey = GlobalKey<FormState>();
  final _personalFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  // Step 1 — Account
  final _givenNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String _role = 'citizen';

  // Step 2 — Personal
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _placeOfBirthCtrl = TextEditingController();
  DateTime? _dob;
  String _civilStatus = 'Single';
  String _gender = 'Male';

  // Step 3 — Address & Documents
  final _addressCtrl = TextEditingController();
  File? _profilePhoto;
  File? _validIdFront;
  File? _validIdBack;

  final _imagePicker = ImagePicker();

  static const _kBlue = Color(0xFF1565C0);

  final _roles = [
    'citizen',
    'secretary',
    'treasurer',
    'kagawad_representative',
    'barangay_tanod',
    'captain',
    'admin',
  ];
  final _civilStatuses = ['Single', 'Married', 'Widowed', 'Divorced'];
  final _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _pageController.dispose();
    _givenNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isPhoto, {bool front = true}) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isPhoto ? 800 : 1200,
      maxHeight: isPhoto ? 800 : 1200,
      imageQuality: isPhoto ? 85 : 90,
    );
    if (picked != null) {
      setState(() {
        if (isPhoto) {
          _profilePhoto = File(picked.path);
        } else if (front) {
          _validIdFront = File(picked.path);
        } else {
          _validIdBack = File(picked.path);
        }
      });
    }
  }

  void _nextStep() {
    bool valid = false;
    switch (_currentStep) {
      case 0:
        valid = _accountFormKey.currentState?.validate() ?? false;
        break;
      case 1:
        valid = _personalFormKey.currentState?.validate() ?? false;
        if (valid && _dob == null) {
          Helpers.showErrorSnackBar(context, 'Please select date of birth');
          return;
        }
        break;
      case 2:
        valid = _addressFormKey.currentState?.validate() ?? false;
        if (valid) _submit();
        return;
    }
    if (valid) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    Helpers.showLoadingDialog(context, 'Creating user...');
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final userProvider = context.read<UserProvider>();

    final ok = await userProvider.createUser(
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      givenName: _givenNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      age: age,
      dateOfBirth: _dob!,
      placeOfBirth: _placeOfBirthCtrl.text.trim(),
      civilStatus: _civilStatus,
      gender: _gender,
      phoneNumber: _phoneCtrl.text.trim(),
      role: _role,
      profilePhoto: _profilePhoto,
      validIdFront: _validIdFront,
      validIdBack: _validIdBack,
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (ok) {
      final fullName = [_givenNameCtrl.text.trim(), if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim(), _lastNameCtrl.text.trim()].join(' ');
      Helpers.showSuccessSnackBar(
        context,
        'User "$fullName" created successfully',
      );
      Navigator.pop(context);
    } else {
      final raw = userProvider.errorMessage ?? '';
      final msg = Helpers.parseSupabaseError(raw);
      final display =
          (msg == 'An error occurred. Please try again' && raw.isNotEmpty)
          ? raw.replaceAll('Exception: ', '')
          : msg;
      Helpers.showErrorSnackBar(context, display);
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Account', 'Personal', 'Address & Docs'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue, Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                          onPressed: _prevStep,
                        ),
                        const Expanded(
                          child: Text(
                            'Create New User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Step ${_currentStep + 1}/${steps.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Step indicators
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: List.generate(steps.length * 2 - 1, (i) {
                        if (i.isOdd) {
                          final stepIdx = i ~/ 2;
                          return Expanded(
                            child: Container(
                              height: 2,
                              color: stepIdx < _currentStep
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          );
                        }
                        final stepIdx = i ~/ 2;
                        final isDone = stepIdx < _currentStep;
                        final isCurrent = stepIdx == _currentStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isCurrent ? 36 : 28,
                          height: isCurrent ? 36 : 28,
                          decoration: BoxDecoration(
                            color: isDone || isCurrent
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
                                    '${stepIdx + 1}',
                                    style: TextStyle(
                                      fontSize: isCurrent ? 15 : 12,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent
                                          ? _kBlue
                                          : Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Step label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      steps[_currentStep],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAccountStep(),
                _buildPersonalStep(),
                _buildAddressDocsStep(),
              ],
            ),
          ),

          // Bottom nav
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _kBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: Icon(
                      _currentStep == steps.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                      size: 18,
                    ),
                    label: Text(
                      _currentStep == steps.length - 1 ? 'Create User' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
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
        ],
      ),
    );
  }

  // ── Step 1: Account Info ─────────────────────────────────────────────────

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Form(
        key: _accountFormKey,
        child: Column(
          children: [
            _field(_givenNameCtrl, 'Given Name *', Icons.badge),
            const SizedBox(height: 14),
            _field(_middleNameCtrl, 'Middle Name', Icons.badge),
            const SizedBox(height: 14),
            _field(_lastNameCtrl, 'Last Name *', Icons.badge),
            const SizedBox(height: 14),
            _field(_usernameCtrl, 'Username', Icons.alternate_email),
            const SizedBox(height: 14),
            _field(
              _emailCtrl,
              'Email',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(
                labelText: 'Role',
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _roles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(AppRoles.displayName(r)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Personal ─────────────────────────────────────────────────────

  Widget _buildPersonalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Form(
        key: _personalFormKey,
        child: Column(
          children: [
            _field(
              _phoneCtrl,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _field(
              _ageCtrl,
              'Age',
              Icons.numbers,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _field(_placeOfBirthCtrl, 'Place of Birth', Icons.place_outlined),
            const SizedBox(height: 14),
            // Date of birth
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: _dob == null
                        ? 'Date of Birth (tap to select)'
                        : 'DOB: ${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _civilStatus,
              decoration: InputDecoration(
                labelText: 'Civil Status',
                prefixIcon: const Icon(Icons.family_restroom_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _civilStatuses
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _civilStatus = v ?? _civilStatus),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Address & Documents ──────────────────────────────────────────

  Widget _buildAddressDocsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              _addressCtrl,
              'Home Address',
              Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Profile Photo
            const Text(
              'Profile Photo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildProfilePhotoCard(),
            const SizedBox(height: 20),

            // Valid ID
            const Text(
              'Valid ID',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIdCard(front: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildIdCard(front: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoCard() {
    return GestureDetector(
      onTap: () => _pickImage(true),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _profilePhoto == null
                ? const Color(0xFF1976D2).withValues(alpha: 0.4)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: _profilePhoto == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1976D2,
                      ).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_outlined,
                      size: 32,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to upload photo',
                    style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Optional',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _profilePhoto!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  _changeOverlay(() => _pickImage(true)),
                ],
              ),
      ),
    );
  }

  Widget _buildIdCard({required bool front}) {
    final file = front ? _validIdFront : _validIdBack;
    return GestureDetector(
      onTap: () => _pickImage(false, front: front),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file == null
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      size: 32,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    front ? 'ID Front' : 'ID Back',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Optional',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  _changeOverlay(() => _pickImage(false, front: front)),
                ],
              ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _changeOverlay(VoidCallback onTap) {
    return Positioned(
      bottom: 8,
      right: 8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                'Change',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: maxLines > 1,
      ),
      validator:
          validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
