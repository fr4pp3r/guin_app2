import 'package:guin_app/services/ai_service.dart';

/// AI-produced validation/normalization hints for a document request.
class DocumentProcessingSuggestion {
  const DocumentProcessingSuggestion({
    required this.issues,
    required this.suggestions,
    required this.normalizedPurpose,
  });

  final List<String> issues;
  final Map<String, String> suggestions;
  final String normalizedPurpose;

  /// Pure parser for the edge function's `result` map. Returns null when the
  /// result is missing or not a map so callers can silently fall back to the
  /// deterministic-validator-only path. Malformed fields are coerced safely.
  static DocumentProcessingSuggestion? fromResult(
    Map<String, dynamic>? result,
  ) {
    if (result == null) return null;

    final issues = <String>[];
    final rawIssues = result['issues'];
    if (rawIssues is List) {
      for (final item in rawIssues) {
        if (item is String && item.trim().isNotEmpty) {
          issues.add(item);
        }
      }
    }

    final suggestions = <String, String>{};
    final rawSuggestions = result['suggestions'];
    if (rawSuggestions is Map) {
      rawSuggestions.forEach((key, value) {
        if (key is String && value is String) {
          suggestions[key] = value;
        }
      });
    }

    final normalizedPurpose = result['normalizedPurpose'] is String
        ? result['normalizedPurpose'] as String
        : '';

    return DocumentProcessingSuggestion(
      issues: issues,
      suggestions: suggestions,
      normalizedPurpose: normalizedPurpose,
    );
  }
}

/// Validates/normalizes document request data via the `ai` edge function
/// (`document-processor` task). Degrades gracefully: any failure (AI
/// unavailable, slow, quota exhausted, bad payload) yields null and the
/// caller keeps the existing deterministic-validator-only flow.
class AiDocumentProcessor {
  AiDocumentProcessor({AiService? aiService})
      : _aiService = aiService ?? AiService();

  final AiService _aiService;

  Future<DocumentProcessingSuggestion?> process({
    required String documentType,
    required String purpose,
    required Map<String, dynamic> documentData,
  }) async {
    final result = await _aiService.invoke(
      'document-processor',
      {
        'documentType': documentType,
        'purpose': purpose,
        'documentData': documentData,
      },
      timeout: const Duration(seconds: 10),
    );
    return DocumentProcessingSuggestion.fromResult(result);
  }
}
