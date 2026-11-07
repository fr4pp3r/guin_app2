import 'package:flutter/foundation.dart';
import 'package:guin_app/services/ai_service.dart';

/// Advisory verdict from the `residency-verifier` AI task on a self-uploaded
/// proof image (utility bill / secondary ID).
///
/// Like [IdVerificationSuggestion], this is ADVISORY ONLY: an officer still
/// has to confirm or reject. The wrapper never blocks — any failure yields
/// null and the caller falls back to the manual review queue.
class ResidencyVerificationSuggestion {
  const ResidencyVerificationSuggestion({
    required this.isConfirmed,
    required this.addressMatch,
    required this.notes,
    required this.confidence,
  });

  /// Whether the document's address points to Poblacion.
  final bool isConfirmed;

  /// Human-readable description of the address match
  /// (e.g. 'exact', 'partial', 'no_match', 'unreadable').
  final String addressMatch;

  final List<String> notes;

  /// 0.0–1.0 confidence score.
  final double confidence;

  /// Tolerant parser: missing fields fall back to safe defaults so a degraded
  /// payload still helps the reviewer instead of being discarded.
  static ResidencyVerificationSuggestion? fromResult(
    Map<String, dynamic>? result,
  ) {
    if (result == null) return null;

    final isConfirmedRaw = result['is_confirmed'] ?? result['isConfirmed'];
    final isConfirmed = _coerceBool(isConfirmedRaw) ?? false;

    final addressMatch = _coerceText(result['address_match'] ?? result['addressMatch']);

    final notes = _reasons(result['notes']);

    final confidence = _coerceDouble(result['confidence']);

    return ResidencyVerificationSuggestion(
      isConfirmed: isConfirmed,
      addressMatch: addressMatch ?? 'unknown',
      notes: notes ?? const <String>[],
      confidence: confidence ?? 0.0,
    );
  }

  Map<String, dynamic> toStoredJson() {
    return {
      'is_confirmed': isConfirmed,
      'address_match': addressMatch,
      'notes': notes,
      'confidence': confidence,
    };
  }

  static bool? _coerceBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    if (value is num) return value != 0;
    return null;
  }

  static String? _coerceText(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  static double? _coerceDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      return parsed;
    }
    return null;
  }

  static List<String>? _reasons(Object? value) {
    if (value is! List) return null;
    final notes = <String>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) notes.add(item);
    }
    return notes.isEmpty ? null : notes;
  }
}

/// Sends a self-uploaded proof image (base64) + the registrant's full name to
/// the `residency-verifier` AI task.
///
/// Degrades exactly like [AiIdVerifier]: a missing input, AI unavailable,
/// quota exhausted or unusable payload all yield null — the caller treats
/// null as "AI unavailable" and routes to the manual review queue.
class AiResidencyVerifier {
  AiResidencyVerifier({AiService? aiService})
      : _aiService = aiService ?? AiService();

  /// Edge task name; registered in `supabase/functions/ai/index.ts`.
  static const String task = 'residency-verifier';

  final AiService _aiService;

  /// Runs the check. Returns the suggestion, or null when the mandatory
  /// proof image is missing or the AI is unavailable.
  Future<ResidencyVerificationSuggestion?> verify({
    required String proofB64,
    required String fullName,
    String? documentType,
  }) async {
    if (proofB64.isEmpty) {
      debugPrint(
        'AiResidencyVerifier: proof image is required; '
        'residency stays unverified',
      );
      return null;
    }

    final payload = <String, dynamic>{
      'proof_b64': proofB64,
      'full_name': fullName,
    };
    if (documentType != null && documentType.trim().isNotEmpty) {
      payload['document_type'] = documentType;
    }

    final result = await _aiService.invoke(task, payload,
        timeout: const Duration(seconds: 15));

    final suggestion = ResidencyVerificationSuggestion.fromResult(result);
    if (suggestion == null) {
      debugPrint(
        'AiResidencyVerifier: no usable residency-verifier result; '
        'stays unverified',
      );
    }
    return suggestion;
  }
}