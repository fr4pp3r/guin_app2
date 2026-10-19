import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached snapshot of a user's document requests plus when it was stored.
class CachedRequests {
  final List<DocumentRequest> requests;
  final DateTime? cachedAt;

  const CachedRequests({required this.requests, this.cachedAt});
}

/// Lightweight offline cache for a citizen's own document requests.
///
/// Stores request metadata + status as JSON in [SharedPreferences], keyed per
/// user so two accounts on one device never see each other's documents. Every
/// method is exception-safe: a cache failure must never break the app's core
/// workflow, so failures are logged and reported as "nothing cached".
class DocumentCacheService {
  static const String _keyPrefix = 'cached_my_requests_';

  String _key(String userId) => '$_keyPrefix$userId';

  /// Write-through: called after a successful online fetch.
  Future<void> saveMyRequests(
    String userId,
    List<DocumentRequest> requests,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'cachedAt': Helpers.now().toIso8601String(),
        'requests': requests.map((r) => r.toJson()).toList(),
      });
      await prefs.setString(_key(userId), payload);
    } catch (e) {
      debugPrint('DocumentCacheService.saveMyRequests failed: $e');
    }
  }

  /// Returns the cached snapshot for [userId], or null when nothing valid is
  /// cached (missing, corrupt, or unreadable).
  Future<CachedRequests?> loadMyRequests(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final rawRequests = decoded['requests'];
      if (rawRequests is! List) return null;

      final requests = rawRequests
          .whereType<Map<String, dynamic>>()
          .map(DocumentRequest.fromJson)
          .toList();

      final rawCachedAt = decoded['cachedAt'];
      final cachedAt =
          rawCachedAt is String ? DateTime.tryParse(rawCachedAt) : null;

      return CachedRequests(requests: requests, cachedAt: cachedAt);
    } catch (e) {
      debugPrint('DocumentCacheService.loadMyRequests failed: $e');
      return null;
    }
  }

  /// Drop a user's cached documents (e.g. on logout).
  Future<void> clearMyRequests(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      debugPrint('DocumentCacheService.clearMyRequests failed: $e');
    }
  }
}
