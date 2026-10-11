import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Downsamples image bytes to a PNG and returns them base64-encoded, which is
/// the only image format the `ai` edge function accepts inline.
///
/// Pure `dart:ui` — no third-party image package. Every failure path
/// (undecodable bytes, unsupported format, PNG still too large) returns null so
/// callers degrade exactly like [AiService.invoke]: AI is a nice-to-have, never
/// a blocker for the core workflow.
class ImageCompressor {
  ImageCompressor._();

  /// Hard cap on the encoded PNG. A <=800px ID photo lands far below this;
  /// anything bigger is treated as unusable rather than sent.
  static const int maxPngBytes = 700000;

  /// Compresses [file] to a PNG whose longest side is <=[maxDimension] and
  /// returns it base64-encoded, or null when that is not possible.
  static Future<String?> toBase64Png(
    File file, {
    int maxDimension = 800,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return await encodeBytesToBase64Png(bytes, maxDimension: maxDimension);
    } catch (e) {
      return null;
    }
  }

  /// Shared encode helper: [toBase64Png] (files picked by the user) and the
  /// captured ID/selfie uploads in `AiIdVerifier` both funnel through here.
  ///
  /// The image is only ever downscaled — a smaller-than-[maxDimension] source
  /// keeps its intrinsic size. Returns base64 PNG, or null when the bytes
  /// cannot be decoded or the re-encoded PNG is still larger than
  /// [maxPngBytes].
  static Future<String?> encodeBytesToBase64Png(
    Uint8List bytes, {
    int maxDimension = 800,
  }) async {
    if (bytes.isEmpty) return null;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (int width, int height) {
          final longestSide = width > height ? width : height;
          if (longestSide <= maxDimension) return const ui.TargetImageSize();
          final scale = maxDimension / longestSide;
          return ui.TargetImageSize(
            width: math.max(1, (width * scale).round()),
            height: math.max(1, (height * scale).round()),
          );
        },
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      if (byteData == null) return null;
      final png = byteData.buffer.asUint8List();
      if (png.lengthInBytes > maxPngBytes) return null;
      return base64Encode(png);
    } catch (e) {
      return null;
    }
  }
}
