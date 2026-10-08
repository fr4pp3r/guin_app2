class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String
  type; // 'registration_approved', 'registration_rejected', 'request_approved', 'request_rejected', 'request_submitted'
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get typeIcon {
    switch (type) {
      case 'registration_approved':
        return '✅';
      case 'registration_rejected':
        return '❌';
      case 'request_approved':
        return '📄';
      case 'request_rejected':
        return '🚫';
      case 'request_submitted':
        return '📨';
      default:
        return '🔔';
    }
  }

  String get typeColor {
    switch (type) {
      case 'registration_approved':
      case 'request_approved':
        return 'green';
      case 'registration_rejected':
      case 'request_rejected':
        return 'red';
      case 'request_submitted':
        return 'blue';
      default:
        return 'grey';
    }
  }
}
