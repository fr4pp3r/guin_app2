import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/residency_proof.dart';

/// CRUD for `document_residency_proofs` + the `residency-proofs` storage bucket.
///
/// The bucket itself must be created manually in the Supabase console
/// (no setup.sql storage policy list — see the Task 3 report). Confirming a
/// proof flips `users_profile.is_poblacion_resident = true`; rejecting sets
/// status 'rejected'. Neither blocks the caller — errors propagate so the UI
/// can surface them, but the AI lanes that call this never depend on it.
class ResidencyProofService {
  ResidencyProofService({SupabaseClient? client})
      : _supabase = client ?? SupabaseConfig.client;

  static const String _bucket = 'residency-proofs';
  static const String _table = 'document_residency_proofs';

  final SupabaseClient _supabase;

  /// Upload a proof image and insert a 'pending' row.
  ///
  /// Path is `userId/proof.jpg` (single-slot per user — a new upload
  /// supersedes the previous one; old URLs are left to expire).
  Future<ResidencyProof> uploadProof({
    required String userId,
    required File image,
    required String documentType,
  }) async {
    final path = '$userId/proof.jpg';
    await _supabase.storage.from(_bucket).upload(path, image);

    final proofUrl = _supabase.storage.from(_bucket).getPublicUrl(path);

    final row = await _supabase
        .from(_table)
        .insert({
          'user_id': userId,
          'proof_url': proofUrl,
          'status': ResidencyProof.pending,
          'auditor_notes': null,
        })
        .select()
        .single();

    return ResidencyProof.fromJson(row);
  }

  /// Every proof row for a user, newest first.
  Future<List<ResidencyProof>> getProofsByUser(String userId) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ResidencyProof.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Officer confirms: status → 'confirmed', verified_at = now, and
  /// `users_profile.is_poblacion_resident = true`.
  Future<ResidencyProof> confirmProof({
    required String proofId,
    required String userId,
    String? auditorNotes,
  }) async {
    final now = DateTime.now().toIso8601String();

    final row = await _supabase
        .from(_table)
        .update({
          'status': ResidencyProof.confirmed,
          'verified_at': now,
          'auditor_notes': auditorNotes,
        })
        .eq('id', proofId)
        .select()
        .single();

    // Flip the profile flag. Best-effort: a proof row that can't propagate
    // still records the confirmation.
    try {
      await _supabase
          .from('users_profile')
          .update({'is_poblacion_resident': true})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ResidencyProofService: confirmProof failed to flip '
          'is_poblacion_resident for $userId: $e');
    }

    return ResidencyProof.fromJson(row);
  }

  /// Officer rejects: status → 'rejected', verified_at = now.
  Future<ResidencyProof> rejectProof({
    required String proofId,
    required String userId,
    String? auditorNotes,
  }) async {
    final now = DateTime.now().toIso8601String();

    final row = await _supabase
        .from(_table)
        .update({
          'status': ResidencyProof.rejected,
          'verified_at': now,
          'auditor_notes': auditorNotes,
        })
        .eq('id', proofId)
        .select()
        .single();

    // Rejecting a proof leaves the user unverified — no profile flip.
    return ResidencyProof.fromJson(row);
  }
}