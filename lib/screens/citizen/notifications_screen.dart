import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/models/notification.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    await context.read<NotificationProvider>().loadNotifications(user.id);
  }

  Future<void> _markAllRead() async {
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    await context.read<NotificationProvider>().markAllAsRead(user.id);
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    await context.read<NotificationProvider>().markAsRead(n.id, user.id);
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'document_approved':
        return Colors.green;
      case 'document_rejected':
        return Colors.red;
      case 'document_released':
        return AppColors.primary;
      case 'payment_verified':
        return Colors.teal;
      case 'payment_rejected':
        return Colors.red;
      case 'registration_approved':
        return Colors.green;
      case 'registration_rejected':
        return Colors.red;
      case 'incident_update':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'document_approved':
        return Icons.check_circle_outline;
      case 'document_rejected':
        return Icons.cancel_outlined;
      case 'document_released':
        return Icons.download_done_outlined;
      case 'payment_verified':
        return Icons.payment_outlined;
      case 'payment_rejected':
        return Icons.money_off_outlined;
      case 'registration_approved':
        return Icons.how_to_reg_outlined;
      case 'registration_rejected':
        return Icons.person_off_outlined;
      case 'incident_update':
        return Icons.update_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                  Color(0xFF42A5F5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Stay updated on your requests',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Consumer<NotificationProvider>(
                      builder: (_, provider, __) {
                        if (provider.unreadCount == 0)
                          return const SizedBox.shrink();
                        return TextButton.icon(
                          onPressed: _markAllRead,
                          icon: const Icon(
                            Icons.done_all,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'Mark all read',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = provider.notifications;

                // Load failed (e.g. offline) — show a plain "couldn't load"
                // state rather than implying there are no notifications. The
                // raw error text is deliberately not shown.
                if (notifications.isEmpty && provider.errorMessage != null) {
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_off_outlined,
                                  size: 64,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Couldn\u2019t load notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Your notifications didn\u2019t load. Check your connection and try again.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Retry',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_off_outlined,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No notifications yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Notifications will appear here when you have activity',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Separate unread and read
                final unread = notifications.where((n) => !n.isRead).toList();
                final read = notifications.where((n) => n.isRead).toList();

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (unread.isNotEmpty) ...[
                        _sectionHeader('New', unread.length),
                        const SizedBox(height: 8),
                        ...unread.map(
                          (n) => _notificationCard(n, isUnread: true),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (read.isNotEmpty) ...[
                        _sectionHeader('Earlier', null),
                        const SizedBox(height: 8),
                        ...read.map(
                          (n) => _notificationCard(n, isUnread: false),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int? count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _notificationCard(
    AppNotification notification, {
    required bool isUnread,
  }) {
    final color = _typeColor(notification.type);
    return GestureDetector(
      onTap: () => _markRead(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: color.withValues(alpha: 0.2), width: 1.5)
              : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isUnread ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _typeIcon(notification.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: isUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread ? AppColors.textSecondary : Colors.grey,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Helpers.formatDateTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
