import 'package:guin_app/config/supabase_config.dart';

class AuditService {
  final _supabase = SupabaseConfig.client;

  Future<void> logAction({
    required String action,
    required String entityType,
    String? entityId,
    String? actorUserId,
    String? actorRole,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? remarks,
  }) async {
    await _supabase.from('audit_logs').insert({
      'actor_user_id': actorUserId,
      'actor_role': actorRole,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'old_value': oldValue,
      'new_value': newValue,
      'remarks': remarks,
    });
  }
}
