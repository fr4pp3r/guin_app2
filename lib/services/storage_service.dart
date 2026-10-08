import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Upload file to storage
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      await _supabase.storage.from(bucket).upload(path, file);

      // Return public URL for public buckets, or the path for private buckets
      if (bucket == 'profile-photos') {
        return _supabase.storage.from(bucket).getPublicUrl(path);
      } else {
        // For private buckets, return signed URL
        return await _supabase.storage
            .from(bucket)
            .createSignedUrl(path, 31536000); // 1 year
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete file from storage
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      rethrow;
    }
  }

  // Get public URL for a file
  String getPublicUrl({required String bucket, required String path}) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  // Create signed URL for private files
  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600, // Default 1 hour
  }) async {
    try {
      return await _supabase.storage
          .from(bucket)
          .createSignedUrl(path, expiresIn);
    } catch (e) {
      rethrow;
    }
  }

  // List files in a folder
  Future<List<FileObject>> listFiles({
    required String bucket,
    String? path,
  }) async {
    try {
      return await _supabase.storage.from(bucket).list(path: path);
    } catch (e) {
      rethrow;
    }
  }

  // Download file as bytes
  Future<List<int>> downloadFile({
    required String bucket,
    required String path,
  }) async {
    try {
      return await _supabase.storage.from(bucket).download(path);
    } catch (e) {
      rethrow;
    }
  }
}
