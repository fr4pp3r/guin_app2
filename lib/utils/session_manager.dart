import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUserId = 'user_id';
  static const String _keyEmail = 'user_email';
  static const String _keyUsername = 'user_username';
  static const String _keyRole = 'user_role';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyProfileSnapshot = 'profile_snapshot';

  // Save user session
  static Future<void> saveSession({
    required String userId,
    required String email,
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Get user ID from session
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  // Get email from session
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  // Get username from session
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  // Get role from session
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Persist a local snapshot of the user's profile so the app can start (and
  // show cached documents) while offline. Best-effort: never throws.
  static Future<void> saveProfileSnapshot(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfileSnapshot, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('SessionManager.saveProfileSnapshot failed: $e');
    }
  }

  // Read the last saved profile snapshot, or null when none is stored/corrupt.
  static Future<UserProfile?> getProfileSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyProfileSnapshot);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      return UserProfile.fromJson(decoded);
    } catch (e) {
      debugPrint('SessionManager.getProfileSnapshot failed: $e');
      return null;
    }
  }

  static Future<void> clearProfileSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyProfileSnapshot);
    } catch (e) {
      debugPrint('SessionManager.clearProfileSnapshot failed: $e');
    }
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyProfileSnapshot);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  // Get all session data
  static Future<Map<String, String?>> getSessionData() async {
    return {
      'userId': await getUserId(),
      'email': await getEmail(),
      'username': await getUsername(),
      'role': await getRole(),
    };
  }
}
