import 'dart:io';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/payment_record.dart';

class PaymentService {
  final _supabase = SupabaseConfig.client;

  Future<String> uploadReceipt(String userId, File imageFile) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = '$userId/receipt_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _supabase.storage.from('payment-receipts').upload(fileName, imageFile);
    return _supabase.storage.from('payment-receipts').getPublicUrl(fileName);
  }

  Future<PaymentRecord> submitGcashPayment({
    required String requestId,
    required String userId,
    required double amount,
    required String receiptUrl,
    String? referenceNumber,
  }) async {
    final response = await _supabase.from('payments').insert({
      'request_id': requestId,
      'user_id': userId,
      'payment_method': 'gcash',
      'amount': amount,
      'reference_number': referenceNumber,
      'receipt_url': receiptUrl,
      'status': 'submitted',
    }).select().single();

    await _supabase.from('document_requests').update({
      'payment_receipt_url': receiptUrl,
      'payment_reference_number': referenceNumber,
      'payment_method': 'gcash',
      'payment_status': 'pending',
      'request_status': 'pending_payment',
    }).eq('id', requestId);

    return PaymentRecord.fromJson(response);
  }

  Future<PaymentRecord> encodeCashPayment({
    required String requestId,
    required String userId,
    required double amount,
    required String cashierId,
    required String method,
    String? referenceNumber,
    String? remarks,
  }) async {
    final response = await _supabase.from('payments').insert({
      'request_id': requestId,
      'user_id': userId,
      'payment_method': method,
      'amount': amount,
      'reference_number': referenceNumber,
      'status': 'verified',
      'encoded_by': cashierId,
      'verified_by': cashierId,
      'verified_at': DateTime.now().toIso8601String(),
      'remarks': remarks,
    }).select().single();

    await _supabase.from('document_requests').update({
      'payment_method': method,
      'payment_reference_number': referenceNumber,
      'payment_status': 'verified',
      'payment_verified_by': cashierId,
      'payment_verified_at': DateTime.now().toIso8601String(),
      'request_status': 'pending_review',
    }).eq('id', requestId);

    return PaymentRecord.fromJson(response);
  }
}
