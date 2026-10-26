import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/automation/profile_prefill.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/services/ai_document_processor.dart';
import 'package:guin_app/services/captcha_service.dart';
import 'package:guin_app/services/captcha_widget.dart';
import 'package:guin_app/utils/helpers.dart';

/// Which shared fill-up form a document type uses.
enum _FormFamily { cedula, indigency, barangayId }

class _DocumentTypeOption {
  const _DocumentTypeOption({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.family,
  });

  final String type;
  final String title;
  final String description;
  final IconData icon;
  final _FormFamily family;
}

/// All document types a citizen can request, in the order they are shown.
/// Types 1,2,3,7,8 share the cedula form; 4,5,6 share the indigency form;
/// barangay_id keeps its own small form.
const List<_DocumentTypeOption> _documentTypeOptions = [
  _DocumentTypeOption(
    type: 'business_clearance',
    title: 'Barangay Business Clearance',
    description: 'For business permits and renewals',
    icon: Icons.storefront,
    family: _FormFamily.cedula,
  ),
  _DocumentTypeOption(
    type: 'certification',
    title: 'Barangay Certification',
    description: 'General barangay certification',
    icon: Icons.verified,
    family: _FormFamily.cedula,
  ),
  _DocumentTypeOption(
    type: 'barangay_clearance',
    title: 'Barangay Clearance',
    description: 'Certificate of residence and good standing',
    icon: Icons.description,
    family: _FormFamily.cedula,
  ),
  _DocumentTypeOption(
    type: 'oath_undertaking',
    title: 'Oath of Undertaking',
    description: 'For first-time job seekers',
    icon: Icons.assignment_turned_in,
    family: _FormFamily.indigency,
  ),
  _DocumentTypeOption(
    type: 'indigency',
    title: 'Certificate of Indigency',
    description: 'For financial assistance purposes',
    icon: Icons.volunteer_activism,
    family: _FormFamily.indigency,
  ),
  _DocumentTypeOption(
    type: 'good_moral',
    title: 'Certificate of Good Moral Character',
    description: 'Character reference',
    icon: Icons.workspace_premium,
    family: _FormFamily.indigency,
  ),
  _DocumentTypeOption(
    type: 'residency',
    title: 'Certificate of Residency',
    description: 'Proof of residency',
    icon: Icons.home,
    family: _FormFamily.cedula,
  ),
  _DocumentTypeOption(
    type: 'cedula',
    title: 'Cedula',
    description: 'Community tax certificate',
    icon: Icons.receipt_long,
    family: _FormFamily.cedula,
  ),
  _DocumentTypeOption(
    type: 'barangay_id',
    title: 'Barangay ID',
    description: 'Official barangay identification',
    icon: Icons.badge,
    family: _FormFamily.barangayId,
  ),
];

const List<String> _genders = ['Male', 'Female'];
const List<String> _civilStatuses = ['Single', 'Married', 'Widowed', 'Divorced'];

class RequestDocumentScreen extends StatefulWidget {
  const RequestDocumentScreen({super.key});

  @override
  State<RequestDocumentScreen> createState() => _RequestDocumentScreenState();
}

