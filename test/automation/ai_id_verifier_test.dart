import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/services/ai_id_verifier.dart';

/// A complete, well-formed `id-verifier` result payload — the shape the edge
/// function emits and the shape we persist.
Map<String, dynamic> payload() => <String, dynamic>{
  'id_authenticity': 'authentic',
  'id_type_guess': 'passport',
  'id_type_match': true,
  'selfie_quality': 'good',
  'liveness': <String, dynamic>{
    'spoof_signal': 'live_looking',
    'notes': 'no screen artefacts visible',
  },
  'field_checks': <String, dynamic>{
    'full_name': 'match',
    'date_of_birth': 'match',
    'address': 'unverifiable',
    'gender': 'match',
  },
  'recommendation': 'looks_ok',
  'reasons': <dynamic>['layout and seal look right', 'name could not be read'],
  'prompt_version': 'v5',
};

void main() {
  group('IdVerificationSuggestion.fromResult', () {
    test('parses every field from a complete payload', () {
      final suggestion = IdVerificationSuggestion.fromResult(payload());

      expect(suggestion, isNotNull);
      expect(suggestion!.idAuthenticity, 'authentic');
      expect(suggestion.idTypeGuess, 'passport');
      expect(suggestion.idTypeMatch, isTrue);
      expect(suggestion.selfieQuality, 'good');
      expect(suggestion.spoofSignal, 'live_looking');
      expect(suggestion.livenessNotes, 'no screen artefacts visible');
      expect(suggestion.fieldChecks, <String, String>{
        'full_name': 'match',
        'date_of_birth': 'match',
        'address': 'unverifiable',
        'gender': 'match',
      });
      expect(suggestion.reasons, [
        'layout and seal look right',
        'name could not be read',
      ]);
      expect(suggestion.recommendation, 'looks_ok');
      expect(suggestion.promptVersion, 'v5');
      expect(suggestion.looksOkay, isTrue);
    });

    test('accepts the needs_review recommendation', () {
      final raw = payload()..['recommendation'] = 'needs_review';

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.recommendation, 'needs_review');
      expect(suggestion.looksOkay, isFalse);
    });

    test('accepts camelCase aliases used by the older AI tasks', () {
      final raw = <String, dynamic>{
        'idAuthenticity': 'suspicious',
        'idTypeGuess': 'sss',
        'idTypeMatch': 'false',
        'selfieQuality': 'poor',
        'liveness': <String, dynamic>{
          'spoof_signal': 'spoof_suspected',
          'notes': 'pixel-grid moire on the cheek',
        },
        'fieldChecks': <String, dynamic>{'full_name': 'mismatch'},
        'recommendation': 'needs_review',
        'promptVersion': 'v4',
      };

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.idAuthenticity, 'suspicious');
      expect(suggestion.idTypeGuess, 'sss');
      expect(suggestion.idTypeMatch, isFalse);
      expect(suggestion.selfieQuality, 'poor');
      expect(suggestion.spoofSignal, 'spoof_suspected');
      expect(suggestion.fieldChecks, <String, String>{
        'full_name': 'mismatch',
      });
      expect(suggestion.recommendation, 'needs_review');
      expect(suggestion.promptVersion, 'v4');
    });

    test('returns null when the result is missing', () {
      expect(IdVerificationSuggestion.fromResult(null), isNull);
    });

    test(
      'returns an all-null suggestion for an empty map instead of throwing',
      () {
        final suggestion = IdVerificationSuggestion.fromResult(
          const <String, dynamic>{},
        )!;

        expect(suggestion.idAuthenticity, isNull);
        expect(suggestion.idTypeGuess, isNull);
        expect(suggestion.idTypeMatch, isNull);
        expect(suggestion.selfieQuality, isNull);
        expect(suggestion.spoofSignal, isNull);
        expect(suggestion.livenessNotes, isNull);
        expect(suggestion.fieldChecks, isNull);
        expect(suggestion.recommendation, isNull);
        expect(suggestion.reasons, isNull);
        expect(suggestion.promptVersion, isNull);
        expect(suggestion.looksOkay, isFalse);
      },
    );

    test('nulls an id_authenticity value outside the known set', () {
      final raw = payload()..['id_authenticity'] = 'probably_fake';

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.idAuthenticity, isNull);
      expect(suggestion.idTypeGuess, 'passport');
      expect(suggestion.recommendation, 'looks_ok');
    });

    test('nulls a selfie_quality value outside the known set', () {
      final raw = payload()..['selfie_quality'] = 'ok';

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.selfieQuality, isNull);
      expect(suggestion.recommendation, 'looks_ok');
    });

    test('nulls a spoof_signal value outside the known set', () {
      final raw = payload()
        ..['liveness'] = <String, dynamic>{'spoof_signal': 'definitely_real'};

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.spoofSignal, isNull);
      expect(suggestion.livenessNotes, isNull);
    });

    test('nulls a recommendation outside the known set', () {
      final raw = payload()..['recommendation'] = 'auto_approve';

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.recommendation, isNull);
      expect(suggestion.looksOkay, isFalse);
      expect(suggestion.idAuthenticity, 'authentic');
    });

    test('accepts every accepted id_authenticity value', () {
      for (final value in [
        'authentic',
        'suspicious',
        'unreadable',
        'uncertain',
      ]) {
        final raw = payload()..['id_authenticity'] = value;

        expect(IdVerificationSuggestion.fromResult(raw)!.idAuthenticity, value);
      }
    });

    test('accepts every accepted selfie_quality value', () {
      for (final value in ['good', 'poor', 'no_face', 'uncertain']) {
        final raw = payload()..['selfie_quality'] = value;

        expect(
          IdVerificationSuggestion.fromResult(raw)!.selfieQuality,
          value,
        );
      }
    });

    test('accepts "unknown" as an id_type_guess', () {
      final raw = payload()..['id_type_guess'] = 'unknown';

      expect(IdVerificationSuggestion.fromResult(raw)!.idTypeGuess, 'unknown');
    });

    test('nulls an id_type_guess outside the known set', () {
      final raw = payload()..['id_type_guess'] = 'mayor_id';

      expect(IdVerificationSuggestion.fromResult(raw)!.idTypeGuess, isNull);
    });

    test('survives a missing or non-map liveness block', () {
      final missing = payload()..remove('liveness');
      final wrong = payload()..['liveness'] = 'live';

      expect(IdVerificationSuggestion.fromResult(missing)!.spoofSignal, isNull);
      expect(IdVerificationSuggestion.fromResult(wrong)!.spoofSignal, isNull);
    });

    test('coerces field_checks to strings and drops the rest', () {
      final raw = payload()
        ..['field_checks'] = <String, dynamic>{
          'full_name': 'match',
          'date_of_birth': '',
          'address': 42,
          '': 'match',
        };

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.fieldChecks, <String, String>{'full_name': 'match'});
    });

    test('nulls field_checks that are not a map', () {
      final raw = payload()..['field_checks'] = 'all fields matched';

      expect(IdVerificationSuggestion.fromResult(raw)!.fieldChecks, isNull);
    });

    test('nulls reasons that are not a list', () {
      final raw = payload()..['reasons'] = 'everything looked fine';

      expect(IdVerificationSuggestion.fromResult(raw)!.reasons, isNull);
    });

    test('drops empty and non-string entries from reasons', () {
      final raw = payload()
        ..['reasons'] = <dynamic>[
          'glare on the seal',
          '',
          '   ',
          42,
          null,
          'address not printed on the document',
        ];

      expect(IdVerificationSuggestion.fromResult(raw)!.reasons, [
        'glare on the seal',
        'address not printed on the document',
      ]);
    });

    test('nulls an empty reasons list and a non-string prompt_version', () {
      final raw = payload()
        ..['reasons'] = <dynamic>[]
        ..['prompt_version'] = 7;

      final suggestion = IdVerificationSuggestion.fromResult(raw)!;

      expect(suggestion.reasons, isNull);
      expect(suggestion.promptVersion, isNull);
    });
  });

  group('IdVerificationSuggestion.toStoredJson', () {
    test('keeps exactly the stable snake_case keys', () {
      final stored = IdVerificationSuggestion.fromResult(
        payload(),
      )!.toStoredJson();

      expect(stored.keys.toSet(), <String>{
        'id_authenticity',
        'id_type_guess',
        'id_type_match',
        'selfie_quality',
        'liveness',
        'field_checks',
        'recommendation',
        'reasons',
        'prompt_version',
      });
      expect(stored['id_authenticity'], 'authentic');
      expect(stored['id_type_guess'], 'passport');
      expect(stored['id_type_match'], isTrue);
      expect(stored['selfie_quality'], 'good');
      expect(
        stored['liveness'],
        <String, dynamic>{
          'spoof_signal': 'live_looking',
          'notes': 'no screen artefacts visible',
        },
      );
      expect(stored['field_checks'], <String, String>{
        'full_name': 'match',
        'date_of_birth': 'match',
        'address': 'unverifiable',
        'gender': 'match',
      });
      expect(stored['recommendation'], 'looks_ok');
      expect(stored['prompt_version'], 'v5');
    });

    test('never stores any face-match or template-match verdict', () {
      final raw = payload()
        ..['face_match'] = 'match'
        ..['template_match'] = 'match'
        ..['face_match_reasons'] = <dynamic>['same person'];

      final stored = IdVerificationSuggestion.fromResult(raw)!.toStoredJson();

      expect(stored.containsKey('face_match'), isFalse);
      expect(stored.containsKey('face_match_reasons'), isFalse);
      expect(stored.containsKey('template_match'), isFalse);
    });

    test('never leaks OCR text or image data', () {
      final raw = payload()
        ..['extracted'] = <String, dynamic>{
          'name': 'JUAN DELA CRUZ',
          'id_number': 'BRGY-2026-00123',
        }
        ..['id_image_front_b64'] = 'iVBORw0KGgoAAAANSUhEUg==';

      final stored = IdVerificationSuggestion.fromResult(raw)!.toStoredJson();

      expect(stored.containsKey('extracted'), isFalse);
      expect(stored.keys.any((key) => key.contains('b64')), isFalse);
      final encoded = jsonEncode(stored).toLowerCase();
      expect(encoded.contains('juan dela cruz'), isFalse);
      expect(encoded.contains('brgy-2026-00123'), isFalse);
    });

    test('keeps the same key set when every field is null', () {
      final stored = const IdVerificationSuggestion().toStoredJson();

      expect(stored.keys.toSet(), <String>{
        'id_authenticity',
        'id_type_guess',
        'id_type_match',
        'selfie_quality',
        'liveness',
        'field_checks',
        'recommendation',
        'reasons',
        'prompt_version',
      });
      expect(
        stored['liveness'],
        <String, dynamic>{'spoof_signal': null, 'notes': null},
      );
    });

    test('round-trips: stored JSON parses back into an equal suggestion', () {
      final original = IdVerificationSuggestion.fromResult(payload())!;
      final stored = original.toStoredJson();

      final reparsed = IdVerificationSuggestion.fromResult(stored)!;

      expect(reparsed.idAuthenticity, original.idAuthenticity);
      expect(reparsed.idTypeGuess, original.idTypeGuess);
      expect(reparsed.idTypeMatch, original.idTypeMatch);
      expect(reparsed.selfieQuality, original.selfieQuality);
      expect(reparsed.spoofSignal, original.spoofSignal);
      expect(reparsed.livenessNotes, original.livenessNotes);
      expect(reparsed.fieldChecks, original.fieldChecks);
      expect(reparsed.recommendation, original.recommendation);
      expect(reparsed.reasons, original.reasons);
      expect(reparsed.promptVersion, original.promptVersion);
      expect(reparsed.toStoredJson(), stored);
    });
  });

  group('IdVerificationSuggestion.looksOkay', () {
    test('is true only for the looks_ok recommendation', () {
      expect(
        IdVerificationSuggestion.fromResult(payload())!.looksOkay,
        isTrue,
      );

      final review = payload()..['recommendation'] = 'needs_review';
      expect(
        IdVerificationSuggestion.fromResult(review)!.looksOkay,
        isFalse,
      );

      expect(const IdVerificationSuggestion().looksOkay, isFalse);
    });
  });
}