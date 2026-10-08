import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/services/ai_document_processor.dart';

class RequestDocumentScreen extends StatefulWidget {
  const RequestDocumentScreen({super.key});

  @override
  State<RequestDocumentScreen> createState() => _RequestDocumentScreenState();
}

class _RequestDocumentScreenState extends State<RequestDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  // Document-specific form controllers
  final _idFullNameController = TextEditingController();
  final _idAddressController = TextEditingController();
  final _idContactController = TextEditingController();

  final _indigencyFullNameController = TextEditingController();
  final _indigencyPurposeController = TextEditingController();

  final _cedulaFirstNameController = TextEditingController();
  final _cedulaMiddleNameController = TextEditingController();
  final _cedulaLastNameController = TextEditingController();
  final _cedulaAddressController = TextEditingController();
  final _cedulaPlaceOfBirthController = TextEditingController();
  final _cedulaHeightController = TextEditingController();
  final _cedulaWeightController = TextEditingController();
  DateTime? _cedulaBirthDate;
  String _cedulaGender = 'Male';
  String _cedulaCivilStatus = 'Single';
  String _cedulaCitizenship = 'Filipino';

  String? _selectedDocumentType;
  final bool _showPaymentSection = false;
  File? _receiptImage;
  final _imagePicker = ImagePicker();

  DocumentProcessingSuggestion? _aiSuggestion;
  bool _aiProcessing = false;
  bool _aiSuggestionApplied = false;
  final _aiProcessor = AiDocumentProcessor();

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
    _purposeController.dispose();
    _idFullNameController.dispose();
    _idAddressController.dispose();
    _idContactController.dispose();
    _indigencyFullNameController.dispose();
    _indigencyPurposeController.dispose();
    _cedulaFirstNameController.dispose();
    _cedulaMiddleNameController.dispose();
    _cedulaLastNameController.dispose();
    _cedulaAddressController.dispose();
    _cedulaPlaceOfBirthController.dispose();
    _cedulaHeightController.dispose();
    _cedulaWeightController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getDocumentData() {
    switch (_selectedDocumentType) {
      case 'barangay_id':
        return {
          'full_name': _idFullNameController.text.trim(),
          'address': _idAddressController.text.trim(),
          'contact_number': _idContactController.text.trim(),
        };
      case 'indigency':
        return {
          'full_name': _indigencyFullNameController.text.trim(),
          'purpose': _indigencyPurposeController.text.trim(),
        };
      case 'cedula':
        return {
          'first_name': _cedulaFirstNameController.text.trim(),
          'middle_name': _cedulaMiddleNameController.text.trim(),
          'last_name': _cedulaLastNameController.text.trim(),
          'address': _cedulaAddressController.text.trim(),
          'birth_date': _cedulaBirthDate?.toIso8601String(),
          'birth_place': _cedulaPlaceOfBirthController.text.trim(),
          'gender': _cedulaGender,
          'civil_status': _cedulaCivilStatus,
          'citizenship': _cedulaCitizenship,
          'height': _cedulaHeightController.text.trim(),
          'weight': _cedulaWeightController.text.trim(),
        };
      default:
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick receipt image')),
        );
      }
    }
  }

  TextEditingController? _controllerForSuggestionField(String field) {
    switch (field) {
      case 'purpose':
        return _selectedDocumentType == 'indigency'
            ? _indigencyPurposeController
            : _purposeController;
      case 'full_name':
        if (_selectedDocumentType == 'barangay_id') {
          return _idFullNameController;
        }
        if (_selectedDocumentType == 'indigency') {
          return _indigencyFullNameController;
        }
        return null;
      case 'address':
        if (_selectedDocumentType == 'barangay_id') {
          return _idAddressController;
        }
        if (_selectedDocumentType == 'cedula') {
          return _cedulaAddressController;
        }
        return null;
      case 'contact_number':
        return _idContactController;
      case 'first_name':
        return _cedulaFirstNameController;
      case 'middle_name':
        return _cedulaMiddleNameController;
      case 'last_name':
        return _cedulaLastNameController;
      case 'birth_place':
        return _cedulaPlaceOfBirthController;
      case 'height':
        return _cedulaHeightController;
      case 'weight':
        return _cedulaWeightController;
      default:
        return null;
    }
  }

  Future<void> _runAiCheck() async {
    if (_aiProcessing) return;
    if (_selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a document type first')),
      );
      return;
    }
    final purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a purpose first')),
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
          const SnackBar(content: Text('AI check unavailable')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Suggestions applied — review the fields and submit'),
      ),
    );
  }

  Widget _buildAiSuggestionCard() {
    final suggestion = _aiSuggestion;
    if (!_aiSuggestionApplied || suggestion == null) {
      return const SizedBox.shrink();
    }
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
              const Text('Details verified — submitting as entered')
            else ...[
              const Text(
                'Issues found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                const Text(
                  'AI suggestions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...suggestion.suggestions.entries.map(
                  (entry) => Text('${entry.key}: ${entry.value}'),
                ),
              ],
              if (suggestion.normalizedPurpose.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Normalized purpose: ${suggestion.normalizedPurpose}'),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _applyAiSuggestions,
                  child: const Text('Apply suggestions'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document type')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();
    final barangayProvider = context.read<BarangayProvider>();

    // Get fee amount
    final fee = barangayProvider.getFeeByType(_selectedDocumentType!);
    if (fee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee information not found')),
      );
      return;
    }

    try {
      await documentProvider.createRequest(
        userId: authProvider.userProfile!.id,
        documentType: _selectedDocumentType!,
        purpose: _purposeController.text.trim(),
        documentData: _getDocumentData(),
        paymentAmount: fee.feeAmount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request submitted! Please wait for admin verification.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to dashboard
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadReceipt() async {
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select receipt image')),
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
        const SnackBar(
          content: Text('Receipt uploaded! Waiting for admin verification.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Document'),
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
                const Text(
                  'Select Document Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDocumentTypeCard(
                  'barangay_id',
                  'Barangay ID',
                  Icons.badge,
                  'Official barangay identification',
                ),
                _buildDocumentTypeCard(
                  'indigency',
                  'Certificate of Indigency',
                  Icons.description,
                  'For financial assistance purposes',
                ),
                _buildDocumentTypeCard(
                  'cedula',
                  'Cedula',
                  Icons.document_scanner,
                  'Community tax certificate',
                ),
                const SizedBox(height: 24),

                // Purpose
                TextFormField(
                  controller: _purposeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Purpose',
                    border: OutlineInputBorder(),
                    hintText: 'Briefly describe the purpose of this request',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the purpose';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Document-specific fields
                if (_selectedDocumentType == 'barangay_id')
                  _buildBarangayIdFields(),
                if (_selectedDocumentType == 'indigency')
                  _buildIndigencyFields(),
                if (_selectedDocumentType == 'cedula') _buildCedulaFields(),

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
                    label: const Text('AI check details'),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAiSuggestionCard(),

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
                          : const Text('Submit Request'),
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

  Widget _buildDocumentTypeCard(
    String type,
    String title,
    IconData icon,
    String description,
  ) {
    final isSelected = _selectedDocumentType == type;
    final barangayProvider = context.watch<BarangayProvider>();
    final fee = barangayProvider.getFeeByType(type);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDocumentType = type;
          _aiSuggestionApplied = false;
          _aiSuggestion = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
            Icon(icon, size: 40, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (fee != null)
                    Text(
                      'Fee: ₱${fee.feeAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
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

  Widget _buildBarangayIdFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Barangay ID Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idFullNameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idAddressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idContactController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Number',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildIndigencyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Indigency Certificate Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _indigencyFullNameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _indigencyPurposeController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Specific Purpose',
            border: OutlineInputBorder(),
            hintText: 'e.g., Medical assistance, Educational support',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildCedulaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cedula Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaFirstNameController,
          decoration: const InputDecoration(
            labelText: 'First Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaMiddleNameController,
          decoration: const InputDecoration(
            labelText: 'Middle Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaLastNameController,
          decoration: const InputDecoration(
            labelText: 'Last Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _cedulaBirthDate == null
                ? 'Select Birth Date'
                : 'Birth Date: ${_cedulaBirthDate!.day}/${_cedulaBirthDate!.month}/${_cedulaBirthDate!.year}',
          ),
          leading: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _cedulaBirthDate = date;
              });
            }
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaPlaceOfBirthController,
          decoration: const InputDecoration(
            labelText: 'Place of Birth',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cedulaAddressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _cedulaGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: ['Male', 'Female']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _cedulaGender = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _cedulaCivilStatus,
                decoration: const InputDecoration(
                  labelText: 'Civil Status',
                  border: OutlineInputBorder(),
                ),
                items: ['Single', 'Married', 'Widowed', 'Divorced']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _cedulaCivilStatus = value!;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _cedulaCitizenship,
          decoration: const InputDecoration(
            labelText: 'Citizenship',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _cedulaCitizenship = value;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cedulaHeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cedulaWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final barangayProvider = context.watch<BarangayProvider>();
    final config = barangayProvider.config;
    final fee = barangayProvider.getFeeByType(_selectedDocumentType!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Request Created Successfully!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '1. Send payment via GCash to:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (config != null) ...[
                  Text(
                    '   Name: ${config.gcashName}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '   Number: ${config.gcashNumber}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 8),
                if (fee != null)
                  Text(
                    '   Amount: ₱${fee.feeAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '2. Take a screenshot of the GCash receipt',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  '3. Upload the receipt below',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Upload GCash Receipt',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tap to upload receipt'),
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
                  : const Text('Submit Payment Receipt'),
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Request'),
                content: const Text(
                  'Are you sure you want to cancel this request? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Yes, Cancel'),
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
                      const SnackBar(
                        content: Text('Request cancelled successfully'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
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
          child: const Text(
            'Cancel Request',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
