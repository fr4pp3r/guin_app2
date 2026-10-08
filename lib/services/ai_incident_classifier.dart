import 'package:guin_app/services/ai_service.dart';

/// Suggested classification for an incident report.
class IncidentSuggestion {
  const IncidentSuggestion({
    required this.reportType,
    required this.priority,
    required this.rationale,
  });

  final String reportType;
  final String priority;
  final String rationale;

  static const Set<String> _reportTypes = {
    'complaint',
    'disturbance',
    'threat',
    'emergency',
    'other',
  };

  static const Set<String> _priorities = {
    'low',
    'normal',
    'high',
    'urgent',
  };

  /// Pure parser for the edge function's `result` map. Returns null when the
  /// shape is invalid so callers can silently fall back to the manual path.
  static IncidentSuggestion? fromResult(Map<String, dynamic>? result) {
    if (result == null) return null;
    final reportType = result['reportType'];
    final priority = result['priority'];
    final rationale = result['rationale'];
    if (reportType is! String || !_reportTypes.contains(reportType)) {
      return null;
    }
    if (priority is! String || !_priorities.contains(priority)) {
      return null;
    }
    if (rationale is! String) {
      return null;
    }
    return IncidentSuggestion(
      reportType: reportType,
      priority: priority,
      rationale: rationale,
    );
  }
}

/// Suggests report_type + priority for an incident via the `ai` edge
/// function. Degrades gracefully: any failure (AI unavailable, slow, quota
/// exhausted, bad payload) yields null and the caller keeps the manual flow.
class AiIncidentClassifier {
  AiIncidentClassifier({AiService? aiService})
      : _aiService = aiService ?? AiService();

  final AiService _aiService;

  Future<IncidentSuggestion?> suggest(String title, String description) async {
    final result = await _aiService.invoke(
      'incident-classifier',
      {'title': title, 'description': description},
      timeout: const Duration(seconds: 10),
    );
    return IncidentSuggestion.fromResult(result);
  }
}
