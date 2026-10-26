import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/notification.dart';

class NotificationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get user's notifications
  Future<List<AppNotification>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  // Get unread notifications
  Future<List<AppNotification>> getUnreadNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Mark notification as read
  Future<AppNotification> markAsRead(String notificationId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .select()
          .single();

      return AppNotification.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await _supabase.from('notifications').delete().eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Listen to new notifications (real-time)
  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(AppNotification) onNotification,
  ) {
    final channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = AppNotification.fromJson(payload.newRecord);
            onNotification(notification);
          },
        )
        .subscribe();

    return channel;
  }

  // Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  // Create manual notification (for testing or admin purposes)
  Future<AppNotification> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final response = await _supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type,
          })
          .select()
          .single();

      return AppNotification.fromJson(response);
    } catch (e) {
      rethrow;
    } finally {
      // Server-side FCM push, fired once the insert above has settled (this
      // runs on the success AND failure paths; the function re-checks that the
      // row exists before sending, so a failed insert produces no push).
      // Deliberately NOT awaited: the bell row is the source of truth and must
      // never wait on, or fail because of, push delivery. Server half lives in
      // supabase/functions/push/.
      _schedulePush(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );
    }
  }

  /// Fire-and-forget trigger for the `push` Edge Function.
  ///
  /// The function checks that the notification row exists and fans out to that
  /// user's registered devices, so nothing security-relevant is decided here.
  /// Any failure (function not deployed, secrets unset, offline device,
  /// Firebase not configured, Android not the platform) is swallowed — in-app
  /// notifications are unaffected.
  void _schedulePush({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) {
    unawaited(
      _supabase.functions
          .invoke('push', body: {
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type,
          })
          .timeout(const Duration(seconds: 10))
          .then(
            (_) {},
            onError: (Object e) =>
                debugPrint('PushService: push invoke skipped/failed: $e'),
          ),
    );
  }

  /// Fan a notification out to every APPROVED user holding one of [roles].
  ///
  /// Best-effort by design: never throws, and one failed insert does not stop
  /// the remaining recipients. Queue/alert notices for officials rely on this
  /// so a notifications hiccup can never block the action that triggered it.
  Future<void> notifyRoles({
    required List<String> roles,
    required String title,
    required String message,
    required String type,
  }) async {
    if (roles.isEmpty) return;
    try {
      final officials = await _supabase
          .from('users_profile')
          .select('id')
          .inFilter('role', roles)
          .eq('is_approved', true);

      for (final row in officials as List) {
        final id = row['id']?.toString();
        if (id == null) continue;
        try {
          await createNotification(
            userId: id,
            title: title,
            message: message,
            type: type,
          );
        } catch (_) {
          // One recipient failing must not stop the rest.
        }
      }
    } catch (_) {
      // Fan-out is best-effort; callers never see a throw.
    }
  }

  /// Fan a notification out to every APPROVED user, regardless of role.
  ///
  /// Used for barangay-wide notices (announcements). Best-effort in exactly the
  /// same way as [notifyRoles]: never throws, one failed insert never stops the
  /// remaining recipients.
  ///
  /// Unlike [notifyRoles] (a handful of officials), this can fan out to every
  /// citizen in the barangay, so the loops are batched and the per-recipient
  /// push handoff is awaited — see [_pushFanOut] for why.
  Future<void> notifyAllApproved({
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final users = await _supabase
          .from('users_profile')
          .select('id')
          .eq('is_approved', true);

      final ids = (users as List)
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return;

      await _insertNotificationsBatched(
        userIds: ids,
        title: title,
        message: message,
        type: type,
      );
    } catch (_) {
      // Fan-out is best-effort; callers never see a throw.
    }
  }

  /// Insert the same notification for many users in fewer round-trips.
  ///
  /// Prefers a single batched INSERT (one request regardless of recipient
  /// count) and falls back to the per-row path if the bulk insert is rejected,
  /// so a fan-out that used to take N sequential calls now takes one.
  Future<void> _insertNotificationsBatched({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    int batchSize = 200,
  }) async {
    for (var start = 0; start < userIds.length; start += batchSize) {
      final end = (start + batchSize < userIds.length)
          ? start + batchSize
          : userIds.length;
      final batch = userIds.sublist(start, end);
      try {
        await _supabase.from('notifications').insert([
          for (final id in batch)
            {
              'user_id': id,
              'title': title,
              'message': message,
              'type': type,
            },
        ]);
        // Hand the batch to the push function once, rather than once per row.
        await _pushFanOut(batch, title: title, message: message, type: type);
      } catch (e) {
        debugPrint('Batched notification insert failed, falling back: $e');
        for (final id in batch) {
          try {
            await createNotification(
              userId: id,
              title: title,
              message: message,
              type: type,
            );
          } catch (_) {
            // One recipient failing must not stop the rest.
          }
        }
      }
    }
  }

  /// Kick off push delivery for a whole batch of recipients.
  ///
  /// This is the half of the handoff that [createNotification] deliberately
  /// leaves fire-and-forget. A bulk fan-out finishes and the caller navigates
  /// away immediately, which would drop the in-flight HTTP requests, so here we
  /// give them a bounded window to complete. Still best-effort: a timeout or
  /// failure only means "no push", never a failed post.
  Future<void> _pushFanOut(
    List<String> userIds, {
    required String title,
    required String message,
    required String type,
  }) async {
    if (userIds.isEmpty) return;
    try {
      await _supabase.functions
          .invoke('push', body: {
            'user_ids': userIds,
            'title': title,
            'message': message,
            'type': type,
          })
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('PushService: batch push skipped/failed: $e');
    }
  }
}
