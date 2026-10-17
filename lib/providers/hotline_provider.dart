import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/models/emergency_hotline.dart';
import 'package:guin_app/services/emergency_hotline_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/session_manager.dart';

/// Emergency hotline directory state.
///
/// Every signed-in user reads the same global list. Officials listed in
/// [AppRoles.canManageHotlines] are the only ones the UI offers
/// create/update/delete affordances to; the data layer itself stays
/// permissive like the rest of the app.
class HotlineProvider extends ChangeNotifier {
  final EmergencyHotlineService _hotlineService = EmergencyHotlineService();
  final UserService _userService = UserService();

  List<EmergencyHotline> _hotlines = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _subscription;
  int _subscribers = 0;

  /// Active first, then alphabetically by name (ordering comes from the query).
  List<EmergencyHotline> get hotlines => _hotlines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadHotlines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _hotlines = await _hotlineService.getHotlines();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Live feed: reloads the list whenever any hotline row changes.
  ///
  /// Reference-counted. The hotlines screen is pushed on top of dashboards
  /// that already hold this subscription, so the screen disposing must not
  /// tear down the channel a still-mounted dashboard relies on — the channel
  /// closes only when the last subscriber releases it.
  void subscribeToHotlines() {
    _subscribers++;
    if (_subscription != null) return;
    _subscription = _hotlineService.subscribeToHotlines(() {
      loadHotlines();
    });
  }

  Future<void> unsubscribe() async {
    if (_subscribers > 0) _subscribers--;
    if (_subscribers > 0) return;

    final channel = _subscription;
    _subscription = null;
    if (channel == null) return;
    try {
      await _hotlineService.unsubscribeFromHotlines(channel);
    } catch (e) {
      debugPrint('Hotlines unsubscribe failed: $e');
    }
  }

  /// Add a hotline entry. Returns false (and sets [error]) on failure.
  ///
  /// The author is resolved from the active session, so callers only supply
  /// content.
  Future<bool> createHotline({
    required String name,
    required String number,
    String? description,
    required bool isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authorId = await SessionManager.getUserId();
      final authorName = await _resolveAuthorName(authorId);

      await _hotlineService.createHotline(
        name: name.trim(),
        number: number.trim(),
        description: description?.trim(),
        isActive: isActive,
        createdBy: authorId,
        createdByName: authorName,
      );

      await loadHotlines();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing hotline entry. Returns false (and sets [error]) on
  /// failure.
  Future<bool> updateHotline({
    required String id,
    required String name,
    required String number,
    String? description,
    required bool isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotlineService.updateHotline(
        id: id,
        name: name.trim(),
        number: number.trim(),
        description: description?.trim(),
        isActive: isActive,
      );

      await loadHotlines();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteHotline(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotlineService.deleteHotline(id);
      _hotlines = _hotlines.where((h) => h.id != id).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Best-effort display name for the editor: live profile, then the cached
  /// session snapshot, then a role-neutral fallback.
  Future<String> _resolveAuthorName(String? userId) async {
    if (userId == null) return 'Barangay Official';
    try {
      final profile = await _userService.getUserProfile(userId);
      final name = profile?.fullName.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (e) {
      debugPrint('Hotline author lookup failed: $e');
    }
    try {
      final snapshot = await SessionManager.getProfileSnapshot();
      final name = snapshot?.fullName.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Fall through to the generic label.
    }
    return 'Barangay Official';
  }
}
