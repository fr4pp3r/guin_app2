import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/face_gate.dart';
import 'package:guin_app/utils/image_compressor.dart';

/// Client for the `face-match` edge function: embeds a face on-device, then
/// verify/enroll/list/delete against the official enrollment store.
///
/// Mirrors `FaceMatchService`'s contract: null/false/[] on ANY failure
/// (unsupported platform, encoding, network, unexpected shape) — callers must
/// treat those as "gate not evaluated / action failed" and never crash. The
/// match threshold lives only in the edge function; the client consumes
/// [FaceGateResult.matched].
class FaceGateService {
  FaceGateService();

  /// Canonical enrollment key: `[given, middle, last]` trimmed, empty parts
  /// dropped, lowercased. The edge function normalizes the same way
  /// (trim + lowercase), so both sides agree on the lookup key.
  static String normalizeName(
    String givenName,
    String middleName,
    String lastName,
  ) =>
      [givenName, middleName, lastName]
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' ')
          .toLowerCase();

  /// Display-cased name (same as [normalizeName] without lowercasing) for
  /// the `full_name` column shown in the officials' enrollment list; the
  /// server derives `full_name_normalized` from it.
  static String displayName(
    String givenName,
    String middleName,
    String lastName,
  ) =>
      [givenName, middleName, lastName]
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' ');

  /// Embeds the single face in [imageFile]. Null on web/desktop, when the
  /// image does not contain exactly one face, or on any detector error.
  Future<List<double>?> embedFromFile(File imageFile) async {
    // Native TFLite only: web/desktop throw from the embedding APIs.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint(
        'FaceGateService: skipped on unsupported platform — returning null',
      );
      return null;
    }
    try {
      final detector = await FaceDetector.create();
      try {
        final bytes = await imageFile.readAsBytes();
        final faces = await detector.detectFacesFromBytes(
          bytes,
          mode: FaceDetectionMode.full,
        );
        if (faces.length != 1) {
          debugPrint(
            'FaceGateService: need exactly one face (found ${faces.length}) '
            '— returning null',
          );
          return null;
        }
        return await detector.getFaceEmbedding(faces.single, bytes);
      } finally {
        await detector.dispose();
      }
    } catch (e) {
      debugPrint('FaceGateService: embed failed — returning null. ($e)');
      return null;
    }
  }

  Future<FaceGateResult?> verify({
    required String fullName,
    required List<double> embedding,
  }) async {
    try {
      final data = await SupabaseConfig.client.functions
          .invoke(
            'face-match',
            body: {
              'action': 'verify',
              'fullName': fullName,
              'embedding': embedding,
            },
          )
          .timeout(const Duration(seconds: 25));
      final json = data.data;
      if (json is Map && json['ok'] == true) {
        return FaceGateResult.fromJson(Map<String, dynamic>.from(json));
      }
      debugPrint('FaceGateService: verify rejected — returning null');
      return null;
    } on FunctionException catch (e) {
      debugPrint(
        'FaceGateService: verify failed status=${e.status} — returning null',
      );
      return null;
    } catch (e) {
      debugPrint('FaceGateService: verify failed: $e — returning null');
      return null;
    }
  }

  Future<bool> enroll({
    required String givenName,
    required String middleName,
    required String lastName,
    required DateTime dob,
    required File photo,
    required List<double> embedding,
    String? enrolledBy,
  }) async {
    try {
      final photoBase64 = await ImageCompressor.toBase64Png(photo);
      if (photoBase64 == null) {
        debugPrint(
          'FaceGateService: enroll photo could not be encoded — returning false',
        );
        return false;
      }
      final data = await SupabaseConfig.client.functions
          .invoke(
            'face-match',
            body: {
              'action': 'enroll',
              'fullName': displayName(givenName, middleName, lastName),
              'dob': dob.toIso8601String().split('T').first,
              'embedding': embedding,
              'photoBase64': photoBase64,
              'enrolledBy': ?enrolledBy,
            },
          )
          .timeout(const Duration(seconds: 25));
      final json = data.data;
      return json is Map && json['ok'] == true;
    } on FunctionException catch (e) {
      debugPrint(
        'FaceGateService: enroll failed status=${e.status} — returning false',
      );
      return false;
    } catch (e) {
      debugPrint('FaceGateService: enroll failed: $e — returning false');
      return false;
    }
  }

  Future<List<FaceEnrollment>> listEnrollments() async {
    try {
      final data = await SupabaseConfig.client.functions
          .invoke('face-match', body: {'action': 'list'})
          .timeout(const Duration(seconds: 25));
      final json = data.data;
      if (json is Map && json['ok'] == true && json['enrollments'] is List) {
        return [
          for (final row in json['enrollments'] as List)
            if (row is Map)
              FaceEnrollment.fromJson(Map<String, dynamic>.from(row)),
        ];
      }
      debugPrint('FaceGateService: list rejected — returning []');
      return const [];
    } on FunctionException catch (e) {
      debugPrint(
        'FaceGateService: list failed status=${e.status} — returning []',
      );
      return const [];
    } catch (e) {
      debugPrint('FaceGateService: list failed: $e — returning []');
      return const [];
    }
  }

  Future<bool> deleteEnrollment(String id) async {
    try {
      final data = await SupabaseConfig.client.functions
          .invoke('face-match', body: {'action': 'delete', 'id': id})
          .timeout(const Duration(seconds: 25));
      final json = data.data;
      return json is Map && json['ok'] == true;
    } on FunctionException catch (e) {
      debugPrint(
        'FaceGateService: delete failed status=${e.status} — returning false',
      );
      return false;
    } catch (e) {
      debugPrint('FaceGateService: delete failed: $e — returning false');
      return false;
    }
  }
}
