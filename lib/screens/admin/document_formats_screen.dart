import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/services/pdf_service.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:open_filex/open_filex.dart';

class DocumentFormatsScreen extends StatefulWidget {
  const DocumentFormatsScreen({super.key});

  @override
  State<DocumentFormatsScreen> createState() => _DocumentFormatsScreenState();
}

class _DocumentFormatsScreenState extends State<DocumentFormatsScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document Formats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Preview and manage document templates',
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
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preview Document Templates',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Generate sample PDFs to preview how documents will look when issued to citizens.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Available Document Formats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Document Format Cards
                  _buildFormatCard(
                    title: 'Barangay Clearance',
                    description:
                        'Certificate of residence and good moral character',
                    icon: Icons.description,
                    color: Colors.blue,
                    onPreview: () => _generatePreview('barangay_clearance'),
                  ),
                  _buildFormatCard(
                    title: 'Certificate of Indigency',
                    description: 'Certificate for low-income families',
                    icon: Icons.volunteer_activism,
                    color: Colors.green,
                    onPreview: () => _generatePreview('indigency'),
                  ),
                  _buildFormatCard(
                    title: 'Community Tax Certificate (Cedula)',
                    description: 'Annual community tax certificate',
                    icon: Icons.receipt_long,
                    color: Colors.orange,
                    onPreview: () => _generatePreview('cedula'),
                  ),
                  _buildFormatCard(
                    title: 'Barangay ID Card',
                    description:
                        'Official barangay identification card (Front & Back)',
                    icon: Icons.badge,
                    color: Colors.purple,
                    onPreview: () => _generatePreview('barangay_id'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPreview,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isGenerating ? null : onPreview,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Preview Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.preview, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePreview(String documentType) async {
    // Check if running on web
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PDF preview is not available on web. Please use mobile or desktop app.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final barangayProvider = context.read<BarangayProvider>();
      await barangayProvider.loadConfig();
      final config = barangayProvider.config;

      if (config == null) {
        throw Exception('Barangay configuration not found');
      }

      // Create sample data
      final now = DateTime.now();
      final sampleRequest = DocumentRequest(
        id: 'SAMPLE-${now.millisecondsSinceEpoch}',
        userId: 'sample-user-id',
        documentType: documentType,
        purpose: 'Sample purpose for preview',
        documentData: {
          'citizenship': 'Filipino',
          'profession_occupation': 'Software Developer',
          'height_cm': 170.0,
          'weight_kg': 65.0,
          'tin_number': '123-456-789-000',
          'community_tax_due': 5.00,
        },
        requestStatus: 'approved',
        paymentAmount: 50.0,
        paymentStatus: 'verified',
        requestedAt: now,
      );

      File? pdfFile;

      switch (documentType) {
        case 'barangay_clearance':
          pdfFile = await PdfService.generateBarangayClearance(
            request: sampleRequest,
            config: config,
            userFullName: 'Juan Dela Cruz',
            userAddress: '123 Sample Street, Purok 1',
            userAge: 30,
            civilStatus: 'Single',
          );
          break;

        case 'indigency':
          pdfFile = await PdfService.generateIndigencyCertificate(
            request: sampleRequest,
            config: config,
            userFullName: 'Maria Santos',
            userAddress: '456 Example Road, Purok 2',
            userAge: 28,
            civilStatus: 'Married',
          );
          break;

        case 'cedula':
          pdfFile = await PdfService.generateCedula(
            request: sampleRequest,
            config: config,
            userFullName: 'Pedro Reyes',
            userAddress: '789 Demo Avenue, Purok 3',
            userAge: 35,
            civilStatus: 'Single',
            dateOfBirth: 'January 15, 1990',
            placeOfBirth: 'Manila, Philippines',
            gender: 'Male',
          );
          break;

        case 'barangay_id':
          pdfFile = await PdfService.generateBarangayId(
            userId: 'sample-user-id',
            fullName: 'Ana Garcia',
            address: '321 Test Lane, Purok 4',
            dateOfBirth: 'March 20, 1995',
            contactNumber: '09123456789',
            emergencyContactName: 'Jose Garcia',
            emergencyContactNumber: '09987654321',
            bloodType: 'O+',
            config: config,
          );
          break;
      }

      if (pdfFile != null && mounted) {
        // Open the PDF
        await OpenFilex.open(pdfFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preview generated: ${pdfFile.path.split('/').last}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error generating preview: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
