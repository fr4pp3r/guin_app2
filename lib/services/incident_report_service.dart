import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/utils/helpers.dart';

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
    
    // Generate content hash for duplicate detection
    final contentHash = _computeContentHash(title, description, location);
    
    final response = await _supabase.from('incident_reports').insert({
      'submitted_by': submittedBy,
      'report_number': 'IR-${Helpers.now().year}-${Helpers.now().millisecondsSinceEpoch}',
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
      'content_hash': contentHash,
      'submission_metadata': {
        'client_timestamp': DateTime.now().toIso8601String(),
        'title_length': title.length,
        'description_length': description.length,
        'has_location': location.isNotEmpty,
        'has_gps': latitude != null && longitude != null,
      },
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    }).select().single();
    return IncidentReport.fromJson(response);
  }

  /// Compute a simple hash of title+description+location for deduplication.
  /// Uses a deterministic hash that doesn't require crypto.
  String _computeContentHash(String title, String description, String location) {
    final combined = '$title|$description|$location';
    // Simple hash using string code units
    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash + combined.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return 'dup_${hash.toRadixString(16)}';
  }

  /// Check if a similar report exists within the last hour (duplicate detection).
  Future<bool> isDuplicateContent(String title, String description, String location, {Duration window = const Duration(hours: 1)}) {
    final contentHash = _computeContentHash(title, description, location);
    final cutoff = DateTime.now().subtract(window).toIso8601String();
    return _supabase.from('incident_reports').select('id').eq('content_hash', contentHash).gte('created_at', cutoff).then((list) => (list as List).isNotEmpty);
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
      if (newStatus == 'received') 'received_at': Helpers.now().toIso8601String(),
      if (newStatus == 'resolved') 'resolved_by': updatedBy,
      if (newStatus == 'resolved') 'resolved_at': Helpers.now().toIso8601String(),
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
