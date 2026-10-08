import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/password_hash.dart';

class UserService {
  final SupabaseClient _supabase = SupabaseConfig.client;

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
    String? fullName,
    String? address,
    int? age,
    DateTime? dateOfBirth,
    String? placeOfBirth,
    String? civilStatus,
    String? gender,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? validIdUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (email != null) updateData['email'] = email;
      if (fullName != null) updateData['full_name'] = fullName;
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
  Future<UserProfile> approveUser(String userId) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .update({'registration_status': 'approved', 'is_approved': true})
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Reject user registration (Admin only)
  Future<UserProfile> rejectUser(String userId, String reason) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .update({
            'registration_status': 'rejected',
            'is_approved': false,
            'rejection_reason': reason,
          })
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Upload profile photo
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

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
          '$userId/valid_id_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

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
    required String fullName,
    required String address,
    required int age,
    required DateTime dateOfBirth,
    required String placeOfBirth,
    required String civilStatus,
    required String gender,
    required String phoneNumber,
    required String role,
    File? profilePhoto,
    File? validId,
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
    final tempId = 'admin_created_${DateTime.now().millisecondsSinceEpoch}';

    String? profilePhotoUrl;
    if (profilePhoto != null) {
      profilePhotoUrl = await uploadProfilePhoto(tempId, profilePhoto);
    }

    String? validIdUrl;
    if (validId != null) {
      validIdUrl = await uploadValidId(tempId, validId);
    }

    final response = await _supabase
        .from('users_profile')
        .insert({
          'username': username,
          'email': email,
          'password_hash': hashedPassword,
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
      await _supabase.from('users_profile').delete().eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }
}
