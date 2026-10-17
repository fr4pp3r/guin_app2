import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/models/announcement.dart';
import 'package:guin_app/services/announcement_service.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/utils/session_manager.dart';

/// Barangay announcement board state.
///
/// Every signed-in user reads the same global list — there is no per-role or
/// per-user filtering. Officials listed in [AppRoles.canPostAnnouncements] are
/// the only ones the UI offers a create/delete affordance to; the data layer
/// itself stays permissive like the rest of the app.
class AnnouncementProvider extends ChangeNotifier {
  final AnnouncementService _announcementService = AnnouncementService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _subscription;
  int _subscribers = 0;

  /// Pinned first, then newest first (ordering comes from the query).
  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnnouncements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _announcements = await _announcementService.getAnnouncements();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Live feed: reloads the list whenever any announcement row changes.
  ///
  /// Reference-counted. The feed screen is pushed on top of dashboards that
  /// already hold this subscription, so the screen disposing must not tear down
  /// the channel a still-mounted dashboard relies on — the channel closes only
  /// when the last subscriber releases it. (The feed is global, with no
  /// per-user filter, so a subscription outliving one dashboard is harmless.)
  void subscribeToAnnouncements() {
    _subscribers++;
    if (_subscription != null) return;
    _subscription = _announcementService.subscribeToAnnouncements(() {
      loadAnnouncements();
    });
  }

  Future<void> unsubscribe() async {
    if (_subscribers > 0) _subscribers--;
    if (_subscribers > 0) return;

    final channel = _subscription;
    _subscription = null;
    if (channel == null) return;
    try {
      await _announcementService.unsubscribeFromAnnouncements(channel);
    } catch (e) {
      debugPrint('Announcements unsubscribe failed: $e');
    }
  }

  /// Post a notice. Returns false (and sets [error]) on failure.
  ///
  /// The author is resolved from the active session, so callers only supply
  /// content. Fanning a bell notification out to every approved user is
  /// best-effort and can never fail the post itself.
  Future<bool> createAnnouncement({
    required String title,
    required String body,
    required bool isPinned,
    File? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _announcementService.uploadImage(imageFile);
      }

      final authorId = await SessionManager.getUserId();
      final authorName = await _resolveAuthorName(authorId);

      await _announcementService.createAnnouncement(
        title: title.trim(),
        body: body.trim(),
        isPinned: isPinned,
        createdBy: authorId,
        createdByName: authorName,
        imageUrl: imageUrl,
      );

      await loadAnnouncements();

      try {
        await _notificationService.notifyAllApproved(
          title: 'New announcement: ${title.trim()}',
          message: authorName,
          type: 'system',
        );
      } catch (e) {
        debugPrint('Announcement notification fan-out failed: $e');
      }

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _announcementService.deleteAnnouncement(id);
      _announcements = _announcements.where((a) => a.id != id).toList();
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

  /// Best-effort display name for the poster: live profile, then the cached
  /// session snapshot, then a role-neutral fallback.
  Future<String> _resolveAuthorName(String? userId) async {
    if (userId == null) return 'Barangay Official';
    try {
      final profile = await _userService.getUserProfile(userId);
      final name = profile?.fullName.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (e) {
      debugPrint('Announcement author lookup failed: $e');
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
