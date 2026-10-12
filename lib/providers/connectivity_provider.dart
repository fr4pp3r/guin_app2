import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Global network-connectivity state for the app.
///
/// Tracks whether the device currently has a usable network interface
/// (wi-fi / mobile / ethernet) so the UI can show a single app-wide
/// "you're offline" indicator.
///
/// Caveat: this is interface-level. An interface that is up but behind a
/// captive portal or with no real internet still reports as online; the
/// per-screen offline banners (which react to actual request failures) remain
/// the authoritative signal for a specific fetch.
class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;

  /// True when there is no usable network interface.
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('ConnectivityProvider initial check failed: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e) {
        debugPrint('ConnectivityProvider stream error: $e');
      },
    );
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = isOfflineFrom(results);
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  /// Pure derivation of the offline flag from a connectivity result set:
  /// offline when there are no interfaces or every interface is `none`.
  static bool isOfflineFrom(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
