import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client for the `captcha` Supabase Edge Function.
///
/// Sends a reCAPTCHA v2 token to the server for verification. On ANY failure
/// (network error, timeout, 401, 429, 501, ...) it returns `null` — callers
/// must treat null as "captcha unavailable" and block the submission.
/// Unlike AI features, captcha failure must NOT degrade to a fallback — it
/// must stop the form.
class CaptchaService {
  CaptchaService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Verify a reCAPTCHA v2 token server-side.
  ///
  /// Returns `true` on success, `null` on any failure. Callers MUST treat
  /// null as "do not proceed" — captcha is a hard gate.
  Future<bool?> verify(String token) async {
    try {
      final response = await _client.functions
          .invoke('captcha', body: {'token': token})
          .timeout(const Duration(seconds: 15));
      final body = response.data is String
          ? response.data as String
          : jsonEncode(response.data);
      final parsed = _unwrap(response.status, body);
      if (parsed == null) {
        debugPrint('CaptchaService: verify failed status=${response.status}');
      }
      return parsed;
    } on FunctionException catch (e) {
      debugPrint('CaptchaService: verify failed status=${e.status} '
          'reason=${e.reasonPhrase}');
      return null;
    } catch (e) {
      debugPrint('CaptchaService: verify error: $e');
      return null;
    }
  }

  /// Pure parsing of the edge function response. Returns `true` on success,
  /// `null` on any failure.
  static bool? _unwrap(int statusCode, String body) {
    if (body.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded.containsKey('error')) return null;
    if (statusCode < 200 || statusCode >= 300) return null;
    final ok = decoded['ok'];
    return ok is bool ? ok : null;
  }
}