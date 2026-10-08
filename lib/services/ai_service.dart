import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client for the `ai` Supabase Edge Function.
///
/// Every AI feature goes through [invoke]. On ANY failure (network error,
/// timeout, 401, 429, 501, ...) it returns `null` — callers must treat null as
/// "AI unavailable" and fall back to the normal non-AI path. The core workflow
/// must never be blocked by an AI failure.
class AiService {
  AiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> invoke(
    String task,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final response = await _client.functions
          .invoke('ai', body: {'task': task, 'payload': payload})
          .timeout(timeout);
      final body = response.data is String
          ? response.data as String
          : jsonEncode(response.data);
      final parsed = AiService.unwrapResponse(response.status, body);
      if (parsed == null) {
        debugPrint('AiService: task=$task returned unusable response '
            '(status ${response.status})');
      }
      return parsed;
    } on FunctionException catch (e) {
      debugPrint('AiService: task=$task failed status=${e.status} '
          'reason=${e.reasonPhrase}');
      final details = e.details;
      final body = details is String ? details : jsonEncode(details ?? {});
      return AiService.unwrapResponse(e.status, body);
    } catch (e) {
      debugPrint('AiService: task=$task invoke error: $e');
      return null;
    }
  }

  /// Pure parsing/unwrapping of the edge function's response. Returns the
  /// unwrapped result map on success, `null` on any failure. Unit-testable
  /// without Supabase.
  static Map<String, dynamic>? unwrapResponse(int statusCode, String body) {
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
    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    return decoded;
  }
}
