import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/emergency_hotline.dart';

/// Data access for the emergency hotline directory.
///
/// Hotlines are global (no audience column): every signed-in user reads the
/// same rows. Write access is gated client-side by
/// `AppRoles.canManageHotlines` in the UI.
class EmergencyHotlineService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// All hotlines, active first, then alphabetically by name.
  Future<List<EmergencyHotline>> getHotlines() async {
    final response = await _supabase
        .from('emergency_hotlines')
        .select()
        .order('is_active', ascending: false)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => EmergencyHotline.fromJson(json))
        .toList();
  }

  Future<EmergencyHotline> createHotline({
    required String name,
    required String number,
    String? description,
    required bool isActive,
    String? createdBy,
    required String createdByName,
  }) async {
    final response = await _supabase
        .from('emergency_hotlines')
        .insert({
          'name': name,
          'number': number,
          'description': ?description,
          'is_active': isActive,
          'created_by': createdBy,
          'created_by_name': createdByName,
        })
        .select()
        .single();

    return EmergencyHotline.fromJson(response);
  }

  Future<EmergencyHotline> updateHotline({
    required String id,
    required String name,
    required String number,
    String? description,
    required bool isActive,
  }) async {
    final response = await _supabase
        .from('emergency_hotlines')
        .update({
          'name': name,
          'number': number,
          'description': ?description,
          'is_active': isActive,
        })
        .eq('id', id)
        .select()
        .single();

    return EmergencyHotline.fromJson(response);
  }

  Future<void> deleteHotline(String id) async {
    await _supabase.from('emergency_hotlines').delete().eq('id', id);
  }

  /// Live feed: any insert/update/delete on the table triggers [onChange],
  /// which callers use to reload the list.
  RealtimeChannel subscribeToHotlines(void Function() onChange) {
    final channel = _supabase
        .channel('emergency_hotlines:feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'emergency_hotlines',
          callback: (_) => onChange(),
        )
        .subscribe();

    return channel;
  }

  Future<void> unsubscribeFromHotlines(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
