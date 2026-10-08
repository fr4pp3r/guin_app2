import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _subscription;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _notificationService.getUserNotifications(userId);
      _unreadCount = await _notificationService.getUnreadCount(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      await loadNotifications(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _notificationService.markAllAsRead(userId);
      await loadNotifications(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void subscribeToNotifications(String userId) {
    _subscription = _notificationService.subscribeToNotifications(userId, (
      notification,
    ) {
      _notifications.insert(0, notification);
      _unreadCount++;
      notifyListeners();
    });
  }

  Future<void> unsubscribe() async {
    if (_subscription != null) {
      await _notificationService.unsubscribeFromNotifications(_subscription!);
      _subscription = null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
