import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/announcement.dart';

/// Data access for the barangay announcement board.
///
/// Announcements are global (no audience column): every signed-in user reads
/// the same rows, so there is nothing to filter client-side beyond ordering.
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

  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required bool isPinned,
    String? createdBy,
    required String createdByName,
  }) async {
    final response = await _supabase
        .from('announcements')
        .insert({
          'title': title,
          'body': body,
          'is_pinned': isPinned,
          'created_by': createdBy,
          'created_by_name': createdByName,
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
