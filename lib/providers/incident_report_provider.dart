import 'package:flutter/foundation.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/services/incident_report_cache_service.dart';
import 'package:guin_app/services/incident_report_service.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/utils/role_access.dart';

class IncidentReportProvider with ChangeNotifier {
  final IncidentReportService _service = IncidentReportService();
  final IncidentReportCacheService _cache = IncidentReportCacheService();
  final NotificationService _notificationService = NotificationService();

  List<IncidentReport> _reports = [];
  bool _isLoading = false;
  String? _error;
  bool _isFromCache = false;
  DateTime? _cacheTimestamp;

  List<IncidentReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isFromCache => _isFromCache;
  DateTime? get cacheTimestamp => _cacheTimestamp;

  // Load the citizen's own reports: network-first, with an offline cache
  // fallback so previously loaded reports stay viewable without connectivity.
  Future<void> loadMyReports(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reports = await _service.getMyReports(userId);
      _isFromCache = false;
      _cacheTimestamp = null;
      _isLoading = false;
      notifyListeners();

      // Write-through: keep the offline copy fresh. Must never break the load.
      try {
        await _cache.saveMyReports(userId, _reports);
      } catch (e) {
        debugPrint('Caching incident reports failed: $e');
      }
    } catch (e) {
      // Network fetch failed — fall back to the last cached copy.
      final cached = await _cache.loadMyReports(userId);
      if (cached != null) {
        _reports = cached.reports;
        _isFromCache = true;
        _cacheTimestamp = cached.cachedAt;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // No cache available: surface the error for the UI to show a retry state.
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reports = await _service.getAllReports();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitReport({
    required String submittedBy,
    required String reportType,
    required String title,
    required String description,
    required String location,
    required DateTime incidentDateTime,
    required bool isSensitive,
    required bool isAnonymous,
    String priority = 'normal',
    double? latitude,
    double? longitude,
  }) async {
    await _service.submitReport(
      submittedBy: submittedBy,
      reportType: reportType,
      title: title,
      description: description,
      location: location,
      incidentDateTime: incidentDateTime,
      isSensitive: isSensitive,
      isAnonymous: isAnonymous,
      priority: priority,
      latitude: latitude,
      longitude: longitude,
    );

    // Official-side fan-out: tanod/captain/admin get a new-report notice.
    // Best-effort — never fails the citizen's submission.
    try {
      await _notificationService.notifyRoles(
        roles: [
          AppRoles.barangayTanod,
          AppRoles.captain,
          AppRoles.legacyAdmin,
        ],
        title: 'New incident report',
        message: '$title ($reportType) was reported at $location.',
        type: 'incident_submitted',
      );
    } catch (e) {
      debugPrint('Incident fan-out notification failed: $e');
    }

    await loadMyReports(submittedBy);
  }

  Future<void> updateStatus({
    required String reportId,
    required String updatedBy,
    required String newStatus,
    String? remarks,
  }) async {
    await _service.updateStatus(
      reportId: reportId,
      updatedBy: updatedBy,
      newStatus: newStatus,
      remarks: remarks,
    );
    await loadAllReports();
  }
}
