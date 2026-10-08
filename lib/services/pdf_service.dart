import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/models/barangay_config.dart';

class PdfService {
  static pw.ThemeData? _unicodeTheme;

  /// Loads a Unicode-capable theme (bundled Roboto) so document text
  /// outside WinAnsi (e.g. ₱, ñ, é) renders instead of throwing
  /// "Unable to find a font to draw …". Cached after first load.
  static Future<pw.ThemeData> _loadUnicodeTheme() async {
    if (_unicodeTheme != null) return _unicodeTheme!;
    final base = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-bold.ttf'),
    );
    return _unicodeTheme = pw.ThemeData.withFont(base: base, bold: bold);
  }
  /// Generate Barangay Clearance PDF
  static Future<File> generateBarangayClearance({
    required DocumentRequest request,
    required BarangayConfig config,
    required String userFullName,
    required String userAddress,
    required int userAge,
    required String civilStatus,
    String? profilePhotoUrl,
    bool isDraft = false,
    String? approverName,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) async {
    final pdf = pw.Document(theme: await _loadUnicodeTheme());

    // Load profile photo if available
    pw.ImageProvider? photoImage;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profilePhotoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error loading profile photo: $e');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.legal,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with photo
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildHeader(config)),
                  if (photoImage != null)
                    pw.Container(
                      width: 80,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blue900,
                          width: 2,
                        ),
                      ),
                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                    ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BARANGAY CLEARANCE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 250,
                      height: 3,
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue900, PdfColors.blue600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // TO WHOM IT MAY CONCERN
              pw.Text(
                'TO WHOM IT MAY CONCERN:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 20),

              // Body
              pw.Paragraph(
                text:
                    '          This is to certify that $userFullName, $userAge years old, $civilStatus, Filipino citizen, and a bonafide resident of $userAddress, ${config.barangayName}, is known to me to be of good moral character and a law-abiding citizen.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              pw.Paragraph(
                text:
                    '          This certification is being issued upon the request of the above-named person for ${request.purpose}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              pw.Paragraph(
                text:
                    '          Issued this ${_formatDate(DateTime.now())} at ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 40),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        userFullName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Applicant Signature',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        config.barangayCaptain ?? 'BARANGAY CAPTAIN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Barangay Captain',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'barangay_clearance_${request.id}.pdf');
  }

  /// Generate Indigency Certificate PDF
  static Future<File> generateIndigencyCertificate({
    required DocumentRequest request,
    required BarangayConfig config,
    required String userFullName,
    required String userAddress,
    required int userAge,
    required String civilStatus,
    String? profilePhotoUrl,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) async {
    final pdf = pw.Document(theme: await _loadUnicodeTheme());

    // Load profile photo if available
    pw.ImageProvider? photoImage;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profilePhotoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error loading profile photo: $e');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.legal,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with photo
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildHeader(config)),
                  if (photoImage != null)
                    pw.Container(
                      width: 80,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blue900,
                          width: 2,
                        ),
                      ),
                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                    ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CERTIFICATE OF INDIGENCY',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 280,
                      height: 3,
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue900, PdfColors.blue600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // TO WHOM IT MAY CONCERN
              pw.Text(
                'TO WHOM IT MAY CONCERN:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 20),

              // Body
              pw.Paragraph(
                text:
                    '          This is to certify that $userFullName, $userAge years old, $civilStatus, Filipino citizen, and a bonafide resident of $userAddress, ${config.barangayName}, is among the indigent families in our barangay.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              pw.Paragraph(
                text:
                    '          This certification further states that the above-named person belongs to a low-income family and is in need of financial assistance.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              pw.Paragraph(
                text:
                    '          This certification is being issued upon the request of the above-named person for ${request.purpose}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              pw.Paragraph(
                text:
                    '          Issued this ${_formatDate(DateTime.now())} at ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 40),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        userFullName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Applicant Signature',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        config.barangayCaptain ?? 'BARANGAY CAPTAIN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Barangay Captain',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'indigency_certificate_${request.id}.pdf');
  }

  /// Generate Cedula PDF
  static Future<File> generateCedula({
    required DocumentRequest request,
    required BarangayConfig config,
    required String userFullName,
    required String userAddress,
    required int userAge,
    required String civilStatus,
    required String dateOfBirth,
    required String placeOfBirth,
    required String gender,
    String? profilePhotoUrl,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) async {
    final pdf = pw.Document(theme: await _loadUnicodeTheme());
    final data = request.documentData;

    // Load profile photo if available
    pw.ImageProvider? photoImage;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profilePhotoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error loading profile photo: $e');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.legal,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with photo
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildHeader(config)),
                  if (photoImage != null)
                    pw.Container(
                      width: 80,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blue900,
                          width: 2,
                        ),
                      ),
                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                    ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'COMMUNITY TAX CERTIFICATE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      '(CEDULA)',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 320,
                      height: 3,
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue900, PdfColors.blue600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Certificate Number
              pw.Text(
                'Certificate No.: CTC-${request.id.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // Personal Information
              _buildInfoRow('Full Name:', userFullName),
              _buildInfoRow('Address:', '$userAddress, ${config.barangayName}'),
              _buildInfoRow('Date of Birth:', dateOfBirth),
              _buildInfoRow('Place of Birth:', placeOfBirth),
              _buildInfoRow('Age:', '$userAge years old'),
              _buildInfoRow('Gender:', gender),
              _buildInfoRow('Civil Status:', civilStatus),
              _buildInfoRow(
                'Citizenship:',
                data['citizenship']?.toString() ?? 'Filipino',
              ),
              _buildInfoRow(
                'Profession/Occupation:',
                data['profession_occupation']?.toString() ?? 'N/A',
              ),
              _buildInfoRow(
                'Height:',
                data['height_cm'] != null ? '${data['height_cm']} cm' : 'N/A',
              ),
              _buildInfoRow(
                'Weight:',
                data['weight_kg'] != null ? '${data['weight_kg']} kg' : 'N/A',
              ),
              _buildInfoRow(
                'TIN Number:',
                data['tin_number']?.toString() ?? 'N/A',
              ),
              pw.SizedBox(height: 20),

              // Tax Information
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TAX ASSESSMENT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildInfoRow(
                      'Community Tax Due:',
                      'PHP ${data['community_tax_due'] ?? '5.00'}',
                    ),
                    _buildInfoRow('Date Issued:', _formatDate(DateTime.now())),
                    _buildInfoRow(
                      'Valid Until:',
                      _formatDate(
                        DateTime.now().add(const Duration(days: 365)),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        config.barangayCaptain ?? 'BARANGAY CAPTAIN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Issuing Officer',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'cedula_${request.id}.pdf');
  }

  /// Generate Barangay ID Card (Front and Back)
  static Future<File> generateBarangayId({
    required String userId,
    required String fullName,
    required String address,
    required String dateOfBirth,
    required String contactNumber,
    required String emergencyContactName,
    required String emergencyContactNumber,
    required String bloodType,
    required BarangayConfig config,
    String? profilePhotoUrl,
    String? documentId,
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) async {
    final pdf = pw.Document(theme: await _loadUnicodeTheme());

    // Load profile photo if available
    pw.ImageProvider? photoImage;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profilePhotoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error loading profile photo: $e');
      }
    }

    // Front of ID
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          3.375 * PdfPageFormat.inch,
          2.125 * PdfPageFormat.inch,
        ),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColors.blue900, PdfColors.blue600],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              border: pw.Border.all(color: PdfColors.yellow, width: 3),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'REPUBLIC OF THE PHILIPPINES',
                          style: pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.Text(
                          config.barangayName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.yellow,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.Container(
                          width: 80,
                          height: 0.5,
                          color: PdfColors.yellow,
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'BARANGAY IDENTIFICATION CARD',
                          style: pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Photo and info
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Photo
                      pw.Container(
                        width: 55,
                        height: 65,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(
                            color: PdfColors.yellow,
                            width: 2,
                          ),
                        ),
                        child: photoImage != null
                            ? pw.Image(photoImage, fit: pw.BoxFit.cover)
                            : pw.Center(
                                child: pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Icon(
                                      const pw.IconData(0xe7fd),
                                      size: 24,
                                      color: PdfColors.grey400,
                                    ),
                                    pw.Text(
                                      '2x2',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      pw.SizedBox(width: 8),

                      // Information
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              fullName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.yellow,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            pw.Container(
                              height: 0.5,
                              width: 120,
                              color: PdfColors.yellow,
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              address,
                              style: const pw.TextStyle(
                                fontSize: 5.5,
                                color: PdfColors.white,
                              ),
                              maxLines: 2,
                            ),
                            pw.SizedBox(height: 4),
                            _buildIdInfoRow('DOB:', dateOfBirth),
                            _buildIdInfoRow('Contact:', contactNumber),
                            pw.Container(
                              margin: const pw.EdgeInsets.only(top: 2),
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.red700,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                'BLOOD TYPE: ${bloodType.toUpperCase()}',
                                style: pw.TextStyle(
                                  fontSize: 5.5,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),

                  // ID Number and QR placeholder
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Text(
                          documentId != null && documentId.isNotEmpty
                              ? 'ID: ${documentId.length > 10 ? documentId.substring(0, 10).toUpperCase() : documentId.toUpperCase()}'
                              : 'ID: ${userId.substring(0, 10).toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.blue900,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 30,
                        height: 30,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.yellow),
                        ),
                        child: qrUrl != null && qrUrl.isNotEmpty
                            ? pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: qrUrl,
                                drawText: false,
                              )
                            : pw.Center(
                                child: pw.Text(
                                  'QR',
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.grey,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (copyNotice != null && copyNotice.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      copyNotice,
                      style: const pw.TextStyle(
                        fontSize: 5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    // Back of ID
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          3.375 * PdfPageFormat.inch,
          2.125 * PdfPageFormat.inch,
        ),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.blue900, width: 3),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    decoration: const pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [PdfColors.blue900, PdfColors.blue600],
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'IN CASE OF EMERGENCY',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),

                  // Emergency Contact
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CONTACT PERSON:',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          emergencyContactName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Tel: $emergencyContactNumber',
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Barangay Info
                  pw.Text(
                    'IF FOUND, PLEASE RETURN TO:',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    config.barangayName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    config.barangayAddress,
                    style: const pw.TextStyle(fontSize: 5.5),
                  ),
                  pw.Text(
                    'Tel: ${config.contactNumber ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 5.5),
                  ),
                  pw.Spacer(),

                  // Important Notes
                  pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.red, width: 1),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '⚠ NON-TRANSFERABLE',
                          style: pw.TextStyle(
                            fontSize: 5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                        ),
                        pw.Text(
                          'Valid for ONE (1) year from issue date',
                          style: const pw.TextStyle(fontSize: 5),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 4),

                  // Signature section
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 60,
                            height: 0.5,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Holder Signature',
                            style: const pw.TextStyle(fontSize: 4.5),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            config.barangayCaptain ?? 'Barangay Captain',
                            style: pw.TextStyle(
                              fontSize: 5.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Container(
                            width: 70,
                            height: 0.5,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Barangay Captain',
                            style: const pw.TextStyle(fontSize: 4.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return _savePdf(pdf, 'barangay_id_$userId.pdf');
  }

  // Helper Methods
  static pw.Widget _buildHeader(BarangayConfig config) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'REPUBLIC OF THE PHILIPPINES',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Province/City', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            config.barangayName.toUpperCase(),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'OFFICE OF THE BARANGAY CAPTAIN',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            config.barangayAddress,
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (config.contactNumber != null)
            pw.Text(
              'Tel: ${config.contactNumber}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          if (config.email != null)
            pw.Text(
              'Email: ${config.email}',
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
    BarangayConfig config,
    String documentId, {
    String? qrUrl,
    String? expiresAtLabel,
    String? copyNotice,
  }) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Document ID: ${documentId.length > 10 ? documentId.substring(0, 10).toUpperCase() : documentId.toUpperCase()}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                if (expiresAtLabel != null && expiresAtLabel.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Valid until: $expiresAtLabel',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                pw.SizedBox(height: 2),
                pw.Text(
                  'Not valid without official seal',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                if (copyNotice != null && copyNotice.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    copyNotice,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
            if (qrUrl != null && qrUrl.isNotEmpty)
              pw.Container(
                width: 60,
                height: 60,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrUrl,
                  drawText: false,
                ),
              )
            else
              pw.Text(
                'Scan QR after release',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIdInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 5.5,
              color: PdfColors.yellow,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 2),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  static Future<File> _savePdf(pw.Document pdf, String filename) async {
    final output = Directory.systemTemp;
    final file = File('${output.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Draft / Signature helpers ────────────────────────────────────────

  static pw.Widget buildDraftBanner() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.red, width: 2),
        color: PdfColors.red50,
      ),
      child: pw.Center(
        child: pw.Text(
          'DRAFT — NOT VALID FOR OFFICIAL USE',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red,
          ),
        ),
      ),
    );
  }

  static pw.Widget buildSignatureBlock({
    required String approverName,
    required String approverTitle,
    DateTime? signedAt,
  }) {
    final dateStr = signedAt != null
        ? DateFormat('MMMM dd, yyyy – hh:mm a').format(signedAt)
        : _formatDate(DateTime.now());
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 30),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'DIGITALLY SIGNED',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  approverName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  approverTitle,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  dateStr,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
