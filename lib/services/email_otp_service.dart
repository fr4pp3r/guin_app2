import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guin_app/config/supabase_config.dart';

enum EmailOtpStatus { success, failure }

class EmailOtpResult {
  const EmailOtpResult({required this.status, this.message});

  final EmailOtpStatus status;
  final String? message;
}

/// Shaped like `SupabaseClient.functions.invoke` so tests can fake it.
typedef EmailOtpInvoke = Future<Object?> Function(
  String task, {
  Map<String, dynamic>? body,
});

/// Thin client for the `email-otp` Edge Function. Any exception or a response
/// without `ok == true` is a [EmailOtpStatus.failure]. [EmailOtpResult.message]
/// is debug context only — the UI must show a localized string, never this.
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
      (await SupabaseConfig.client.functions.invoke(task, body: body)).data;

  Future<EmailOtpResult> _run(Map<String, dynamic> body) async {
    try {
      final data = await _invoke('email-otp', body: body);
      if (data is Map && data['ok'] == true) {
        return const EmailOtpResult(status: EmailOtpStatus.success);
      }
      return EmailOtpResult(
        status: EmailOtpStatus.failure,
        message: _messageFrom(data) ?? _unavailable,
      );
    } on FunctionException catch (e) {
      debugPrint('EmailOtpService: ${body['action']} failed status=${e.status}');
      return EmailOtpResult(
        status: EmailOtpStatus.failure,
        message: _messageFrom(e.details) ?? _unavailable,
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

  /// Pulls `error.message` out of the function's error envelope, which arrives
  /// as a decoded map (JSON content type) or a raw JSON string depending on
  /// the transport path.
  static String? _messageFrom(Object? data) {
    Object? decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null;
      }
    }
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    return null;
  }
}
