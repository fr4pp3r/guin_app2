import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/password_hash.dart';
import 'package:guin_app/utils/session_manager.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get current user ID from session
  Future<String?> get currentUserId => SessionManager.getUserId();

  // Check if user is logged in
  Future<bool> get isLoggedIn => SessionManager.isLoggedIn();

  // Sign up with email and password (Custom Auth - No Supabase Auth)
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String address,
    required int age,
    required DateTime dateOfBirth,
    required String placeOfBirth,
    required String civilStatus,
    required String gender,
    required String phoneNumber,
    String? profilePhotoUrl,
    String? validIdUrl,
  }) async {
    try {
      // Check if email already exists
      final existingEmail = await _supabase
          .from('users_profile')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existingEmail != null) {
        throw Exception('Email already exists');
      }

      // Check if username already exists
      final existingUsername = await _supabase
          .from('users_profile')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      if (existingUsername != null) {
        throw Exception('Username already exists');
      }

      // Hash the password
      final hashedPassword = PasswordHash.generate(password);

      // Create user profile with hashed password
      final response = await _supabase
          .from('users_profile')
          .insert({
            'email': email,
            'password_hash': hashedPassword,
            'username': username,
            'full_name': fullName,
            'address': address,
            'age': age,
            'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
            'place_of_birth': placeOfBirth,
            'civil_status': civilStatus,
            'gender': gender,
            'phone_number': phoneNumber,
            'profile_photo_url': profilePhotoUrl,
            'valid_id_url': validIdUrl,
            'role': 'citizen',
            'is_approved': false,
            'registration_status': 'pending',
          })
          .select()
          .single();

      final userProfile = UserProfile.fromJson(response);

      // Save session
      await SessionManager.saveSession(
        userId: userProfile.id,
        email: userProfile.email,
        username: userProfile.username,
        role: userProfile.role,
      );

      return userProfile;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password (Custom Auth - No Supabase Auth)
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Get user by email
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid email or password');
      }

      final userProfile = UserProfile.fromJson(response);

      // Verify password
      final storedHash = response['password_hash'] as String;
      final isPasswordValid = PasswordHash.verify(password, storedHash);

      if (!isPasswordValid) {
        throw Exception('Invalid email or password');
      }

      // Save session (even for pending users so they can see their status)
      await SessionManager.saveSession(
        userId: userProfile.id,
        email: userProfile.email,
        username: userProfile.username,
        role: userProfile.role,
      );

      return userProfile;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await SessionManager.clearSession();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user profile from session
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) return null;

      return await getUserProfile(userId);
    } catch (e) {
      rethrow;
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

  // Check if username exists
  Future<bool> isUsernameExists(String username) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      return response != null;
    } catch (e) {
      rethrow;
    }
  }

  // Check if email exists
  Future<bool> isEmailExists(String email) async {
    try {
      final response = await _supabase
          .from('users_profile')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      rethrow;
    }
  }

  // Update password (user must be logged in)
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get user profile
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('id', userId)
          .single();

      // Verify current password
      final storedHash = response['password_hash'] as String;
      final isPasswordValid = PasswordHash.verify(currentPassword, storedHash);

      if (!isPasswordValid) {
        throw Exception('Current password is incorrect');
      }

      // Hash new password
      final newHashedPassword = PasswordHash.generate(newPassword);

      // Update password in database
      await _supabase
          .from('users_profile')
          .update({'password_hash': newHashedPassword})
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Reset password (requires email verification in production)
  // For now, this is a simplified version
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Check if email exists
      final response = await _supabase
          .from('users_profile')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        throw Exception('Email not found');
      }

      // Hash new password
      final hashedPassword = PasswordHash.generate(newPassword);

      // Update password
      await _supabase
          .from('users_profile')
          .update({'password_hash': hashedPassword})
          .eq('email', email);
    } catch (e) {
      rethrow;
    }
  }

  // Restore session on app start
  Future<UserProfile?> restoreSession() async {
    try {
      final isLoggedIn = await SessionManager.isLoggedIn();
      if (!isLoggedIn) return null;

      final userId = await SessionManager.getUserId();
      if (userId == null) return null;

      // Get fresh user profile from database
      return await getUserProfile(userId);
    } catch (e) {
      // If session restore fails, clear session
      await SessionManager.clearSession();
      return null;
    }
  }
}
