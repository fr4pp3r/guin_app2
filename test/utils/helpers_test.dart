import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/utils/helpers.dart';

void main() {
  group('Helpers.parseSupabaseError', () {
    test('recognizes offline / socket failures as a connection problem', () {
      for (final err in [
        'SocketException: Failed host lookup: example.supabase.co',
        'ClientException with SocketException',
        'Connection refused',
        'Connection timed out',
        'Network is unreachable',
      ]) {
        expect(
          Helpers.parseSupabaseError(err),
          contains('offline'),
          reason: 'expected "$err" to be treated as offline',
        );
      }
    });

    test('does not leak raw exception text for unknown errors', () {
      expect(
        Helpers.parseSupabaseError('SomeWeirdInternalFailure: xyz'),
        'An error occurred. Please try again',
      );
    });

    test('still maps known database errors', () {
      expect(
        Helpers.parseSupabaseError('duplicate key value violates email'),
        'Email already exists',
      );
      expect(Helpers.parseSupabaseError(null), 'An unknown error occurred');
    });
  });
}
