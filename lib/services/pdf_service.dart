import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/models/barangay_config.dart';
import 'package:guin_app/utils/helpers.dart';

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
    final now = Helpers.now();
    final month = DateFormat('MMMM').format(now);
    final year2 = now.year.toString().substring(2);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.only(
          left: 60,
          right: 60,
          top: 55,
          bottom: 50,
        ),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Faded circular seal/watermark centered behind text
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.SizedBox(width: 320, height: 320),
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header: logo left, address block right
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 70 + 16, height: 70),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'Republic of the Philippines',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Province of Palawan',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Municipality of Narra',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Barangay Poblacion',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'OFFICE OF THE PUNONG BARANGAY',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(
                    thickness: 2,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(
                    thickness: 0.5,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 16),

                  // Title
                  pw.Center(
                    child: pw.Text(
                      'CERTIFICATE OF INDIGENCY',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 18),

                  // Salutation
                  pw.Text(
                    'TO WHOM IT MAY CONCERN;',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Body
                  pw.Paragraph(
                    text:
                        'This is to certify that ___________, ${userAge >= 0 ? userAge : '___'} years old, _____, Filipino Citizen is a bonafide resident of ___________, Barangay Poblacion, Narra, Palawan.',
                    style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                    textAlign: pw.TextAlign.justify,
                  ),
                  pw.SizedBox(height: 14),
                  pw.Paragraph(
                    text:
                        'This certifies further that he/she belongs to INDIGENT FAMILIES of this Barangay.',
                    style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                    textAlign: pw.TextAlign.justify,
                  ),
                  pw.SizedBox(height: 14),
                  pw.Paragraph(
                    text:
                        'This certification is being issued upon request of _______________________, for __________ purpose that may legally serve his/her best.',
                    style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                    textAlign: pw.TextAlign.justify,
                  ),
                  pw.SizedBox(height: 14),
                  pw.Paragraph(
                    text:
                        'Issued this ______ day of $month, 20$year2 at Barangay Hall, Poblacion, Narra, Palawan.',
                    style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                    textAlign: pw.TextAlign.justify,
                  ),
                  pw.Spacer(),

                  // Signature block
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      width: 230,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            (config.barangayCaptain ?? 'NENITA R. NACARIO')
                                .toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Punong Barangay',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Footer note
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Note: This certificate valid without the barangay seal.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
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

  /// Generate Barangay Business Clearance PDF
  /// (NEW establishment variant by default; RENEW variant when
  /// `documentData['business_status']` is 'RENEW').
  static Future<File> generateBusinessClearance({
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
    final data = request.documentData;
    final isRenew =
        data['business_status']?.toString().toUpperCase() == 'RENEW';

    // Load profile photo if available
    pw.ImageProvider? photoImage;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profilePhotoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        // Photo load failures must never block PDF generation.
      }
    }

    final businessName = data['business_name']?.toString().isNotEmpty == true
        ? data['business_name'].toString()
        : (data['occupation']?.toString().isNotEmpty == true
            ? data['occupation'].toString()
            : '____________________');
    final location = data['business_location']?.toString().isNotEmpty == true
        ? data['business_location'].toString()
        : (data['address']?.toString().isNotEmpty == true
            ? data['address'].toString()
            : userAddress);
    final operatorName = data['operator_name']?.toString().isNotEmpty == true
        ? data['operator_name'].toString()
        : userFullName;
    final businessAddress =
        data['business_address']?.toString().isNotEmpty == true
            ? data['business_address'].toString()
            : userAddress;

    final businessFields = <(String, String)>[
      (businessName, '(Business Name or Trade Activity)'),
      (location, '(Location)'),
      (operatorName, '(Operator/Manager)'),
      (businessAddress, '(Address)'),
    ];

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
              pw.SizedBox(height: 16),

              // Date (top-right, underlined)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Date: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),

              // Title (two stacked bold centered lines)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BARANGAY/BUSINESS CLEARANCE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'YEAR ${Helpers.now().year}',
                      style: pw.TextStyle(
                        fontSize: 20,
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
              pw.SizedBox(height: 22),

              // Salutation
              pw.Text(
                'TO WHOM IT MAY CONCERN;',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 16),

              // Intro
              pw.Paragraph(
                text:
                    'This is to certify that the business or trade activity described below:',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 14),

              // Centered field stack (bold underlined value + italic caption)
              pw.Column(
                children: [
                  for (final (value, caption) in businessFields) ...[
                    pw.Center(
                      child: pw.Text(
                        value,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        caption,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],
                ],
              ),
              pw.SizedBox(height: 6),

              // Variant clauses
              if (!isRenew) ...[
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 1.5,
                    ),
                    children: [
                      const pw.TextSpan(text: 'Proposed to be '),
                      pw.TextSpan(
                        text: 'NEW',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      const pw.TextSpan(
                        text:
                            ' established in this Barangay and is being applied for a Barangay Clearance to be used in securing a corresponding Legal Permits has been found to be:',
                      ),
                    ],
                  ),
                  textAlign: pw.TextAlign.justify,
                  overflow: pw.TextOverflow.span,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      '√  In conformity with the provisions of existing Ordinances, rules and Regulations being enforced in this Barangay;',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 4),
                pw.Paragraph(
                  text:
                      '[  ]  not among those businesses or trade activities banned to be established in this Barangay.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text: 'In view of the foregoing, this Barangay thru the undersigned.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      '√  Interpose NO objection for the issuance of the corresponding Mayor\'s Permit being applied.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
              ] else ...[
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 1.5,
                    ),
                    children: [
                      const pw.TextSpan(text: 'Being applied for '),
                      pw.TextSpan(
                        text: 'RENEW',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      const pw.TextSpan(
                        text:
                            ' of the corresponding Mayor\'s Permit has been found to be:',
                      ),
                    ],
                  ),
                  textAlign: pw.TextAlign.justify,
                  overflow: pw.TextOverflow.span,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      'X  Complying with the provisions of existing Barangay Ordinances, Rules and Regulations being enforced in this Barangay.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 4),
                pw.Paragraph(
                  text:
                      '[  ]  Partially complying with the provisions of existing Barangay Ordinances, Rules and Regulation being enforced in this Barangay.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      'In view of the foregoing, this Barangay, thru the undersigned.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      'X  Interpose NO objection for the issuance of the corresponding Mayor\'s Permit being applied for;',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 4),
                pw.Paragraph(
                  text:
                      '[  ]  Recommends only the issuance of a "TEMPORARY MAYOR\'S PERMIT" for not more than three (3) months and within that period the requirements under existing Barangay Ordinances, Rules and Regulations on that matter should be totally complied with, otherwise this Barangay would take the necessary actions within legal bound, to stop its continued operation.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
              ],
              pw.SizedBox(height: 22),

              // Signature Section (right-aligned, single rule line)
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
                        approverName ??
                            config.barangayCaptain ??
                            'PUNONG BARANGAY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Punong Barangay',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Note (bottom-left, italic)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note: This certificate is not valid without the barangay seal.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'business_clearance_${request.id}.pdf');
  }

  /// Generate Barangay Certification PDF (employment/salary).
  static Future<File> generateCertification({
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
        // Photo load failures must never block PDF generation.
      }
    }

    final occupation = data['occupation']?.toString().isNotEmpty == true
        ? data['occupation'].toString()
        : '____________________';
    final requester = data['requester']?.toString().isNotEmpty == true
        ? data['requester'].toString()
        : userFullName;

    String salaryLabel;
    final incomeVal = data['annual_income'];
    if (incomeVal == null || incomeVal.toString().trim().isEmpty) {
      salaryLabel = 'Php ______';
    } else {
      final parsed = num.tryParse(incomeVal.toString().replaceAll(',', ''));
      salaryLabel = parsed != null
          ? 'Php ${NumberFormat('#,##0.00').format(parsed)}'
          : 'Php ______';
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
                      'BARANGAY CERTIFICATION',
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

              // Salutation
              pw.Text(
                'TO WHOM IT MAY CONCERN;',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 16),

              // Body
              pw.Paragraph(
                text:
                    'This is to certify that $userFullName, of legal age, $civilStatus, is a Bonafide resident of $userAddress, ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 14),

              // Occupation / salary (values bolded)
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  children: [
                    const pw.TextSpan(
                      text: 'This certifies further that the work is a ',
                    ),
                    pw.TextSpan(
                      text: occupation,
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    const pw.TextSpan(text: ' with monthly salary of '),
                    pw.TextSpan(
                      text: salaryLabel,
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    const pw.TextSpan(text: ' only.'),
                  ],
                ),
                textAlign: pw.TextAlign.justify,
                overflow: pw.TextOverflow.span,
              ),
              pw.SizedBox(height: 14),

              pw.Paragraph(
                text:
                    'This certification is being issued upon request of $requester for ${request.purpose} it may serve.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 14),

              pw.Paragraph(
                text:
                    'Issued this ${_formatDate(DateTime.now())} at ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 36),

              // Signature Section (right-aligned, single rule line)
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
                        approverName ??
                            config.barangayCaptain ??
                            'PUNONG BARANGAY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Punong Barangay',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Note (bottom-left, italic)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note: This certificate is not valid without the barangay seal.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'certification_${request.id}.pdf');
  }

  /// Generate Electronic Receipt PDF for any document request.
  static Future<File> generateERecceipt({
    required DocumentRequest request,
    required BarangayConfig config,
    required String userFullName,
    required String userAddress,
    String? paymentReceiptUrl,
    String? documentId,
    String? qrUrl,
    String? verificationToken,
    String? expiresAtLabel,
  }) async {
    final pdf = pw.Document(theme: await _loadUnicodeTheme());
    final data = request.documentData;
    final amount = data['amount']?.toString() ?? '0.00';
    final paymentMethod = data['payment_method']?.toString() ??
        request.paymentMethod ??
        'N/A';
    final referenceNumber = data['reference_number']?.toString() ??
        request.paymentReferenceNumber ??
        'N/A';
    final paymentStatus = request.paymentStatus;
    final requestedAt = request.requestedAt;
    final reviewedAt = request.reviewedAt;
    final paidAt = request.paymentVerifiedAt;
    final approvedAt = request.approvedAt;
    final releasedAt = request.releasedAt;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.legal,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(config),
              pw.SizedBox(height: 30),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ELECTRONIC RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 300,
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
              pw.SizedBox(height: 20),

              // Receipt Number
              pw.Center(
                child: pw.Text(
                  'Receipt No.: ${documentId ?? request.id}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Document Request Details Section
              _buildSectionTitle('DOCUMENT REQUEST DETAILS'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Document Type:', _formatDocumentType(request.documentType)),
              _buildInfoRow('Purpose:', request.purpose),
              _buildInfoRow('Request ID:', request.id),
              if (documentId != null && documentId.isNotEmpty)
                _buildInfoRow('Document ID:', documentId),
              pw.SizedBox(height: 20),

              // Citizen Information Section
              _buildSectionTitle('CITIZEN INFORMATION'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Full Name:', userFullName),
              _buildInfoRow('Address:', '$userAddress, ${config.barangayName}'),
              pw.SizedBox(height: 20),

              // Payment Information Section
              _buildSectionTitle('PAYMENT INFORMATION'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Amount:', 'PHP ${_formatAmount(amount)}'),
              _buildInfoRow('Status:', _formatPaymentStatus(paymentStatus)),
              _buildInfoRow('Method:', paymentMethod),
              _buildInfoRow('Reference Number:', referenceNumber),
              if (paymentReceiptUrl != null && paymentReceiptUrl.isNotEmpty)
                _buildInfoRow('Receipt URL:', paymentReceiptUrl),
              pw.SizedBox(height: 20),

              // Timeline Section
              _buildSectionTitle('TIMELINE'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Requested At:', _formatDate(requestedAt)),
              if (reviewedAt != null)
                _buildInfoRow('Reviewed At:', _formatDate(reviewedAt)),
              if (paidAt != null)
                _buildInfoRow('Paid At:', _formatDate(paidAt)),
              if (approvedAt != null)
                _buildInfoRow('Approved At:', _formatDate(approvedAt)),
              if (releasedAt != null)
                _buildInfoRow('Released At:', _formatDate(releasedAt)),
              pw.SizedBox(height: 20),

              // Barangay Official Info
              _buildSectionTitle('BARANGAY OFFICIAL'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Barangay Captain:', config.barangayCaptain ?? 'N/A'),
              pw.SizedBox(height: 30),

              // QR Code
              if (qrUrl != null && qrUrl.isNotEmpty) ...[
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Verification QR Code',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 100,
                        height: 100,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrUrl,
                          drawText: false,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Footer
              _buildFooter(
                config,
                documentId ?? request.id,
                qrUrl: qrUrl ?? request.qrUrl,
                expiresAtLabel: expiresAtLabel,
                copyNotice: verificationToken != null
                    ? 'Verification Token: ${verificationToken.length > 12 ? verificationToken.substring(0, 12).toUpperCase() : verificationToken.toUpperCase()}'
                    : null,
              ),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'e_receipt_${request.id}.pdf');
  }

  /// Helper to build section titles
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Format document type for display
  static String _formatDocumentType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Format payment status for display
  static String _formatPaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Verification';
      case 'verified':
      case 'confirmed':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'partial':
        return 'Partial Payment';
      default:
        return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }

  /// Format amount with commas
  static String _formatAmount(String amount) {
    final parsed = num.tryParse(amount.replaceAll(',', ''));
    if (parsed == null) return amount;
    return NumberFormat('#,##0.00').format(parsed);
  }

  /// Generate Certificate of Good Moral Character PDF.
  static Future<File> generateGoodMoral({
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
        // Photo load failures must never block PDF generation.
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
                      'CERTIFICATION',
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

              // Salutation
              pw.Text(
                'TO WHOM IT MAY CONCERN;',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 16),

              // Body (GOOD MORAL CHARACTER bolded)
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  children: [
                    pw.TextSpan(
                      text:
                          'This is to certify that $userFullName, $civilStatus, legal age, Filipino citizen, is a resident of this Barangay and who is personally known to me to be a law-abiding citizen and has a ',
                    ),
                    const pw.TextSpan(
                      text: 'GOOD MORAL CHARACTER',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    const pw.TextSpan(
                      text:
                          '. That of my own personal knowledge, has not committed, nor been involved in, any kind of unlawful activities in this Barangay.',
                    ),
                  ],
                ),
                textAlign: pw.TextAlign.justify,
                overflow: pw.TextOverflow.span,
              ),
              pw.SizedBox(height: 14),

              pw.Paragraph(
                text:
                    'Issued this ${_formatDate(DateTime.now())} at Barangay Hall, ${config.barangayName} for whatever purpose it may serve him/her best.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 36),

              // Signature Section (right-aligned, single rule line)
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
                        approverName ??
                            config.barangayCaptain ??
                            'PUNONG BARANGAY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Punong Barangay',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Note (bottom-left, italic)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note: This certificate is not valid without the barangay seal.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'good_moral_${request.id}.pdf');
  }

  /// Generate Certificate of Residency PDF.
  static Future<File> generateResidency({
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
        // Photo load failures must never block PDF generation.
      }
    }

    final requester = data['requester']?.toString().isNotEmpty == true
        ? data['requester'].toString()
        : userFullName;

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

              // Title (two stacked bold centered lines)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BARANGAY CERTIFICATION OF',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'RESIDENCY',
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

              // Salutation
              pw.Text(
                'TO WHOM IT MAY CONCERN;',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 16),

              // Body
              pw.Paragraph(
                text:
                    'This is to certify that $userFullName, of legal age, $civilStatus, Filipino citizen, bonafide resident of $userAddress, ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 14),

              pw.Paragraph(
                text:
                    'This certification is issued upon request of $requester for ${request.purpose} purpose may serve her/him best.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 14),

              pw.Paragraph(
                text:
                    'Issued this ${_formatDate(DateTime.now())} at Barangay Hall, ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 36),

              // Signature Section (right-aligned, single rule line)
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
                        approverName ??
                            config.barangayCaptain ??
                            'PUNONG BARANGAY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Punong Barangay',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Note (bottom-left, italic)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note: This certificate is not valid without the barangay seal.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'residency_${request.id}.pdf');
  }

  /// Generate Certification Oath Undertaking PDF
  /// (First Time Jobseeker Act of 2019, R.A. 11261).
  static Future<File> generateOathUndertaking({
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
        // Photo load failures must never block PDF generation.
      }
    }

    final residencyLength = data['residency_length']?.toString().isNotEmpty ==
            true
        ? data['residency_length'].toString()
        : '______';

    const undertakings = [
      'That this is the first time that I will actively look for a job, and therefore requesting that a Barangay Certification be issued in my favor to avail the benefits of the law;',
      'That I am aware that the benefits and privilege/s under the said law shall be validated only for one (1) year from the date that the Barangay Certification is issued;',
      'That can avail the benefits of the Law only once;',
      'That I understand that may personal information shall be included in the Roster/List of First Time Jobseeker and will not be used for any unlawful purpose;',
      'That I will inform and/or report to the Barangay personally, through text or other means, or through my family/relative once I get employed, and',
      'That I am not a beneficiary of the Job Start Program under R.A. No. 10869 and other laws that give similar exemptions for the documents or transactions exempted under R.A. No. 11261;',
      'That if issued the request certification, I will not use the same in any fraud, neither falsify nor help and/or assist in the fabrication of the said certification;',
      'That this undertaking is made solely for the purpose of obtaining a Barangay Certification consistent with the objective of R.A. No. 11261 and not for any other purpose;',
      'That I consent to the use of my personal information pursuant to the Data Privacy Act and other applicable laws, and regulations;',
    ];

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
                      'CERTIFICATION OATH UNDERTAKING',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 290,
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
              pw.SizedBox(height: 24),

              // Salutation
              pw.Text(
                'TO WHOM IT MAY CONCERN:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 14),

              // Intro
              pw.Paragraph(
                text:
                    'I\'m $userFullName, $userAge years old, $civilStatus, resident of $userAddress, ${config.barangayName}, for $residencyLength (years/months), availing the benefits of Republic Act 11261, otherwise known as the First Time Jobseeker Act of 2019, do hereby declare, agree and undertake to abide and be bound by the following.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),

              // Numbered undertakings
              for (var i = 0; i < undertakings.length; i++) ...[
                pw.Paragraph(
                  text: '${i + 1}. ${undertakings[i]}',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 4),
              ],
              pw.SizedBox(height: 6),

              pw.Paragraph(
                text:
                    'Issued this ${_formatDate(DateTime.now())} at Barangay Hall, ${config.barangayName}.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 28),

              // Signature Section (right-aligned, single rule line)
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
                        approverName ??
                            config.barangayCaptain ??
                            'PUNONG BARANGAY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Punong Barangay',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Note (bottom-left, italic)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note: This certificate is not valid without the barangay seal.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Footer
              _buildFooter(config, documentId ?? request.id, qrUrl: qrUrl ?? request.qrUrl, expiresAtLabel: expiresAtLabel, copyNotice: copyNotice),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'oath_undertaking_${request.id}.pdf');
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
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 12, height: 55),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                'REPUBLIC OF THE PHILIPPINES',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Province of Palawan', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Municipality of Narra', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Barangay Poblacion', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text(
                'OFFICE OF THE PUNONG BARANGAY',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
            ],
          ),
        ),
      ],
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
    return DateFormat('MMMM dd, yyyy').format(Helpers.toPh(date));
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
        ? DateFormat('MMMM dd, yyyy – hh:mm a').format(Helpers.toPh(signedAt))
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
