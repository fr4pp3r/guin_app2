/// A barangay-wide notice posted by an official.
///
/// Announcements are global: every signed-in user reads the same list. There is
/// no per-user targeting and no read state. [createdByName] is denormalized on
/// the row (and copied again for the primary key referenced author) so the feed
/// renders without joining `users_profile`.
class Announcement {
  final String id;
  final String title;
  final String body;
  final String? createdBy;
  final String createdByName;
  final bool isPinned;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdByName,
    required this.isPinned,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdBy: json['created_by'] as String?,
      createdByName: (json['created_by_name'] as String?) ?? 'Barangay Official',
      isPinned: (json['is_pinned'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