class _RequestDocumentScreenState extends State<RequestDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = ExpansibleController();
  final _purposeController = TextEditingController();

  // Barangay ID form controllers (only used by the barangay_id type).
  final _idFullNameController = TextEditingController();
  final _idAddressController = TextEditingController();
  final _idContactController = TextEditingController();

  // Shared controllers for the indigency fill-up form (oath_undertaking,
  // indigency, good_moral). One set is reused across all three types. The
  // purpose is the shared top-level field, not stored here.
  final _indigencyFullNameController = TextEditingController();
  final _indigencyAddressController = TextEditingController();
  final _indigencyAgeController = TextEditingController();
  final _indigencyCivilStatusController = TextEditingController();
  final _indigencyRequesterController = TextEditingController();
  final _indigencyRequesterAddressController = TextEditingController();

  // Shared controllers for the cedula fill-up form (business_clearance,
  // certification, barangay_clearance, residency, cedula). One set is reused
  // across all five types.
  final _cedulaLastNameController = TextEditingController();
  final _cedulaFirstNameController = TextEditingController();
  final _cedulaMiddleNameController = TextEditingController();
  final _cedulaAddressController = TextEditingController();
  final _cedulaBirthPlaceController = TextEditingController();
  final _cedulaHeightController = TextEditingController();
  final _cedulaWeightController = TextEditingController();
  final _cedulaTinController = TextEditingController();
  final _cedulaOccupationController = TextEditingController();
  final _cedulaAnnualIncomeController = TextEditingController();
  final _cedulaCitizenshipController = TextEditingController(text: 'Filipino');
  DateTime? _cedulaBirthDate;
  String _cedulaGender = 'Male';
  String _cedulaCivilStatus = 'Single';
  String _businessStatus = 'NEW';

  String? _selectedDocumentType;
  final bool _showPaymentSection = false;
  File? _receiptImage;
  final _imagePicker = ImagePicker();

  DocumentProcessingSuggestion? _aiSuggestion;
  bool _aiProcessing = false;
  bool _aiSuggestionApplied = false;
  final _aiProcessor = AiDocumentProcessor();

  // reCAPTCHA
  String? _captchaToken;

  _DocumentTypeOption? get _selectedOption {
    final type = _selectedDocumentType;
    if (type == null) return null;
    for (final option in _documentTypeOptions) {
      if (option.type == type) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BarangayProvider>().loadConfig();
      context.read<BarangayProvider>().loadFees();
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _purposeController.dispose();
    _idFullNameController.dispose();
    _idAddressController.dispose();
    _idContactController.dispose();
    _indigencyFullNameController.dispose();
    _indigencyAddressController.dispose();
    _indigencyAgeController.dispose();
    _indigencyCivilStatusController.dispose();
    _indigencyRequesterController.dispose();
    _indigencyRequesterAddressController.dispose();
    _cedulaLastNameController.dispose();
    _cedulaFirstNameController.dispose();
    _cedulaMiddleNameController.dispose();
    _cedulaAddressController.dispose();
    _cedulaBirthPlaceController.dispose();
    _cedulaHeightController.dispose();
    _cedulaWeightController.dispose();
    _cedulaTinController.dispose();
    _cedulaOccupationController.dispose();
    _cedulaAnnualIncomeController.dispose();
    _cedulaCitizenshipController.dispose();
    super.dispose();
  }

  /// Fills the family's controllers with profile-backed values whenever the
  /// citizen switches document families. Values already typed are kept when
  /// staying inside the same family.
  void _seedFromProfile(String documentType) {
    final UserProfile? profile = context.read<AuthProvider>().userProfile;
    if (profile == null) return;
    final data = profileDocumentData(profile, documentType);
    String value(String key) => data[key] as String? ?? '';

    switch (_selectedOption?.family) {
      case _FormFamily.barangayId:
        _idFullNameController.text = value('full_name');
        _idAddressController.text = value('address');
        _idContactController.text = value('contact_number');
      case _FormFamily.indigency:
        _indigencyFullNameController.text = value('full_name');
        _indigencyAddressController.text = value('address');
        _indigencyAgeController.text = value('age');
        _indigencyCivilStatusController.text = value('civil_status');
        _indigencyRequesterController.text = value('requester');
        _indigencyRequesterAddressController.text = value('requester_address');
      case _FormFamily.cedula:
        _cedulaLastNameController.text = value('last_name');
        _cedulaFirstNameController.text = value('first_name');
        _cedulaMiddleNameController.text = value('middle_name');
        _cedulaAddressController.text = value('address');
        _cedulaBirthPlaceController.text = value('birth_place');
        _cedulaCitizenshipController.text = value('citizenship');
        _cedulaBirthDate = profile.dateOfBirth;
        _cedulaGender =
            _genders.contains(profile.gender) ? profile.gender : 'Male';
        _cedulaCivilStatus = _civilStatuses.contains(profile.civilStatus)
            ? profile.civilStatus
            : 'Single';
      case null:
        return;
    }
  }

  Map<String, dynamic> _getDocumentData() {
    switch (_selectedOption?.family) {
      case _FormFamily.barangayId:
        return {
          'full_name': _idFullNameController.text.trim(),
          'address': _idAddressController.text.trim(),
          'contact_number': _idContactController.text.trim(),
        };
      case _FormFamily.indigency:
        return {
          'full_name': _indigencyFullNameController.text.trim(),
          'address': _indigencyAddressController.text.trim(),
          'age': _indigencyAgeController.text.trim(),
          'civil_status': _indigencyCivilStatusController.text.trim(),
          'requester': _indigencyRequesterController.text.trim(),
          'requester_address': _indigencyRequesterAddressController.text.trim(),
          'purpose': _purposeController.text.trim(),
        };
      case _FormFamily.cedula:
        final cedulaData = <String, dynamic>{
          'last_name': _cedulaLastNameController.text.trim(),
          'first_name': _cedulaFirstNameController.text.trim(),
          'middle_name': _cedulaMiddleNameController.text.trim(),
          'address': _cedulaAddressController.text.trim(),
          'gender': _cedulaGender,
          'civil_status': _cedulaCivilStatus,
          'birth_place': _cedulaBirthPlaceController.text.trim(),
          'birth_date': _cedulaBirthDate?.toIso8601String(),
          'height': _cedulaHeightController.text.trim(),
          'weight': _cedulaWeightController.text.trim(),
          'tin': _cedulaTinController.text.trim(),
          'occupation': _cedulaOccupationController.text.trim(),
          'annual_income': _cedulaAnnualIncomeController.text.trim(),
          'citizenship': _cedulaCitizenshipController.text.trim(),
          'purpose': _purposeController.text.trim(),
        };
        if (_selectedOption?.type == 'business_clearance') {
          cedulaData['business_status'] = _businessStatus;
        }
        return cedulaData;
      case null:
        return {};
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reqDocFailedPickReceipt)),
        );
      }
    }
  }

  TextEditingController? _controllerForSuggestionField(String field) {
    switch (_selectedOption?.family) {
      case _FormFamily.barangayId:
        switch (field) {
          case 'full_name':
            return _idFullNameController;
          case 'address':
            return _idAddressController;
          case 'contact_number':
            return _idContactController;
          case 'purpose':
            return _purposeController;
          default:
            return null;
        }
      case _FormFamily.indigency:
        switch (field) {
          case 'full_name':
            return _indigencyFullNameController;
          case 'address':
            return _indigencyAddressController;
          case 'age':
            return _indigencyAgeController;
          case 'civil_status':
            return _indigencyCivilStatusController;
          case 'requester':
            return _indigencyRequesterController;
          case 'requester_address':
            return _indigencyRequesterAddressController;
          case 'purpose':
            return _purposeController;
          default:
            return null;
        }
      case _FormFamily.cedula:
        switch (field) {
          case 'last_name':
            return _cedulaLastNameController;
          case 'first_name':
            return _cedulaFirstNameController;
          case 'middle_name':
            return _cedulaMiddleNameController;
          case 'address':
            return _cedulaAddressController;
          case 'birth_place':
            return _cedulaBirthPlaceController;
          case 'height':
            return _cedulaHeightController;
          case 'weight':
            return _cedulaWeightController;
          case 'tin':
            return _cedulaTinController;
          case 'occupation':
            return _cedulaOccupationController;
          case 'annual_income':
            return _cedulaAnnualIncomeController;
          case 'citizenship':
            return _cedulaCitizenshipController;
          case 'purpose':
            return _purposeController;
          default:
            return null;
        }
      case null:
        return null;
    }
  }

  Future<void> _runAiCheck() async {
    if (_aiProcessing) return;
    final l10n = AppLocalizations.of(context);
    if (_selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reqDocSelectTypeFirst)),
      );
      return;
    }
    final purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reqDocEnterPurposeFirst)),
      );
      return;
    }

    setState(() => _aiProcessing = true);
    final suggestion = await _aiProcessor.process(
      documentType: _selectedDocumentType!,
      purpose: purpose,
      documentData: _getDocumentData(),
    );
    if (!mounted) return;
    setState(() {
      _aiProcessing = false;
      if (suggestion != null) {
        _aiSuggestion = suggestion;
        _aiSuggestionApplied = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reqDocAiUnavailable)),
        );
      }
    });
  }

  void _applyAiSuggestions() {
    final suggestion = _aiSuggestion;
    if (suggestion == null) return;
    setState(() {
      suggestion.suggestions.forEach((field, value) {
        final controller = _controllerForSuggestionField(field);
        if (controller != null) {
          controller.text = value;
        }
      });
      if (suggestion.normalizedPurpose.trim().isNotEmpty) {
        _purposeController.text = suggestion.normalizedPurpose;
      }
      _aiSuggestionApplied = false;
      _aiSuggestion = null;
    });
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reqDocSuggestionsApplied),
      ),
    );
  }

  Widget _buildAiSuggestionCard() {
    final suggestion = _aiSuggestion;
    if (!_aiSuggestionApplied || suggestion == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final hasFindings = suggestion.issues.isNotEmpty ||
        suggestion.suggestions.isNotEmpty ||
        suggestion.normalizedPurpose.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasFindings)
              Text(l10n.reqDocDetailsVerified)
            else ...[
              Text(
                l10n.reqDocIssuesFound,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (suggestion.issues.isNotEmpty)
                ...suggestion.issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $issue'),
                  ),
                ),
              if (suggestion.suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.reqDocAiSuggestions,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...suggestion.suggestions.entries.map(
                  (entry) => Text('${entry.key}: ${entry.value}'),
                ),
              ],
              if (suggestion.normalizedPurpose.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.reqDocNormalizedPurpose(suggestion.normalizedPurpose)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _applyAiSuggestions,
                  child: Text(l10n.reqDocApplySuggestions),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    final l10n = AppLocalizations.of(context);
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      _detailsController.expand();
      return;
    }
    if (_selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reqDocPleaseSelectType)),
      );
      return;
    }
    if (_selectedOption?.family == _FormFamily.cedula &&
        _cedulaBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reqDocPleaseSelectBirthDate)),
      );
      return;
    }

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

    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();
    final barangayProvider = context.read<BarangayProvider>();

    // A missing fee record is treated as a free document instead of blocking
    // the submission.
    final fee = barangayProvider.getFeeByType(_selectedDocumentType!);

    try {
      await documentProvider.createRequest(
        userId: authProvider.userProfile!.id,
        documentType: _selectedDocumentType!,
        purpose: _purposeController.text.trim(),
        documentData: _getDocumentData(),
        paymentAmount: fee == null || fee.isFree ? 0.0 : fee.feeAmount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reqDocRequestSubmitted),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back to dashboard
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Helpers.parseSupabaseError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadReceipt() async {
    final l10n = AppLocalizations.of(context);
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reqDocSelectReceiptImage)),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    // Get the most recent request
    await documentProvider.loadMyRequests(authProvider.userProfile!.id);
    if (!mounted) return;
    final requests = documentProvider.myRequests;

    if (requests.isEmpty) return;
    final latestRequest = requests.first;

    try {
      await documentProvider.uploadReceipt(
        requestId: latestRequest.id,
        receiptImage: _receiptImage!,
        userId: authProvider.userProfile!.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reqDocReceiptUploaded),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Helpers.parseSupabaseError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reqDocTitle),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_showPaymentSection) ...[
                // Document Type Selection
                Text(
                  l10n.reqDocSelectDocumentType,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDocumentTypeSection(),
                const SizedBox(height: 24),

                // Purpose — the only field the citizen must write for every
                // document type.
                TextFormField(
                  controller: _purposeController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.commonPurpose,
                    border: const OutlineInputBorder(),
                    hintText: l10n.reqDocPurposeHint,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.reqDocPleaseEnterPurpose;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Prefilled, collapsible details for the selected type
                _buildDetailsSection(),

                const SizedBox(height: 24),

                // AI check affordance
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: (_aiProcessing ||
                            context.watch<DocumentProvider>().isLoading)
                        ? null
                        : _runAiCheck,
                    icon: _aiProcessing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(l10n.reqDocAiCheckDetails),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAiSuggestionCard(),

                // reCAPTCHA
                if (_captchaToken == null) ...[
                  const SizedBox(height: 16),
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

                // Submit Button
                Consumer<DocumentProvider>(
                  builder: (context, docProvider, child) {
                    return ElevatedButton(
                      onPressed: docProvider.isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: docProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(l10n.reqDocSubmitRequest),
                    );
                  },
                ),
              ] else
                _buildPaymentSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTypeSection() {
    final barangayProvider = context.watch<BarangayProvider>();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.reqDocCertificatesClearances,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        for (final option in _documentTypeOptions)
          _buildDocumentTypeCard(
            option,
            feeLabel: _feeLabelFor(barangayProvider, option.type),
          ),
      ],
    );
  }

  String _feeLabelFor(BarangayProvider provider, String type) {
    final l10n = AppLocalizations.of(context);
    final fee = provider.getFeeByType(type);
    if (fee == null || fee.isFree) return l10n.reqDocFeeFree;
    return l10n.reqDocFeeLabel(fee.feeAmount.toStringAsFixed(2));
  }

  Widget _buildDocumentTypeCard(
    _DocumentTypeOption option, {
    required String feeLabel,
  }) {
    final isSelected = _selectedDocumentType == option.type;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          final previousFamily = _selectedOption?.family;
          if (_selectedDocumentType != option.type) {
            _businessStatus = 'NEW';
          }
          _selectedDocumentType = option.type;
          if (option.family != previousFamily) {
            _seedFromProfile(option.type);
          }
          _aiSuggestionApplied = false;
          _aiSuggestion = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(option.icon, size: 32, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _documentTypeDescription(option, l10n),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  /// Localized description for a document type option. Official document
  /// titles stay as-is; descriptions come from l10n.
  String _documentTypeDescription(
    _DocumentTypeOption option,
    AppLocalizations l10n,
  ) {
    switch (option.type) {
      case 'business_clearance':
        return l10n.reqDocBusinessClearanceDesc;
      case 'certification':
        return l10n.reqDocCertificationDesc;
      case 'barangay_clearance':
        return l10n.reqDocBarangayClearanceDesc;
      case 'oath_undertaking':
        return l10n.reqDocOathUndertakingDesc;
      case 'indigency':
        return l10n.reqDocIndigencyDesc;
      case 'good_moral':
        return l10n.reqDocGoodMoralDesc;
      case 'residency':
        return l10n.reqDocResidencyDesc;
      case 'cedula':
        return l10n.reqDocCedulaDesc;
      case 'barangay_id':
        return l10n.reqDocBarangayIdDesc;
      default:
        return option.description;
    }
  }

  /// The NEW/RENEW segmented button plus an `ExpansionTile` holding the
  /// prefilled fill-up form, so the citizen edits only what the profile
  /// cannot answer.
  Widget _buildDetailsSection() {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedOption;
    if (selected == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.type == 'business_clearance') ...[
          Text(
            l10n.reqDocTypeOfApplication,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'NEW', label: Text(l10n.reqDocNew)),
                ButtonSegment(value: 'RENEW', label: Text(l10n.reqDocRenewal)),
              ],
              selected: {_businessStatus},
              onSelectionChanged: (selection) {
                setState(() => _businessStatus = selection.first);
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.blue.shade700),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.blue
                        : Colors.white),
                side: WidgetStateProperty.all(
                  BorderSide(color: Colors.blue.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ExpansionTile(
          controller: _detailsController,
          title: Text(l10n.reqDocDocumentDetails(selected.title)),
          subtitle: Text(l10n.reqDocPrefilledFromProfile),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildSelectedForm(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedForm() {
    switch (_selectedOption?.family) {
      case _FormFamily.barangayId:
        return _buildBarangayIdFields();
      case _FormFamily.indigency:
        return _buildIndigencyFields();
      case _FormFamily.cedula:
        return _buildCedulaFields();
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBarangayIdFields() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _idFullNameController,
          decoration: InputDecoration(
            labelText: l10n.commonFullName,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idAddressController,
          decoration: InputDecoration(
            labelText: l10n.commonAddress,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idContactController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.commonPhoneNumber,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
      ],
    );
  }

  Widget _buildIndigencyFields() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _indigencyFullNameController,
          decoration: InputDecoration(
            labelText: l10n.commonFullName,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _indigencyAddressController,
          decoration: InputDecoration(
            labelText: l10n.commonAddress,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _indigencyAgeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.commonAge,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _indigencyCivilStatusController,
                decoration: InputDecoration(
                  labelText: l10n.commonCivilStatus,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _indigencyRequesterController,
          decoration: InputDecoration(
            labelText: l10n.reqDocRequester,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _indigencyRequesterAddressController,
          decoration: InputDecoration(
            labelText: l10n.reqDocRequesterAddress,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildCedulaFields() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cedulaLastNameController,
                decoration: InputDecoration(
                  labelText: l10n.reqDocLastName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? l10n.commonRequired : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cedulaFirstNameController,
                decoration: InputDecoration(
                  labelText: l10n.reqDocFirstName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? l10n.commonRequired : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaMiddleNameController,
          decoration: InputDecoration(
            labelText: l10n.reqDocMiddleName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaAddressController,
          decoration: InputDecoration(
            labelText: l10n.commonAddress,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _cedulaGender,
                decoration: InputDecoration(
                  labelText: l10n.commonGender,
                  border: const OutlineInputBorder(),
                ),
                items: _genders
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g == 'Male' ? l10n.commonMale : l10n.commonFemale,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _cedulaGender = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _cedulaCivilStatus,
                decoration: InputDecoration(
                  labelText: l10n.commonCivilStatus,
                  border: const OutlineInputBorder(),
                ),
                items: _civilStatuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s == 'Single'
                                ? l10n.commonSingle
                                : s == 'Married'
                                    ? l10n.commonMarried
                                    : s == 'Widowed'
                                        ? l10n.commonWidowed
                                        : l10n.commonDivorced,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _cedulaCivilStatus = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaBirthPlaceController,
          decoration: InputDecoration(
            labelText: l10n.commonPlaceOfBirth,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? l10n.commonRequired : null,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _cedulaBirthDate ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _cedulaBirthDate = date;
              });
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.commonDateOfBirth,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _cedulaBirthDate == null
                  ? l10n.reqDocSelectBirthDate
                  : '${_cedulaBirthDate!.day}/${_cedulaBirthDate!.month}/${_cedulaBirthDate!.year}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cedulaHeightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.reqDocHeight,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cedulaWeightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.reqDocWeight,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaTinController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'TIN',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaOccupationController,
          decoration: InputDecoration(
            labelText: l10n.reqDocOccupation,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaAnnualIncomeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.reqDocAnnualIncome,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaCitizenshipController,
          decoration: InputDecoration(
            labelText: l10n.reqDocCitizenship,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final barangayProvider = context.watch<BarangayProvider>();
    final config = barangayProvider.config;
    final fee = barangayProvider.getFeeByType(_selectedDocumentType!);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          l10n.reqDocRequestCreatedSuccess,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reqDocPaymentInstructions,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.reqDocSendPaymentGcash,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (config != null) ...[
                  Text(
                    l10n.reqDocPaymentName(config.gcashName),
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    l10n.reqDocPaymentNumber(config.gcashNumber),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 8),
                if (fee != null && !fee.isFree)
                  Text(
                    l10n.reqDocPaymentAmount(fee.feeAmount.toStringAsFixed(2)),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  l10n.reqDocScreenshotGcashReceipt,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.reqDocUploadReceiptBelow,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.reqDocUploadGcashReceipt,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickReceipt,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _receiptImage == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(l10n.reqDocTapToUploadReceipt),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_receiptImage!, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Consumer<DocumentProvider>(
          builder: (context, docProvider, child) {
            return ElevatedButton(
              onPressed: docProvider.isLoading ? null : _uploadReceipt,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: docProvider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.reqDocSubmitPaymentReceipt),
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.reqDocCancelRequest),
                content: Text(l10n.reqDocCancelRequestConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.commonNo),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text(l10n.reqDocYesCancel),
                  ),
                ],
              ),
            );

            if (confirm == true && mounted) {
              final authProvider = context.read<AuthProvider>();
              final documentProvider = context.read<DocumentProvider>();

              // Get the latest request to delete
              await documentProvider.loadMyRequests(
                authProvider.userProfile!.id,
              );
              final requests = documentProvider.myRequests;

              if (requests.isNotEmpty) {
                final latestRequest = requests.first;

                try {
                  await documentProvider.cancelRequest(
                    requestId: latestRequest.id,
                    userId: authProvider.userProfile!.id,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.reqDocRequestCancelled),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(Helpers.parseSupabaseError(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.red),
          ),
          child: Text(
            l10n.reqDocCancelRequest,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
