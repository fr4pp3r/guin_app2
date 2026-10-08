import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/document_request.dart';

class DocumentService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Create a new document request
  Future<DocumentRequest> createRequest({
    required String userId,
    required String documentType,
    required String purpose,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .insert({
            'user_id': userId,
            'document_type': documentType,
            'purpose': purpose,
            'request_status': 'pending',
          })
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get user's document requests
  Future<List<DocumentRequest>> getUserRequests(String userId) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false);

      return (response as List)
          .map((json) => DocumentRequest.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all pending requests (Admin only)
  Future<List<DocumentRequest>> getPendingRequests() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!inner(username, full_name)
          ''')
          .eq('request_status', 'pending')
          .order('requested_at', ascending: false);

      return (response as List).map((json) {
        final flatJson = <String, dynamic>{
          ...json,
          'username': json['users_profile']['username'],
          'full_name': json['users_profile']['full_name'],
        };
        flatJson.remove('users_profile');
        return DocumentRequest.fromJson(flatJson);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all requests with user info (Admin only)
  Future<List<DocumentRequest>> getAllRequests() async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!inner(username, full_name)
          ''')
          .order('requested_at', ascending: false);

      return (response as List).map((json) {
        final flatJson = <String, dynamic>{
          ...json,
          'username': json['users_profile']['username'],
          'full_name': json['users_profile']['full_name'],
        };
        flatJson.remove('users_profile');
        return DocumentRequest.fromJson(flatJson);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get request by ID
  Future<DocumentRequest?> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .select('''
            *,
            users_profile!inner(username, full_name)
          ''')
          .eq('id', requestId)
          .maybeSingle();

      if (response == null) return null;

      final flatJson = <String, dynamic>{
        ...response,
        'username': response['users_profile']['username'],
        'full_name': response['users_profile']['full_name'],
      };
      flatJson.remove('users_profile');
      return DocumentRequest.fromJson(flatJson);
    } catch (e) {
      rethrow;
    }
  }

  // Approve document request (Admin only)
  Future<DocumentRequest> approveRequest({
    required String requestId,
    required String documentUrl,
    required String reviewedBy,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'request_status': 'approved',
            'document_url': documentUrl,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': reviewedBy,
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Reject document request (Admin only)
  Future<DocumentRequest> rejectRequest({
    required String requestId,
    required String reason,
    required String reviewedBy,
  }) async {
    try {
      final response = await _supabase
          .from('document_requests')
          .update({
            'request_status': 'rejected',
            'rejection_reason': reason,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': reviewedBy,
          })
          .eq('id', requestId)
          .select()
          .single();

      return DocumentRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Upload document file
  Future<String> uploadDocument(String requestId, File documentFile) async {
    try {
      final fileExt = documentFile.path.split('.').last;
      final fileName =
          '$requestId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('documents').upload(fileName, documentFile);

      // For private bucket, create signed URL (valid for 1 year)
      final signedUrl = await _supabase.storage
          .from('documents')
          .createSignedUrl(fileName, 31536000); // 1 year in seconds

      return signedUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Delete document file
  Future<void> deleteDocument(String documentUrl) async {
    try {
      final uri = Uri.parse(documentUrl);
      final pathSegments = uri.pathSegments;

      // Find 'documents' bucket index and get path after it
      final bucketIndex = pathSegments.indexOf('documents');
      if (bucketIndex == -1) return;

      final path = pathSegments.skip(bucketIndex + 1).join('/');

      await _supabase.storage.from('documents').remove([path]);
    } catch (e) {
      rethrow;
    }
  }

  // Get document statistics (Admin only)
  Future<Map<String, int>> getDocumentStatistics() async {
    try {
      final totalRequests = await _supabase
          .from('document_requests')
          .select('id')
          .count(CountOption.exact);

      final pendingRequests = await _supabase
          .from('document_requests')
          .select('id')
          .eq('request_status', 'pending')
          .count(CountOption.exact);

      final approvedRequests = await _supabase
          .from('document_requests')
          .select('id')
          .eq('request_status', 'approved')
          .count(CountOption.exact);

      final rejectedRequests = await _supabase
          .from('document_requests')
          .select('id')
          .eq('request_status', 'rejected')
          .count(CountOption.exact);

      return {
        'total': totalRequests.count,
        'pending': pendingRequests.count,
        'approved': approvedRequests.count,
        'rejected': rejectedRequests.count,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Download document (creates a new signed URL for download)
  Future<String> getDownloadUrl(String documentUrl) async {
    try {
      final uri = Uri.parse(documentUrl);
      final pathSegments = uri.pathSegments;

      // Find 'documents' bucket index and get path after it
      final bucketIndex = pathSegments.indexOf('documents');
      if (bucketIndex == -1) throw Exception('Invalid document URL');

      final path = pathSegments.skip(bucketIndex + 1).join('/');

      // Create a new signed URL for download (valid for 1 hour)
      final signedUrl = await _supabase.storage
          .from('documents')
          .createSignedUrl(path, 3600); // 1 hour in seconds

      return signedUrl;
    } catch (e) {
      rethrow;
    }
  }
}
