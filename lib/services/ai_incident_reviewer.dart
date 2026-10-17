import 'package:flutter/foundation.dart';

import 'ai_service.dart';

class IncidentReview {
  final String summary;
  final String riskLevel;
  final String escalationRecommended;
  final String reviewNotes;
  final List<String> suggestedNextSteps;

  const IncidentReview({
    required this.summary,
    required this.riskLevel,
    required this.escalationRecommended,
    required this.reviewNotes,
    this.suggestedNextSteps = const [],
  });

  factory IncidentReview.fromMap(Map<String, dynamic> map) {
    final summary = map['summary'] is String
        ? (map['summary'] as String).trim()
        : 'AI analysis generated for this incident report.';
    final riskLevel = map['riskLevel'] is String
        ? (map['riskLevel'] as String).trim().toLowerCase()
        : 'low';
    final escalationRecommended = map['escalationRecommended'] is String
        ? (map['escalationRecommended'] as String).trim().toLowerCase()
        : 'review';
    final reviewNotes = map['reviewNotes'] is String
        ? (map['reviewNotes'] as String).trim()
        : 'No additional review notes.';

    final List<String> steps = [];
    final rawSteps = map['suggestedNextSteps'];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        if (s is String && s.trim().isNotEmpty) {
          steps.add(s.trim());
        }
      }
    }

    return IncidentReview(
      summary: summary,
      riskLevel: riskLevel,
      escalationRecommended: escalationRecommended,
      reviewNotes: reviewNotes,
      suggestedNextSteps: steps,
    );
  }
}

class AiIncidentReviewer {
  AiIncidentReviewer({AiService? service}) : _service = service ?? AiService();

  final AiService _service;

  Future<IncidentReview?> review({
    required String title,
    required String description,
    String location = '',
    String reportType = '',
    String priority = '',
    bool isSensitive = false,
    bool isAnonymous = false,
  }) async {
    try {
      final result = await _service.invoke(
        'incident-reviewer',
        {
          'title': title,
          'description': description,
          'location': location,
          'reportType': reportType,
          'priority': priority,
          'isSensitive': isSensitive,
          'isAnonymous': isAnonymous,
        },
        timeout: const Duration(seconds: 30),
      );
      if (result == null) return null;
      return IncidentReview.fromMap(result);
    } catch (e) {
      debugPrint('AiIncidentReviewer.review error: $e');
      return null;
    }
  }
}
