import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/services/email_otp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmailOtpService', () {
    test('sendCode returns success and posts the send body', () async {
      String? capturedTask;
      Map<String, dynamic>? capturedBody;
      final service = EmailOtpService(
        invoke: (task, {body}) async {
          capturedTask = task;
          capturedBody = body;
          return <String, dynamic>{'ok': true};
        },
      );

      final result = await service.sendCode('resident@example.com');

      expect(result.status, EmailOtpStatus.success);
      expect(result.message, isNull);
      expect(capturedTask, 'email-otp');
      expect(capturedBody, <String, dynamic>{'action': 'send', 'email': 'resident@example.com'});
    });

    test('verifyCode returns success and posts the verify body', () async {
      Map<String, dynamic>? capturedBody;
      final service = EmailOtpService(
        invoke: (task, {body}) async {
          capturedBody = body;
          return <String, dynamic>{'ok': true};
        },
      );

      final result = await service.verifyCode('resident@example.com', '123456');

      expect(result.status, EmailOtpStatus.success);
      expect(capturedBody, <String, dynamic>{
        'action': 'verify',
        'email': 'resident@example.com',
        'code': '123456',
      });
    });

    test('verifyCode returns failure with a message when invoke throws',
        () async {
      final service = EmailOtpService(
        invoke: (task, {body}) async {
          // Shape mirrors functions_client 2.x: non-2xx → FunctionException
          // with the decoded error envelope in details.
          throw const FunctionException(
            status: 400,
            reasonPhrase: 'Bad Request',
            details: <String, dynamic>{
              'error': {'code': 'invalid_code', 'message': 'Invalid or expired code'},
            },
          );
        },
      );

      final result = await service.verifyCode('resident@example.com', '000000');

      expect(result.status, EmailOtpStatus.failure);
      expect(result.message, 'Invalid or expired code');
    });

    test('verifyCode returns failure with a message on a network error',
        () async {
      final service = EmailOtpService(
        invoke: (task, {body}) async => throw Exception('Network unreachable'),
      );

      final result = await service.verifyCode('resident@example.com', '000000');

      expect(result.status, EmailOtpStatus.failure);
      expect(result.message, isNotNull);
    });

    test('a response body without ok is treated as failure', () async {
      final service = EmailOtpService(
        invoke: (task, {body}) async => <String, dynamic>{'unexpected': true},
      );

      final result = await service.sendCode('resident@example.com');

      expect(result.status, EmailOtpStatus.failure);
      expect(result.message, isNotNull);
    });

    test('a non-ok error envelope surfaces the server message', () async {
      final service = EmailOtpService(
        invoke: (task, {body}) async => <String, dynamic>{
          'error': {'code': 'rate_limited', 'message': 'Please wait a minute'},
        },
      );

      final result = await service.sendCode('resident@example.com');

      expect(result.status, EmailOtpStatus.failure);
      expect(result.message, 'Please wait a minute');
    });

    test('a non-ok error envelope surfaces the server error code', () async {
      final service = EmailOtpService(
        invoke: (task, {body}) async => <String, dynamic>{
          'error': {'code': 'too_many_attempts', 'message': 'Too many attempts'},
        },
      );

      final result = await service.sendCode('resident@example.com');

      expect(result.status, EmailOtpStatus.failure);
      expect(result.code, 'too_many_attempts');
    });
  });
}
