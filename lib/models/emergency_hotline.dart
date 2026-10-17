/// An emergency hotline contact displayed to all signed-in users.
///
/// Hotlines are global: every signed-in user reads the same list. Only
/// officials who pass `AppRoles.canManageHotlines` (captain / secretary /
/// admin) may add, edit, or remove entries — the data layer itself stays
/// permissive like the rest of the app.
class EmergencyHotline {
  final String id;
  final String name;
  final String number;
  final String? description;
  final bool isActive;
  final String? createdBy;
  final String createdByName;
  final DateTime createdAt;

  EmergencyHotline({
    required this.id,
    required this.name,
    required this.number,
    this.description,
    required this.isActive,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory EmergencyHotline.fromJson(Map<String, dynamic> json) {
    return EmergencyHotline(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String,
      description: json['description'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdBy: json['created_by'] as String?,
      createdByName:
          (json['created_by_name'] as String?) ?? 'Barangay Official',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'description': description,
      'is_active': isActive,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
