import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guin_app/config/supabase_config.dart';

enum EmailOtpStatus { success, failure }

class EmailOtpResult {
  const EmailOtpResult({required this.status, this.code, this.message});

  final EmailOtpStatus status;
  final String? code;
  final String? message;
}

/// Shaped like `SupabaseClient.functions.invoke` so tests can fake it.
typedef EmailOtpInvoke = Future<Object?> Function(
  String task, {
  Map<String, dynamic>? body,
});

/// Thin client for the `email-otp` Edge Function. Any exception or a response
/// without `ok == true` is a [EmailOtpStatus.failure]. [EmailOtpResult.code]
/// is the machine error code (e.g. `rate_limited`) the UI may branch on;
/// [EmailOtpResult.message] stays debug-only.
class EmailOtpService {
  EmailOtpService({EmailOtpInvoke? invoke}) : _invoke = invoke ?? _defaultInvoke;

  final EmailOtpInvoke _invoke;

  Future<EmailOtpResult> sendCode(String email) =>
      _run({'action': 'send', 'email': email});

  Future<EmailOtpResult> verifyCode(String email, String code) =>
      _run({'action': 'verify', 'email': email, 'code': code});

  static Future<Object?> _defaultInvoke(
    String task, {
    Map<String, dynamic>? body,
  }) async =>
      (await SupabaseConfig.client.functions
              .invoke(task, body: body)
              .timeout(const Duration(seconds: 25)))
          .data;

  Future<EmailOtpResult> _run(Map<String, dynamic> body) async {
    try {
      final data = await _invoke('email-otp', body: body);
      if (data is Map && data['ok'] == true) {
        return const EmailOtpResult(status: EmailOtpStatus.success);
      }
      final error = _errorFrom(data);
      return EmailOtpResult(
        status: EmailOtpStatus.failure,
        code: error.code,
        message: error.message ?? _unavailable,
      );
    } on FunctionException catch (e) {
      debugPrint('EmailOtpService: ${body['action']} failed status=${e.status}');
      final error = _errorFrom(e.details);
      return EmailOtpResult(
        status: EmailOtpStatus.failure,
        code: error.code,
        message: error.message ?? _unavailable,
      );
    } catch (e) {
      debugPrint('EmailOtpService: ${body['action']} failed: $e');
      return const EmailOtpResult(
        status: EmailOtpStatus.failure,
        message: _unavailable,
      );
    }
  }

  static const _unavailable = 'Email verification is unavailable';

  /// Pulls the `{ error: { code, message } }` envelope out of the function's
  /// error response, which arrives as a decoded map (JSON content type) or a
  /// raw JSON string depending on the transport path.
  static ({String? code, String? message}) _errorFrom(Object? data) {
    Object? decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return (code: null, message: null);
      }
    }
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        final code = error['code'];
        final message = error['message'];
        return (
          code: code is String && code.isNotEmpty ? code : null,
          message: message is String && message.isNotEmpty ? message : null,
        );
      }
    }
    return (code: null, message: null);
  }
}
