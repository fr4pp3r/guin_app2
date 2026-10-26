import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:guin_app/l10n/generated/app_localizations.dart';

/// Shows the treasurer's Confirm Payment dialog with the mandatory
/// official-receipt photo step attached.
///
/// Returns the picked image when the treasurer confirms, or `null` when they
/// cancel. The confirm action stays disabled until a photo is selected; the
/// upload itself happens in the caller so a failed upload never leaves a
/// half-confirmed state.
Future<File?> showConfirmPaymentDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<File>(
    context: context,
    builder: (ctx) => _ConfirmPaymentDialog(message: message),
  );
}

class _ConfirmPaymentDialog extends StatefulWidget {
  const _ConfirmPaymentDialog({required this.message});

  final String message;

  @override
  State<_ConfirmPaymentDialog> createState() => _ConfirmPaymentDialogState();
}

class _ConfirmPaymentDialogState extends State<_ConfirmPaymentDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Same parameters as the citizen receipt picker
      // (upload_payment_screen.dart) so uploads stay consistent.
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authFailedPickImage)),
      );
    }
  }

  Future<void> _chooseImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).authSelectImageSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.of(context).authCameraOption),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(context).authGalleryOption),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasImage = _image != null;

    return AlertDialog(
      title: Text(l10n.atreasConfirmPayment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            Text(
              l10n.atreasOfficialReceiptPhoto,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!hasImage) ...[
              InkWell(
                onTap: _chooseImage,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 32,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.atreasAddReceiptPhoto,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.atreasOfficialReceiptHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  _image!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 4),
              // Two equal-width actions under the preview, aligned as a
              // single row in every locale. Expanded bounds each button,
              // and the FittedBox scales a too-wide label down as a whole
              // instead of overflowing the dialog (this Row used to
              // overflow by 17px, and a Wrap stacked the buttons on two
              // uneven lines).
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _chooseImage,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.atreasRetakePhoto, maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _image = null),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.atreasRemovePhoto, maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton.icon(
          // A photo is required before the payment can be confirmed.
          onPressed: hasImage ? () => Navigator.pop(context, _image) : null,
          icon: const Icon(Icons.check, size: 18),
          label: Text(l10n.atreasConfirmPayment),
        ),
      ],
    );
  }
}
