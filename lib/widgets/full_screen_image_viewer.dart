import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart'; // also exports XFile

import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/utils/helpers.dart';

/// Full-screen, pinch-zoomable image viewer.
///
/// When [shareFileBaseName] is set, the AppBar shows a Download/Share action:
/// the image bytes are fetched and handed to the system share sheet, so the
/// user can save them to the gallery/files (mobile) or download them in the
/// browser (web). This is the shared replacement for the several private
/// `_FullScreenImageViewer` copies — new screens should use this widget.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.title,
    required this.url,
    this.shareFileBaseName,
  });

  /// AppBar / share-sheet title.
  final String title;

  /// Public URL of the image to display.
  final String url;

  /// Base file name (without extension) for Download/Share; the extension is
  /// derived from [url]. When null the viewer is display-only.
  final String? shareFileBaseName;

  /// Extension derived from the URL path (public URLs keep the original
  /// extension, e.g. `.../official_1760000000000.jpg`).
  static String extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  static String _mimeTypeFromUrl(String url) => switch (extensionFromUrl(url)) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  Future<void> _shareImage(BuildContext context, RenderBox originBox) async {
    final l10n = AppLocalizations.of(context);
    Helpers.showLoadingDialog(context, l10n.payOfficialReceiptPreparing);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (!context.mounted) return;
      Helpers.dismissDialog(context);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              response.bodyBytes,
              mimeType: _mimeTypeFromUrl(url),
            ),
          ],
          // XFile.fromData ignores `name` on most platforms.
          fileNameOverrides: [
            '$shareFileBaseName${extensionFromUrl(url)}',
          ],
          title: title,
          sharePositionOrigin:
              originBox.localToGlobal(Offset.zero) & originBox.size,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(context, l10n.payOfficialReceiptShareFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (shareFileBaseName != null)
            // Builder gives this button's own RenderBox as the iPad
            // popover anchor for the share sheet.
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: l10n.payOfficialReceiptDownload,
                icon: const Icon(Icons.download_outlined),
                onPressed: () {
                  final box = buttonContext.findRenderObject();
                  if (box is! RenderBox) return;
                  _shareImage(context, box);
                },
              ),
            ),
        ],
      ),
      body: InteractiveViewer(
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, _) => const CircularProgressIndicator(),
            errorWidget: (context, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
