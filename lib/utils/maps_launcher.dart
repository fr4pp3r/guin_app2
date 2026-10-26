import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps with turn-by-turn directions to an incident's pin.
///
/// Deliberately uses the **universal** `https://www.google.com/maps/dir/` URL
/// rather than the Android-only `google.navigation:` scheme: the same link
/// works on Android (hands off to the Google Maps app when installed, else the
/// browser), iOS (Google Maps app or Safari) and web (new tab), so no
/// per-platform branch is needed.
class MapsLauncher {
  MapsLauncher._();

  /// Builds the Google Maps directions URL.
  ///
  /// No `origin` is sent on purpose — omitting it makes Google Maps default
  /// the starting point to the device's current location, which is exactly
  /// what "Go Direction" means. Pure and offline-testable.
  static Uri directionsUri({
    required double latitude,
    required double longitude,
    String travelMode = 'driving',
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': travelMode,
    });
  }

  /// Hands the directions URL to the platform. Returns false when nothing
  /// could handle it (no browser / no Maps app) so callers can show a
  /// graceful message instead of failing silently.
  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
    String travelMode = 'driving',
  }) async {
    final uri = directionsUri(
      latitude: latitude,
      longitude: longitude,
      travelMode: travelMode,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Never let an external-app hand-off crash the screen.
      debugPrint('openDirections failed: $e');
      return false;
    }
  }
}
