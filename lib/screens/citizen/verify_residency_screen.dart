import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/services/residency_proof_service.dart';
import 'package:guin_app/services/ai_residency_verifier.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/image_compressor.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class VerifyResidencyScreen extends StatefulWidget {
  const VerifyResidencyScreen({super.key});

  @override
  State<VerifyResidencyScreen> createState() => _VerifyResidencyScreenState();
}

class _VerifyResidencyScreenState extends State<VerifyResidencyScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ResidencyProofService _proofService = ResidencyProofService();
  final AiResidencyVerifier _aiVerifier = AiResidencyVerifier();

  XFile? _proofImage;
  bool _verifying = false;
  String? _statusMessage;

  final List<String> _acceptedProofs = [
    'PALECO / Electricity Bill',
    'Water Bill',
    'PTTLC / Phone Bill',
    'TIN ID',
    "Driver's License or Voter's Card (with Poblacion address)",
  ];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked != null && mounted) {
      setState(() => _proofImage = picked);
    }
  }

  Future<void> _verifyWithAi() async {
    if (_proofImage == null) {
      Helpers.showErrorSnackBar(context, AppLocalizations.of(context).verifyResidencyUploadHint);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final fullName = authProvider.userProfile?.fullName ?? '';
    if (fullName.isEmpty) {
      Helpers.showErrorSnackBar(context, 'User profile not found');
      return;
    }

    setState(() {
      _verifying = true;
      _statusMessage = AppLocalizations.of(context).verifyResidencyUploading;
    });

    try {
      final base64 = await ImageCompressor.toBase64Png(File(_proofImage!.path));
      if (base64 == null) {
        throw Exception('Image compression failed');
      }

      final proof = await _proofService.uploadProof(
        userId: authProvider.userProfile!.id,
        image: File(_proofImage!.path),
        documentType: 'residency_proof',
      );

      final suggestion = await _aiVerifier.verify(
        proofB64: base64,
        fullName: fullName,
      );

      if (!mounted) return;

      if (suggestion == null) {
        setState(() {
          _verifying = false;
          _statusMessage = AppLocalizations.of(context).verifyResidencyFailed;
        });
        Helpers.showErrorSnackBar(
          context,
          '${AppLocalizations.of(context).verifyResidencyFailed} — ${AppLocalizations.of(context).verifyResidencyManualEscalation}',
        );
        return;
      }

      if (suggestion.isConfirmed) {
        await _proofService.confirmProof(
          proofId: proof.id,
          userId: authProvider.userProfile!.id,
          auditorNotes: 'AI verified: ${suggestion.notes.join('; ')}',
        );

        // Refresh user profile
        await authProvider.loadUserProfile();

        if (mounted) {
          Helpers.showSuccessSnackBar(
            context,
            AppLocalizations.of(context).verifyResidencySuccess,
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _verifying = false;
          _statusMessage = AppLocalizations.of(context).verifyResidencyFailed;
        });
        Helpers.showErrorSnackBar(
          context,
          '${AppLocalizations.of(context).verifyResidencyFailed}\n${suggestion.notes.join('\n')}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _statusMessage = AppLocalizations.of(context).verifyResidencyFailed;
      });
      Helpers.showErrorSnackBar(
        context,
        '${AppLocalizations.of(context).verifyResidencyFailed} — ${AppLocalizations.of(context).verifyResidencyManualEscalation}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyResidencyTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.verifyResidencySubtitle,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.verifyResidencyUploadHint,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._acceptedProofs.map((proof) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(child: Text(proof)),
              ],
            ),
          )),
          const SizedBox(height: 24),
          _buildImagePicker(),
          const SizedBox(height: 24),
          if (_verifying || _statusMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _verifying ? null : _verifyWithAi,
              icon: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified),
              label: Text(_verifying
                  ? l10n.verifyResidencyUploading
                  : l10n.commonVerify),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showSourceDialog(),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _proofImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_proofImage!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text(
                        l10n.verifyResidencyUploadHint,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to take photo or choose from gallery',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
        if (_proofImage != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _proofImage = null),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.verifyResidencyUploadHint.replaceAll(':', '')),
          ),
        ],
      ],
    );
  }

  void _showSourceDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.verifyResidencyUploadHint),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}