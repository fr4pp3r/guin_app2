import 'package:flutter/foundation.dart';
import 'package:guin_app/services/ai_service.dart';

/// Advisory hints from the `id-verifier` AI task for a self-registered
/// citizen.
///
/// This is ADVISORY ONLY: registration is always manually reviewed, so nothing
/// in this model approves anyone. Transient OCR text is intentionally NOT part
/// of it — the captured ID text is handed to the edge function as base64,
/// compared there, and only the verdicts (plus the non-PII metadata the
/// reviewer needs) come back.
///
/// There is no face-match field: the selfie is never compared to the face on
/// the ID, so this model carries no biometric judgement of that kind.
class IdVerificationSuggestion {
  const IdVerificationSuggestion({
    this.idAuthenticity,
    this.idTypeGuess,
    this.idTypeMatch,
    this.selfieQuality,
    this.spoofSignal,
    this.livenessNotes,
    this.fieldChecks,
    this.recommendation,
    this.reasons,
    this.promptVersion,
  });

  /// 'authentic' | 'suspicious' | 'unreadable' | 'uncertain' — whether the
  /// uploaded document is a plausible genuine ID of the DECLARED type.
  final String? idAuthenticity;

  /// What the document appears to be on its own merits; 'unknown' when it
  /// could not be identified at all.
  final String? idTypeGuess;

  /// Whether [idTypeGuess] agrees with the declared ID type. False for
  /// 'unknown' — an unidentified document is never a type match.
  final bool? idTypeMatch;

  /// 'good' | 'poor' | 'no_face' | 'uncertain' — usability of the selfie
  /// capture on its own technical merits.
  final String? selfieQuality;

  /// 'live_looking' | 'spoof_suspected' | 'uncertain' — passive anti-spoof
  /// signal over the selfie. A signal, not a proof of liveness.
  final String? spoofSignal;

  /// Optional short note attached to [spoofSignal] by the model.
  final String? livenessNotes;

  /// Per-form-field verdict: 'match' | 'mismatch' | 'unverifiable' for
  /// full_name, date_of_birth, address and gender.
  final Map<String, String>? fieldChecks;

  /// 'looks_ok' | 'needs_review' — the edge function's ADVISORY hint. Both
  /// outcomes still require human review; neither approves anything.
  final String? recommendation;

  /// Short plain-language notes for the reviewer (never model-decided approval
  /// text, never quoted PII).
  final List<String>? reasons;

  /// Prompt template version, so a suspicious verdict can be traced back.
  final String? promptVersion;

  /// True only when the edge function said the capture looks clean. Advisory:
  /// the caller still has to route the registration to a human.
  bool get looksOkay => recommendation == 'looks_ok';

  static const Set<String> _authenticities = {
    'authentic',
    'suspicious',
    'unreadable',
    'uncertain',
  };
  static const Set<String> _selfieQualities = {
    'good',
    'poor',
    'no_face',
    'uncertain',
  };
  static const Set<String> _spoofSignals = {
    'live_looking',
    'spoof_suspected',
    'uncertain',
  };
  static const Set<String> _recommendations = {'looks_ok', 'needs_review'};
  static const Set<String> _idTypeGuesses = {
    'barangay_id',
    'drivers_license',
    'passport',
    'national_id',
    'umid',
    'prc',
    'sss',
    'philhealth',
    'postal_id',
    'voters_id',
    'other',
    'unknown',
  };

  /// Pure parser for the edge function's `result` map. snake_case is the shape
  /// we persist (and therefore what the handler emits); camelCase aliases are
  /// tolerated because the older AI tasks (`document-processor`,
  /// `incident-classifier`) use them.
  ///
  /// Returns null only when the payload itself is missing — a field the model
  /// cannot use (unknown enum value, wrong type) is left null instead of
  /// failing the whole suggestion, so a partially degraded payload still helps
  /// the reviewer.
  static IdVerificationSuggestion? fromResult(Map<String, dynamic>? result) {
    if (result == null) return null;

    final liveness = _liveness(result['liveness']);

    return IdVerificationSuggestion(
      idAuthenticity: _knownValue(
        result['id_authenticity'] ?? result['idAuthenticity'],
        _authenticities,
      ),
      idTypeGuess: _knownValue(
        result['id_type_guess'] ?? result['idTypeGuess'],
        _idTypeGuesses,
      ),
      idTypeMatch: _coerceBool(result['id_type_match'] ?? result['idTypeMatch']),
      selfieQuality: _knownValue(
        result['selfie_quality'] ?? result['selfieQuality'],
        _selfieQualities,
      ),
      spoofSignal: _knownValue(
        liveness['spoof_signal'] ?? liveness['spoofSignal'],
        _spoofSignals,
      ),
      livenessNotes: _identifier(liveness['notes']),
      fieldChecks: _fieldChecks(
        result['field_checks'] ?? result['fieldChecks'],
      ),
      recommendation: _knownValue(result['recommendation'], _recommendations),
      reasons: _reasons(result['reasons']),
      promptVersion: _identifier(
        result['prompt_version'] ?? result['promptVersion'],
      ),
    );
  }

