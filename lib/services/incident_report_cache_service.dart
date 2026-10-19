import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached snapshot of a user's incident reports plus when it was stored.
class CachedReports {
  final List<IncidentReport> reports;
  final DateTime? cachedAt;

  const CachedReports({required this.reports, this.cachedAt});
}

/// Offline cache for a citizen's own incident reports.
///
/// Mirrors DocumentCacheService: per-user JSON in [SharedPreferences], and
/// every method is exception-safe so a cache failure never breaks the app.
class IncidentReportCacheService {
  static const String _keyPrefix = 'cached_my_reports_';

  String _key(String userId) => '$_keyPrefix$userId';

  /// Write-through: called after a successful online fetch.
  Future<void> saveMyReports(
    String userId,
    List<IncidentReport> reports,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'cachedAt': Helpers.now().toIso8601String(),
        'reports': reports.map((r) => r.toJson()).toList(),
      });
      await prefs.setString(_key(userId), payload);
    } catch (e) {
      debugPrint('IncidentReportCacheService.saveMyReports failed: $e');
    }
  }

  /// Returns the cached snapshot for [userId], or null when nothing valid is
  /// cached (missing, corrupt, or unreadable).
  Future<CachedReports?> loadMyReports(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final rawReports = decoded['reports'];
      if (rawReports is! List) return null;

      final reports = rawReports
          .whereType<Map<String, dynamic>>()
          .map(IncidentReport.fromJson)
          .toList();

      final rawCachedAt = decoded['cachedAt'];
      final cachedAt =
          rawCachedAt is String ? DateTime.tryParse(rawCachedAt) : null;

      return CachedReports(reports: reports, cachedAt: cachedAt);
    } catch (e) {
      debugPrint('IncidentReportCacheService.loadMyReports failed: $e');
      return null;
    }
  }

  /// Drop a user's cached reports (e.g. on logout).
  Future<void> clearMyReports(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      debugPrint('IncidentReportCacheService.clearMyReports failed: $e');
    }
  }
}
