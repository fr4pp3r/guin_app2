import 'package:flutter/foundation.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/services/incident_report_service.dart';

class IncidentReportProvider with ChangeNotifier {
  final IncidentReportService _service = IncidentReportService();

  List<IncidentReport> _reports = [];
  bool _isLoading = false;
  String? _error;

  List<IncidentReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyReports(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reports = await _service.getMyReports(userId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
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
    );
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