  /// PII-safe subset stored in `users_profile.kyc_ai_result`. Keys are stable
  /// snake_case so the admin review UI can render them without a migration;
  /// null fields are written as null so the key set never shifts. OCR text and
  /// image data can never appear here — the model never returns or stores them.
  Map<String, dynamic> toStoredJson() {
    return {
      'id_authenticity': idAuthenticity,
      'id_type_guess': idTypeGuess,
      'id_type_match': idTypeMatch,
      'selfie_quality': selfieQuality,
      'liveness': <String, dynamic>{
        'spoof_signal': spoofSignal,
        'notes': livenessNotes,
      },
      'field_checks': fieldChecks,
      'recommendation': recommendation,
      'reasons': reasons,
      'prompt_version': promptVersion,
    };
  }

  static String? _knownValue(Object? value, Set<String> allowed) {
    if (value is String && allowed.contains(value)) return value;
    return null;
  }

  static String? _identifier(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  /// Normalizes the nested `liveness` block to a plain map; anything else
  /// (null, missing, wrong type) yields an empty block so the caller never
  /// touches a non-map.
  static Map<dynamic, dynamic> _liveness(Object? value) {
    if (value is Map) return value;
    return const <dynamic, dynamic>{};
  }

  static Map<String, String>? _fieldChecks(Object? value) {
    if (value is! Map) return null;
    final checks = <String, String>{};
    value.forEach((dynamic key, dynamic raw) {
      if (key is! String || key.trim().isEmpty) return;
      final coerced = _coerceText(raw);
      if (coerced != null) checks[key] = coerced;
    });
    return checks;
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

  static List<String>? _reasons(Object? value) {
    if (value is! List) return null;
    final reasons = <String>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) reasons.add(item);
    }
    return reasons.isEmpty ? null : reasons;
  }
}

/// Sends a registering citizen's uploaded government ID (front, plus back when
/// the ID has two sides) and their live selfie to the `id-verifier` AI task.
///
/// Degrades exactly like the other AI wrappers: a missing required image, AI
/// unavailable, quota exhausted or an unusable payload all yield null, and the
/// caller falls back to the existing manual review queue. This class only ever
/// produces an ADVISORY 'looks_ok' hint — the decision belongs to the captain.
class AiIdVerifier {
  AiIdVerifier({AiService? aiService}) : _aiService = aiService ?? AiService();

  /// Edge task name; registered in `supabase/functions/ai/index.ts`.
  static const String task = 'id-verifier';

  final AiService _aiService;

  /// Runs the check. Returns the suggestion, or null when a mandatory input
  /// (ID front or selfie) is missing or the AI is unavailable — every one of
  /// those keeps the registration in the manual review queue.
  Future<IdVerificationSuggestion?> verify({
    required String idType,
    required String idFrontB64,
    String? idBackB64,
    required String selfieB64,
    required Map<String, String> formFields,
  }) async {
    // The edge function rejects an empty id_type or image string with a 400,
    // which would burn quota on a payload that cannot succeed. The ID back is
    // optional: single-sided IDs (passports) have none.
    if (idType.trim().isEmpty ||
        idFrontB64.isEmpty ||
        selfieB64.isEmpty) {
      debugPrint(
        'AiIdVerifier: ID type, ID front and selfie are all required; '
        'registration stays manual',
      );
      return null;
    }

    final result = await _aiService.invoke(task, {
      'id_type': idType,
      'id_image_front_b64': idFrontB64,
      if (idBackB64 != null && idBackB64.isNotEmpty)
        'id_image_back_b64': idBackB64,
      'selfie_b64': selfieB64,
      'form_fields': formFields,
    }, timeout: const Duration(seconds: 15));

    final suggestion = IdVerificationSuggestion.fromResult(result);
    if (suggestion == null) {
      debugPrint(
        'AiIdVerifier: no usable id-verifier result; registration '
        'stays manual',
      );
    }
    return suggestion;
  }
}