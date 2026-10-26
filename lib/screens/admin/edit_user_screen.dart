import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

/// Officer-facing screen to correct another user's profile details
/// (name, DOB, address, etc.). Role, registration status, credentials and
/// ID images are not editable here — the officer reads the ID photo and
/// retypes the correct value; no AI-corrected values are ever prefilled.
class EditUserScreen extends StatefulWidget {
  final UserProfile user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _givenNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _placeOfBirthCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _dob;
  String _civilStatus = 'Single';
  String _gender = 'Male';
  int _age = 0;

  static const _kBlue = Color(0xFF1565C0);

  final _civilStatuses = ['Single', 'Married', 'Widowed', 'Divorced'];
  final _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _givenNameCtrl.text = widget.user.givenName;
    _middleNameCtrl.text = widget.user.middleName;
    _lastNameCtrl.text = widget.user.lastName;
    _placeOfBirthCtrl.text = widget.user.placeOfBirth;
    _phoneCtrl.text = widget.user.phoneNumber;
    _addressCtrl.text = widget.user.address;
    _dob = widget.user.dateOfBirth;
    _civilStatus = _civilStatuses.contains(widget.user.civilStatus)
        ? widget.user.civilStatus
        : 'Single';
    _gender = _genders.contains(widget.user.gender)
        ? widget.user.gender
        : 'Male';
    _age = _calculateAge(_dob!);
  }

  @override
  void dispose() {
    _givenNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
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

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _age = _calculateAge(picked);
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    Helpers.showLoadingDialog(context, l10n.profileSavingChanges);
    final userProvider = context.read<UserProvider>();
    final ok = await userProvider.updateUserInfo(
      userId: widget.user.id,
      givenName: _givenNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      age: _age,
      dateOfBirth: _dob!,
      placeOfBirth: _placeOfBirthCtrl.text.trim(),
      civilStatus: _civilStatus,
      gender: _gender,
      phoneNumber: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    Helpers.dismissDialog(context);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      // Stay on the page so the officer can fix and resubmit.
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(userProvider.errorMessage ?? ''),
      );
    }
  }

  // ── Read-only summary of who is being edited ──────────────────────────

  Widget _buildSummaryCard(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.auserEditUserTitle,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _readOnlyRow(
              Icons.person_outline,
              l10n.commonFullName,
              widget.user.fullName,
            ),
            _readOnlyRow(
              Icons.alternate_email,
              l10n.commonUsername,
              '@${widget.user.username}',
            ),
            _readOnlyRow(
              Icons.email_outlined,
              l10n.commonEmail,
              widget.user.email,
            ),
            _readOnlyRow(
              Icons.badge_outlined,
              l10n.commonRole,
              AppRoles.displayName(widget.user.role),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
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

  // ── Editable fields ───────────────────────────────────────────────────

  TextFormField _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final l10n = AppLocalizations.of(context);
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
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
    );
  }

  String _civilStatusLabel(String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'Married':
        return l10n.commonMarried;
      case 'Widowed':
        return l10n.commonWidowed;
      case 'Divorced':
        return l10n.commonDivorced;
      case 'Single':
        return l10n.commonSingle;
      default:
        return value;
    }
  }

  String _genderLabel(String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'Male':
        return l10n.commonMale;
      case 'Female':
        return l10n.commonFemale;
      case 'Other':
        return l10n.commonOther;
      default:
        return value;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header (mirrors create_user_screen.dart).
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
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
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            l10n.auserEditUserTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(
                      l10n.auserEditInfo,
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

          // Scrollable form.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(l10n),
                    const SizedBox(height: 16),
                    _field(
                      _givenNameCtrl,
                      l10n.acreateGivenNameLabel,
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _middleNameCtrl,
                      l10n.acreateMiddleNameLabel,
                      Icons.person_outline,
                      validator: (_) => null, // middle name is optional
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _lastNameCtrl,
                      l10n.acreateLastNameLabel,
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    // Date of birth — tap to pick, read-only text field.
                    GestureDetector(
                      onTap: _pickDob,
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: _dob == null
                                ? l10n.acreateDobTapToSelect
                                : l10n.acreateDobSelected(
                                    _dob!.year, _dob!.month, _dob!.day),
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => _dob == null
                              ? l10n.authPleaseSelectDob
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Text(
                        '${l10n.commonAge}: $_age',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _field(
                      _placeOfBirthCtrl,
                      l10n.commonPlaceOfBirth,
                      Icons.place_outlined,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _civilStatus,
                      decoration: InputDecoration(
                        labelText: l10n.commonCivilStatus,
                        prefixIcon: const Icon(Icons.family_restroom_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _civilStatuses
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(_civilStatusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _civilStatus = v ?? _civilStatus),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: l10n.commonGender,
                        prefixIcon: const Icon(Icons.wc_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _genders
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(_genderLabel(g)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _phoneCtrl,
                      l10n.commonPhoneNumber,
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _addressCtrl,
                      l10n.commonAddress,
                      Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sticky bottom Save button.
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.commonSaveChanges,
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
    );
  }
}
