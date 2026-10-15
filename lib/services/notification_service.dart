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
    }
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

      for (final row in users as List) {
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
}
