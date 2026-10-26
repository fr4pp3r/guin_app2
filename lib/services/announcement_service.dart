import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/announcement.dart';

/// Data access for the barangay announcement board.
///
/// Announcements are global (no audience column): every signed-in user reads
/// the same rows, so the query needs no server-side filtering — the feed's
/// search bar narrows the whole list in memory instead
/// (`lib/utils/announcement_search.dart`).
class AnnouncementService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// All announcements, pinned first, then newest first.
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _supabase
        .from('announcements')
        .select()
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Announcement.fromJson(json))
        .toList();
  }

  Future<String> uploadImage(File file) async {
    final bucket = _supabase.storage.from('announcement-images');
    // Use the URI's last path segment so the name is correct on Windows too
    // (backslash separators break String.split('/')).
    final baseName = file.uri.pathSegments.last.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final path = '${DateTime.now().millisecondsSinceEpoch}_$baseName';
    try {
      await bucket.upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
    } on StorageException catch (e) {
      // Surface the missing-bucket case distinctly: Supabase reports a missing
      // bucket as 404 "Record not found", which reads like a DB row error.
      if (e.statusCode == '404' ||
          e.message.toLowerCase().contains('not found')) {
        throw Exception(
          'Storage bucket "announcement-images" is not set up. '
          'Apply supabase/migrations/20261021_announcements_images.sql in the '
          'SQL Editor (or create the bucket in the Supabase dashboard).',
        );
      }
      rethrow;
    }
    return bucket.getPublicUrl(path);
  }

  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required bool isPinned,
    String? createdBy,
    required String createdByName,
    String? imageUrl,
  }) async {
    final response = await _supabase
        .from('announcements')
        .insert({
          'title': title,
          'body': body,
          'is_pinned': isPinned,
          'created_by': createdBy,
          'created_by_name': createdByName,
          'image_url': ?imageUrl,
        })
        .select()
        .single();

    return Announcement.fromJson(response);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _supabase.from('announcements').delete().eq('id', id);
  }

  /// Live feed: any insert/update/delete on the table triggers [onChange],
  /// which callers use to reload the list.
  RealtimeChannel subscribeToAnnouncements(void Function() onChange) {
    final channel = _supabase
        .channel('announcements:feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (_) => onChange(),
        )
        .subscribe();

    return channel;
  }

  Future<void> unsubscribeFromAnnouncements(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
