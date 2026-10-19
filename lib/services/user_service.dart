import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/utils/password_hash.dart';
import 'package:guin_app/utils/session_manager.dart';

class UserService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final NotificationService _notificationService = NotificationService();

  /// Best-effort citizen notice for registration decisions. Swallows errors —
  /// a notification failure must never fail the approve/reject itself.
  Future<void> _safeNotify(
    String userId,
    String title,
    String message,
    String type,
  ) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );
    } catch (e) {
      debugPrint('Registration notification to $userId failed: $e');
    }
  }

  // Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<UserProfile> updateUserProfile({
    required String userId,
    String? username,
    String? email,
    String? givenName,
    String? middleName,
    String? lastName,
    String? address,
    int? age,
    DateTime? dateOfBirth,
    String? placeOfBirth,
    String? civilStatus,
    String? gender,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? validIdUrl,
    String? validIdBackUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (email != null) updateData['email'] = email;
      if (givenName != null) updateData['given_name'] = givenName;
      if (middleName != null) updateData['middle_name'] = middleName.isEmpty ? null : middleName;
      if (lastName != null) updateData['last_name'] = lastName;
      // Also update full_name for backward compatibility
      if (givenName != null || middleName != null || lastName != null) {
        // We'd need to read current values to build full_name; for simplicity,
        // the DB trigger handles it on update. But we can also send it if all three provided.
        // For now, rely on DB trigger.
      }
      if (address != null) updateData['address'] = address;
      if (age != null) updateData['age'] = age;
      if (dateOfBirth != null) {
        updateData['date_of_birth'] = dateOfBirth.toIso8601String().split(
          'T',
        )[0];
      }
      if (placeOfBirth != null) updateData['place_of_birth'] = placeOfBirth;
      if (civilStatus != null) updateData['civil_status'] = civilStatus;
      if (gender != null) updateData['gender'] = gender;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (profilePhotoUrl != null) {
        updateData['profile_photo_url'] = profilePhotoUrl;
      }
      if (validIdUrl != null) updateData['valid_id_url'] = validIdUrl;
      if (validIdBackUrl != null) updateData['valid_id_back_url'] = validIdBackUrl;

      final response = await _supabase
          .from('users_profile')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get all pending user registrations (Admin only)
  Future<List<UserProfile>> getPendingUsers() async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('registration_status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all approved users (Admin only)
  Future<List<UserProfile>> getApprovedUsers() async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('registration_status', 'approved')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all citizens (Admin only)
  Future<List<UserProfile>> getAllCitizens() async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('role', 'citizen')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserProfile>> getUsersByRole(String role) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('role', role)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserProfile>> getBarangayStaff() async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .inFilter('role', [
            'admin',
            'captain',
            'secretary',
            'treasurer',
            'kagawad_representative',
            'barangay_tanod',
          ])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile> assignRole({
    required String userId,
    required String role,
  }) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .update({
            'role': role,
            'registration_status': 'approved',
            'is_approved': true,
          })
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Approve user registration (Admin only)
  //
  // This is the ONLY way a citizen becomes approved — registration itself never
  // self-approves. The kyc_method stamp records how the reviewer settled the
  // identity: an indigent registrant is vouched for by an approved guarantor
  // (`guarantor_verified`), everything else is a plain officer check
  // (`manual_verified`).
  Future<UserProfile> approveUser(String userId) async {
    try {
      final reviewerId = await SessionManager.getUserId();
      final updateData = <String, dynamic>{
        'registration_status': 'approved',
        'is_approved': true,
        'kyc_verified_at': Helpers.now().toIso8601String(),
      };
      if (reviewerId != null) {
        updateData['kyc_reviewed_by'] = reviewerId;
      }
      updateData['kyc_method'] =
          (await _isGuarantorBacked(userId))
          ? 'guarantor_verified'
          : 'manual_verified';

      final response = await _supabase
          .from('users_profile')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      final approved = UserProfile.fromJson(response);
      await _safeNotify(
        userId,
        'Registration approved',
        'Your barangay registration has been approved. You can now sign in '
            'and use the app.',
        'registration_approved',
      );

      return approved;
    } catch (e) {
      rethrow;
    }
  }

  /// True when this registration was vouched for by a guarantor: the citizen
  /// is flagged indigent, or an approved `kyc_guarantors` row links them to one.
  /// Read failures degrade to false (plain manual review) instead of blocking
  /// an approval an officer is entitled to make.
  Future<bool> _isGuarantorBacked(String userId) async {
    try {
      final profile = await _supabase
          .from('users_profile')
          .select('is_indigent')
          .eq('id', userId)
          .maybeSingle();

      final isIndigent = profile?['is_indigent'] as bool? ?? false;
      if (isIndigent) return true;

      final guarantors = await _supabase
          .from('kyc_guarantors')
          .select('id')
          .eq('indigent_user_id', userId)
          .eq('status', 'approved')
          .limit(1);

      return (guarantors as List).isNotEmpty;
    } catch (e) {
      debugPrint('Guarantor lookup failed for $userId: $e');
      return false;
    }
  }

  // Reject user registration (Admin only)
  //
  // `reason` is optional so a rejection can be filed without a note; the
  // KYC-specific reason is only written when there is actually something to say.
  Future<UserProfile> rejectUser(String userId, [String? reason]) async {
    try {
      final updateData = <String, dynamic>{
        'registration_status': 'rejected',
        'is_approved': false,
      };
      if (reason != null && reason.trim().isNotEmpty) {
        updateData['rejection_reason'] = reason.trim();
        updateData['kyc_rejection_reason'] = reason.trim();
      }

      final response = await _supabase
          .from('users_profile')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      final rejected = UserProfile.fromJson(response);
      final trimmedReason = (reason ?? '').trim();
      await _safeNotify(
        userId,
        'Registration rejected',
        trimmedReason.isEmpty
            ? 'Your barangay registration was not approved. Please visit the '
                  'barangay hall for details.'
            : 'Your barangay registration was not approved. '
                  'Reason: $trimmedReason',
        'registration_rejected',
      );

      return rejected;
    } catch (e) {
      rethrow;
    }
  }

  // Upload profile photo
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '$userId/${Helpers.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage
          .from('profile-photos')
          .upload(fileName, imageFile);

      final publicUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Upload valid ID
  Future<String> uploadValidId(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '$userId/valid_id_${Helpers.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('valid-ids').upload(fileName, imageFile);

      final publicUrl = _supabase.storage
          .from('valid-ids')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Delete profile photo
  Future<void> deleteProfilePhoto(String photoUrl) async {
    try {
      final uri = Uri.parse(photoUrl);
      final path = uri.pathSegments.skip(uri.pathSegments.length - 3).join('/');

      await _supabase.storage.from('profile-photos').remove([path]);
    } catch (e) {
      rethrow;
    }
  }

  // Get statistics (Admin only)
  Future<Map<String, int>> getUserStatistics() async {
    try {
      final pending = await _supabase
          .from('users_profile')
          .select('id')
          .eq('registration_status', 'pending');

      final approved = await _supabase
          .from('users_profile')
          .select('id')
          .eq('registration_status', 'approved');

      final rejected = await _supabase
          .from('users_profile')
          .select('id')
          .eq('registration_status', 'rejected');

      final total = await _supabase
          .from('users_profile')
          .select('id')
          .eq('role', 'citizen');

      return {
        'pending_users': (pending as List).length,
        'approved_users': (approved as List).length,
        'rejected_users': (rejected as List).length,
        'total_users': (total as List).length,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Get ALL users regardless of role (Admin/Captain only)
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select()
          .order('role', ascending: true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Create a user directly (admin-created, auto-approved)
  Future<UserProfile> createUser({
    required String username,
    required String email,
    required String password,
    required String givenName,
    required String middleName,
    required String lastName,
    required String address,
    required int age,
    required DateTime dateOfBirth,
    required String placeOfBirth,
    required String civilStatus,
    required String gender,
    required String phoneNumber,
    required String role,
    File? profilePhoto,
    File? validIdFront,
    File? validIdBack,
  }) async {
    final existingEmail = await _supabase
        .from('users_profile')
        .select('email')
        .eq('email', email)
        .maybeSingle();
    if (existingEmail != null) throw Exception('Email already exists');

    final existingUsername = await _supabase
        .from('users_profile')
        .select('username')
        .eq('username', username)
        .maybeSingle();
    if (existingUsername != null) throw Exception('Username already exists');

    final hashedPassword = PasswordHash.generate(password);
    final tempId = 'admin_created_${Helpers.now().millisecondsSinceEpoch}';
    final fullName = [givenName, if (middleName.isNotEmpty) middleName, lastName].join(' ');

    String? profilePhotoUrl;
    if (profilePhoto != null) {
      profilePhotoUrl = await uploadProfilePhoto(tempId, profilePhoto);
    }

    String? validIdUrl;
    String? validIdBackUrl;
    if (validIdFront != null) {
      validIdUrl = await uploadValidId(tempId, validIdFront);
    }
    if (validIdBack != null) {
      validIdBackUrl = await uploadValidId(tempId, validIdBack);
    }

    final response = await _supabase
        .from('users_profile')
        .insert({
          'username': username,
          'email': email,
          'password_hash': hashedPassword,
          'given_name': givenName,
          'middle_name': middleName.isEmpty ? null : middleName,
          'last_name': lastName,
          'full_name': fullName,
          'address': address,
          'age': age,
          'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
          'place_of_birth': placeOfBirth,
          'civil_status': civilStatus,
          'gender': gender,
          'phone_number': phoneNumber,
          'role': role,
          'is_approved': true,
          'registration_status': 'approved',
          'profile_photo_url': profilePhotoUrl,
          'valid_id_url': validIdUrl,
          'valid_id_back_url': validIdBackUrl,
        })
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  // Update a user's role (Admin/Captain only)
  Future<UserProfile> updateUserRole(String userId, String role) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .update({'role': role})
          .eq('id', userId)
          .select()
          .single();
      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a user account (Admin only)
  Future<void> deleteUser(String userId) async {
    try {
      debugPrint('=== deleteUser START for userId: $userId ===');

      // 1. Clear FK references that are NOT CASCADE (set to NULL to preserve history)
      debugPrint('Step 1: Clearing document_requests FKs...');
      await _supabase
          .from('document_requests')
          .update({
            'payment_verified_by': null,
            'reviewed_by_secretary': null,
            'approved_by': null,
            'released_by': null,
            'printed_by': null,
          })
          .or('payment_verified_by.eq.$userId,reviewed_by_secretary.eq.$userId,approved_by.eq.$userId,released_by.eq.$userId,printed_by.eq.$userId');
      debugPrint('Step 1 done');

      debugPrint('Step 2: Clearing document_verifications FKs...');
      await _supabase
          .from('document_verifications')
          .update({'released_by': null, 'revoked_by': null})
          .or('released_by.eq.$userId,revoked_by.eq.$userId');
      debugPrint('Step 2 done');

      debugPrint('Step 3: Clearing incident_reports FKs...');
      await _supabase
          .from('incident_reports')
          .update({
            'submitted_by': null,
            'received_by': null,
            'assigned_to': null,
            'escalated_to': null,
            'resolved_by': null,
          })
          .or('submitted_by.eq.$userId,received_by.eq.$userId,assigned_to.eq.$userId,escalated_to.eq.$userId,resolved_by.eq.$userId');
      debugPrint('Step 3 done');

      debugPrint('Step 4: Clearing notifications FKs...');
      // notifications only has user_id (CASCADE), no action needed
      debugPrint('Step 4 done (notifications uses CASCADE)');

      debugPrint('Step 5: Clearing payments FKs...');
      await _supabase
          .from('payments')
          .update({'encoded_by': null, 'verified_by': null})
          .or('encoded_by.eq.$userId,verified_by.eq.$userId');
      debugPrint('Step 5 done');

      debugPrint('Step 6: Clearing audit_logs FKs...');
      await _supabase
          .from('audit_logs')
          .update({'actor_user_id': null})
          .eq('actor_user_id', userId);
      debugPrint('Step 5 done');

      debugPrint('Step 6: Clearing document_print_copies FKs...');
      await _supabase
          .from('document_print_copies')
          .update({'issued_by': null})
          .eq('issued_by', userId);
      debugPrint('Step 6 done');

      debugPrint('Step 7: Clearing kyc_guarantors FKs...');
      await _supabase
          .from('kyc_guarantors')
          .update({'reviewed_by': null, 'guarantor_user_id': null})
          .or('reviewed_by.eq.$userId,guarantor_user_id.eq.$userId');
      debugPrint('Step 7 done');

      debugPrint('Step 8: Clearing users_profile self-ref FKs...');
      await _supabase
          .from('users_profile')
          .update({'kyc_reviewed_by': null})
          .eq('kyc_reviewed_by', userId);
      debugPrint('Step 8 done');

      // 2. Now delete the user (all CASCADE FKs will auto-clean)
      debugPrint('Step 9: Deleting user profile...');
      await _supabase.from('users_profile').delete().eq('id', userId);
      debugPrint('Step 9 done');

      debugPrint('=== deleteUser SUCCESS for userId: $userId ===');
    } catch (e, stackTrace) {
      debugPrint('=== deleteUser FAILED for userId: $userId ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
