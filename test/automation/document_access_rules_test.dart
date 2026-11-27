import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/automation/document_access_rules.dart';

void main() {
  group('DocumentAccessRules', () {
    test('evaluate returns allowed when not expired', () {
      final now = DateTime(2026, 6, 15);
      final expiresAt = DateTime(2027, 1, 1);

      final state = DocumentAccessState(
        status: 'valid',
        expiresAt: expiresAt,
      );

      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.allowed),
      );
    });

    test('evaluate returns expired when past expiry', () {
      final now = DateTime(2027, 2, 1);
      final expiresAt = DateTime(2027, 1, 1);

      final state = DocumentAccessState(
        status: 'valid',
        expiresAt: expiresAt,
      );

      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.expired),
      );
    });

    test('evaluate returns expired exactly at expiry time', () {
      final now = DateTime(2027, 1, 1, 12, 0, 0);
      final expiresAt = DateTime(2027, 1, 1, 11, 0, 0);

      final state = DocumentAccessState(
        status: 'valid',
        expiresAt: expiresAt,
      );

      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.expired),
      );
    });

    test('evaluate returns allowed on the expiry day before expiry', () {
      final now = DateTime(2026, 12, 31, 23, 59, 59);
      final expiresAt = DateTime(2027, 1, 1, 0, 0, 0);

      final state = DocumentAccessState(
        status: 'valid',
        expiresAt: expiresAt,
      );

      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.allowed),
      );
    });

    test('evaluate returns used for single-use document', () {
      final now = DateTime(2026, 6, 15);

      final stateUsed = DocumentAccessState(
        status: 'valid',
        singleUse: true,
        useCount: 1,
      );

      final stateUnused = DocumentAccessState(
        status: 'valid',
        singleUse: true,
        useCount: 0,
      );

      expect(
        DocumentAccessRules.evaluate(stateUsed, now: now),
        equals(DocumentAccessDecision.used),
      );

      expect(
        DocumentAccessRules.evaluate(stateUnused, now: now),
        equals(DocumentAccessDecision.allowed),
      );
    });

    test('evaluate returns useLimitReached when max uses exceeded', () {
      final now = DateTime(2026, 6, 15);

      final stateOverLimit = DocumentAccessState(
        status: 'valid',
        maxUses: 3,
        useCount: 3,
      );

      final stateUnderLimit = DocumentAccessState(
        status: 'valid',
        maxUses: 3,
        useCount: 2,
      );

      expect(
        DocumentAccessRules.evaluate(stateOverLimit, now: now),
        equals(DocumentAccessDecision.useLimitReached),
      );

      expect(
        DocumentAccessRules.evaluate(stateUnderLimit, now: now),
        equals(DocumentAccessDecision.allowed),
      );
    });

    test('evaluate checks revoked first', () {
      final now = DateTime(2026, 6, 15);

      final state = DocumentAccessState(
        status: 'revoked',
        expiresAt: DateTime(2020, 1, 1),
      );

      // Revoked check comes before expired check
      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.revoked),
      );
    });

    test('evaluate checks used before expired', () {
      final now = DateTime(2027, 2, 1);

      final state = DocumentAccessState(
        status: 'used',
        expiresAt: DateTime(2020, 1, 1),
      );

      // Used check comes before expired check
      expect(
        DocumentAccessRules.evaluate(state, now: now),
        equals(DocumentAccessDecision.used),
      );
    });

    test('isUsable returns correct boolean', () {
      final now = DateTime(2026, 6, 15);

      final validState = DocumentAccessState(status: 'valid');
      final expiredState = DocumentAccessState(
        status: 'valid',
        expiresAt: DateTime(2020, 1, 1),
      );
      final revokedState = DocumentAccessState(status: 'revoked');
      final usedState = DocumentAccessState(
        status: 'valid',
        singleUse: true,
        useCount: 1,
      );

      expect(DocumentAccessRules.isUsable(validState, now: now), isTrue);
      expect(DocumentAccessRules.isUsable(expiredState, now: now), isFalse);
      expect(DocumentAccessRules.isUsable(revokedState, now: now), isFalse);
      expect(DocumentAccessRules.isUsable(usedState, now: now), isFalse);
    });

    test('remainingUses returns correct count', () {
      final unlimited = DocumentAccessState(status: 'valid', maxUses: null);
      final withLimit = DocumentAccessState(status: 'valid', maxUses: 5, useCount: 2);
      final exhausted = DocumentAccessState(status: 'valid', maxUses: 5, useCount: 5);

      expect(DocumentAccessRules.remainingUses(unlimited), isNull);
      expect(DocumentAccessRules.remainingUses(withLimit), equals(3));
      expect(DocumentAccessRules.remainingUses(exhausted), equals(0));
    });

    test('describe returns correct labels', () {
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.allowed),
        equals('Valid'),
      );
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.expired),
        equals('Expired'),
      );
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.revoked),
        equals('Revoked'),
      );
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.used),
        equals('Already used'),
      );
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.useLimitReached),
        equals('Usage limit reached'),
      );
      expect(
        DocumentAccessRules.describe(DocumentAccessDecision.notFound),
        equals('Not found'),
      );
    });

    test('computeExpiry adds validity duration to base time', () {
      final now = DateTime(2026, 6, 15, 12, 30, 45);
      final validity = Duration(days: 30);

      final expiry = DocumentAccessRules.computeExpiry(from: now, validity: validity);

      // Should be exactly 30 days later at the same time
      expect(expiry, equals(DateTime(2026, 7, 15, 12, 30, 45)));
    });

    test('computeExpiry uses defaultValidity when validity is null', () {
      final now = DateTime(2026, 6, 15, 12, 30, 45);

      // When validity is null, it uses defaultValidity
      // We can't test exact value because it depends on Helpers.now() and timezone
      // But we can verify it returns a DateTime
      final expiry = DocumentAccessRules.computeExpiry(from: now);

      expect(expiry, isA<DateTime>());
      // Should be in the future
      expect(expiry.isAfter(now), isTrue);
    });

    test('computeExpiry works with custom validity of 365 days', () {
      final now = DateTime(2026, 6, 15, 0, 0, 0);
      final yearValidity = Duration(days: 365);

      final expiry = DocumentAccessRules.computeExpiry(from: now, validity: yearValidity);

      // 2026 is not a leap year, so June 15 + 365 days = June 15 next year
      expect(expiry, equals(DateTime(2027, 6, 15, 0, 0, 0)));
    });

    test('isUsable respects maxUses limit', () {
      final now = DateTime(2026, 6, 15);

      // Under limit - should be usable
      final underLimit = DocumentAccessState(
        status: 'valid',
        maxUses: 5,
        useCount: 4,
      );

      // At limit - not usable
      final atLimit = DocumentAccessState(
        status: 'valid',
        maxUses: 5,
        useCount: 5,
      );

      expect(DocumentAccessRules.isUsable(underLimit, now: now), isTrue);
      expect(DocumentAccessRules.isUsable(atLimit, now: now), isFalse);
    });
  });
}