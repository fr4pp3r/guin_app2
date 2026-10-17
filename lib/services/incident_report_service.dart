import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/incident_report.dart';

class IncidentReportService {
  final _supabase = SupabaseConfig.client;

  Future<IncidentReport> submitReport({
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
    final visibility = isAnonymous
        ? (isSensitive ? 'hidden_until_authorized' : 'restricted')
        : 'visible';
    final response = await _supabase.from('incident_reports').insert({
      'submitted_by': submittedBy,
      'report_number': 'IR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch}',
      'report_type': reportType,
      'title': title,
      'description': description,
      'location': location,
      'incident_datetime': incidentDateTime.toIso8601String(),
      'is_sensitive': isSensitive,
      'is_anonymous': isAnonymous,
      'identity_visibility': visibility,
      'priority': priority,
      'status': 'submitted',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    }).select().single();
    return IncidentReport.fromJson(response);
  }

  Future<List<IncidentReport>> getMyReports(String userId) async {
    final response = await _supabase
        .from('incident_reports')
        .select()
        .eq('submitted_by', userId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => IncidentReport.fromJson(json)).toList();
  }

  Future<List<IncidentReport>> getAllReports() async {
    final response = await _supabase
        .from('incident_reports')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => IncidentReport.fromJson(json)).toList();
  }

  Future<IncidentReport> updateStatus({
    required String reportId,
    required String updatedBy,
    required String newStatus,
    String? remarks,
  }) async {
    final current = await _supabase.from('incident_reports').select('status').eq('id', reportId).single();
    final response = await _supabase.from('incident_reports').update({
      'status': newStatus,
      if (newStatus == 'received') 'received_by': updatedBy,
      if (newStatus == 'received') 'received_at': DateTime.now().toIso8601String(),
      if (newStatus == 'resolved') 'resolved_by': updatedBy,
      if (newStatus == 'resolved') 'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId).select().single();

    await _supabase.from('incident_updates').insert({
      'incident_report_id': reportId,
      'updated_by': updatedBy,
      'old_status': current['status'],
      'new_status': newStatus,
      'remarks': remarks,
    });

    return IncidentReport.fromJson(response);
  }

  Future<void> logIdentityAccess({
    required String reportId,
    required String accessedBy,
    required String reason,
  }) async {
    await _supabase.from('identity_access_logs').insert({
      'incident_report_id': reportId,
      'accessed_by': accessedBy,
      'reason': reason,
    });
  }
}
