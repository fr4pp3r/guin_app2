import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/models/guarantor.dart';

class GuarantorService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Find approved citizens (potential guarantors) matching a name/username query.
  Future<List<UserProfile>> findApprovedGuarantors(String query) async {
    try {
      final pattern = '%${query.toLowerCase()}%';
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('role', 'citizen')
          .eq('is_approved', true)
          .or('full_name.ilike.$pattern,username.ilike.$pattern')
          .order('full_name', ascending: true)
          .limit(20);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Create a guarantor record linking an indigent registrant to an approved guarantor.
  Future<bool> createGuarantorRecord({
    required String indigentUserId,
    required String guarantorUserId,
    required String guarantorFullName,
    String? guarantorIdType,
    String? guarantorIdNumber,
    required String relationship,
  }) async {
    try {
      await _supabase.from('kyc_guarantors').insert({
        'indigent_user_id': indigentUserId,
        'guarantor_user_id': guarantorUserId,
        'guarantor_full_name': guarantorFullName,
        'guarantor_id_type': guarantorIdType,
        'guarantor_id_number': guarantorIdNumber,
        'relationship': relationship,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all pending guarantor records for admin review.
  Future<List<GuarantorRegistration>> fetchPendingGuarantors() async {
    try {
      final response = await _supabase
          .from('kyc_guarantors')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => GuarantorRegistration.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all guarantor records (for a specific indigent user or all).
  Future<List<GuarantorRegistration>> fetchAllGuarantors({
    String? indigentUserId,
  }) async {
    try {
      final query = _supabase.from('kyc_guarantors').select();
      final filtered = indigentUserId != null
          ? query.eq('indigent_user_id', indigentUserId)
          : query;
      final response = await filtered.order('created_at', ascending: false);

      return (response as List)
          .map((json) => GuarantorRegistration.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Review (approve/reject) a guarantor record.
  Future<bool> reviewGuarantorRecord({
    required String id,
    required bool approve,
    String? reviewedBy,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
      };
      if (reviewedBy != null) {
        updateData['reviewed_by'] = reviewedBy;
      }
      if (notes != null && notes.trim().isNotEmpty) {
        updateData['review_notes'] = notes.trim();
      }
      updateData['reviewed_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('kyc_guarantors')
          .update(updateData)
          .eq('id', id);

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get guarantor record by indigent user ID (for display in user profile/admin).
  Future<GuarantorRegistration?> getGuarantorForUser(String indigentUserId) async {
    try {
      final response = await _supabase
          .from('kyc_guarantors')
          .select()
          .eq('indigent_user_id', indigentUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return GuarantorRegistration.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}