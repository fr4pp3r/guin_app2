import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/barangay_config.dart';
import 'package:guin_app/models/document_fee.dart';

class BarangayService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get barangay configuration
  Future<BarangayConfig?> getBarangayConfig() async {
    try {
      final response = await _supabase
          .from('barangay_config')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return BarangayConfig.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Update barangay configuration (admin only)
  Future<BarangayConfig> updateBarangayConfig({
    required String id,
    required String gcashName,
    required String gcashNumber,
    required String barangayName,
    required String barangayAddress,
    String? barangayCaptain,
    String? contactNumber,
    String? email,
    String? logoUrl,
  }) async {
    try {
      final response = await _supabase
          .from('barangay_config')
          .update({
            'gcash_name': gcashName,
            'gcash_number': gcashNumber,
            'barangay_name': barangayName,
            'barangay_address': barangayAddress,
            'barangay_captain': barangayCaptain,
            'contact_number': contactNumber,
            'email': email,
            'logo_url': logoUrl,
          })
          .eq('id', id)
          .select()
          .single();

      return BarangayConfig.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get all document fees
  Future<List<DocumentFee>> getDocumentFees() async {
    try {
      final response = await _supabase
          .from('document_fees')
          .select()
          .order('document_type');

      return (response as List)
          .map((json) => DocumentFee.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get document fee by type
  Future<DocumentFee?> getDocumentFeeByType(String documentType) async {
    try {
      final response = await _supabase
          .from('document_fees')
          .select()
          .eq('document_type', documentType)
          .maybeSingle();

      if (response == null) return null;
      return DocumentFee.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Update document fee (admin only)
  Future<DocumentFee> updateDocumentFee({
    required String id,
    required double feeAmount,
    String? description,
    required bool isFree,
  }) async {
    try {
      final response = await _supabase
          .from('document_fees')
          .update({
            'fee_amount': isFree ? 0.0 : feeAmount,
            'description': description,
            'is_free': isFree,
          })
          .eq('id', id)
          .select()
          .single();

      return DocumentFee.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
