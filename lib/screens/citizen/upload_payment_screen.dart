import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/utils/helpers.dart';

class UploadPaymentScreen extends StatefulWidget {
  final DocumentRequest request;

  const UploadPaymentScreen({super.key, required this.request});

  @override
  State<UploadPaymentScreen> createState() => _UploadPaymentScreenState();
}

class _UploadPaymentScreenState extends State<UploadPaymentScreen> {
  File? _receiptImage;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarangayProvider>().loadConfig();
    });
  }

  Future<void> _pickReceipt() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
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

    try {
      await documentProvider.uploadReceipt(
        requestId: widget.request.id,
        receiptImage: _receiptImage!,
        userId: authProvider.userProfile!.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt uploaded! Waiting for admin verification.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Add small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final barangayProvider = context.watch<BarangayProvider>();
    final config = barangayProvider.config;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2E7D32),
                  Color(0xFF388E3C),
                  Color(0xFF66BB6A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.payment_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Payment Receipt',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Complete your document request',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Amount badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.request.documentTypeDisplay}  ·  ₱${widget.request.paymentAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // GCash info card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Color(0xFF1976D2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Payment Instructions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _step('1', 'Send payment via GCash to:'),
                          const SizedBox(height: 10),
                          if (barangayProvider.isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (config != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        config.gcashName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.phone_android,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        config.gcashNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: 1.5,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              'Loading GCash details...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on_outlined,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Amount: ₱${widget.request.paymentAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _step('2', 'Screenshot your GCash confirmation'),
                          const SizedBox(height: 6),
                          _step('3', 'Upload the screenshot below'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Receipt picker
                  const Text(
                    'GCash Receipt Screenshot',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickReceipt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 200,
                      decoration: BoxDecoration(
                        color: _receiptImage == null ? Colors.white : null,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _receiptImage == null
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: _receiptImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.upload_outlined,
                                    size: 36,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tap to select screenshot',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'JPG, PNG accepted',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _receiptImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _pickReceipt,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Change',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit + Cancel
                  Consumer<DocumentProvider>(
                    builder: (context, docProvider, _) => Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: docProvider.isLoading
                                ? null
                                : _uploadReceipt,
                            icon: docProvider.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 20,
                                  ),
                            label: Text(
                              docProvider.isLoading
                                  ? 'Uploading...'
                                  : 'Submit Payment Receipt',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
