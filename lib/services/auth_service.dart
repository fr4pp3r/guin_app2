import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/services/document_cache_service.dart';
import 'package:guin_app/services/incident_report_cache_service.dart';
import 'package:guin_app/utils/password_hash.dart';
import 'package:guin_app/utils/session_manager.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get current user ID from session
  Future<String?> get currentUserId => SessionManager.getUserId();

  // Check if user is logged in
  Future<bool> get isLoggedIn => SessionManager.isLoggedIn();

  // Sign up with email and password (Custom Auth - No Supabase Auth)
  //
  // KYC posture: registration collects an ID type + number and a liveness
  // selfie result, but NOTHING here approves anybody. Every insert lands as
  // registration_status='pending' / is_approved=false and leaves kyc_method
  // null — `kycAiResult` is advisory evidence for the reviewer, not a verdict.
  // An officer stamps kyc_method when they approve (see UserService.approveUser).
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
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
    String? profilePhotoUrl,
    String? validIdUrl,
    String? validIdBackUrl,
    String? idType,
    String? idNumber,
    DateTime? idIssuedAt,
    DateTime? idExpiryAt,
    bool livenessVerified = false,
    Map<String, dynamic>? kycAiResult,
    bool isIndigent = false,
    String? indigencyReason,
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

      // Build full_name from parts (DB trigger also does this, but we send it
      // explicitly so the returned row is immediately consistent).
      final fullName = [givenName, if (middleName.isNotEmpty) middleName, lastName].join(' ');

      // Create user profile with hashed password
      final response = await _supabase
          .from('users_profile')
          .insert({
            'email': email,
            'password_hash': hashedPassword,
            'username': username,
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
            'profile_photo_url': profilePhotoUrl,
            'valid_id_url': validIdUrl,
            'valid_id_back_url': validIdBackUrl,
            'role': 'citizen',
            // No auto-approval path exists: every registration waits for a
            // captain/secretary review.
            'is_approved': false,
            'registration_status': 'pending',
            'kyc_id_type': idType,
            'kyc_id_number': idNumber,
            'id_issued_at': _dateOnly(idIssuedAt),
            'id_expiry_at': _dateOnly(idExpiryAt),
            'liveness_verified': livenessVerified,
            if (livenessVerified)
              'liveness_verified_at': DateTime.now().toIso8601String(),
            // Advisory only — kyc_method stays null until a human approves.
            'kyc_ai_result': kycAiResult,
            'is_indigent': isIndigent,
            'indigency_reason': indigencyReason,
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
      // Keep a local profile snapshot for offline session restore.
      await SessionManager.saveProfileSnapshot(userProfile);

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
      // Keep a local profile snapshot for offline session restore.
      await SessionManager.saveProfileSnapshot(userProfile);

      return userProfile;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Drop the user's cached documents so a different account on this device
      // can never see them. Cache failures must not block sign-out.
      final userId = await SessionManager.getUserId();
      if (userId != null) {
        try {
          await DocumentCacheService().clearMyRequests(userId);
          await IncidentReportCacheService().clearMyReports(userId);
        } catch (e) {
          debugPrint('Clearing cached data on sign-out failed: $e');
        }
      }
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

  // Restore session on app start.
  //
  // Network-first, but tolerates being offline: if the profile can't be fetched
  // because the server is unreachable, fall back to the last saved profile
  // snapshot so the app stays logged in and cached documents remain viewable.
  Future<UserProfile?> restoreSession() async {
    try {
      final isLoggedIn = await SessionManager.isLoggedIn();
      if (!isLoggedIn) return null;

      final userId = await SessionManager.getUserId();
      if (userId == null) return null;

      // Get fresh user profile from database
      final profile = await getUserProfile(userId);
      if (profile != null) {
        // Refresh the offline snapshot while live data is available.
        await SessionManager.saveProfileSnapshot(profile);
        return profile;
      }

      // Server reachable but the profile is genuinely gone — drop the session.
      await SessionManager.clearSession();
      return null;
    } catch (e) {
      // Server unreachable — fall back to the saved profile snapshot.
      debugPrint('restoreSession: profile fetch failed: $e');
      final cached = await SessionManager.getProfileSnapshot();
      if (cached != null) return cached;

      // Nothing to fall back to. Keep the session flag so a later online launch
      // can still restore it.
      return null;
    }
  }
}

/// `id_issued_at` / `id_expiry_at` are DATE columns, so they go over the wire
/// as a bare calendar day — the same shape as `date_of_birth`.
String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().split('T').first;
