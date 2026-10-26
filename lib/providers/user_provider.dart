import 'dart:io';
import 'package:flutter/material.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  RealtimeChannel? _usersChannel;

  List<UserProfile> _pendingUsers = [];
  List<UserProfile> _approvedUsers = [];
  List<UserProfile> _allUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserProfile> get pendingUsers => _pendingUsers;
  List<UserProfile> get approvedUsers => _approvedUsers;
  List<UserProfile> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadPendingUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingUsers = await _userService.getPendingUsers();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadApprovedUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _approvedUsers = await _userService.getApprovedUsers();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> approveUser(String userId) async {
    try {
      await _userService.approveUser(userId);
      // Reload lists
      await loadPendingUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectUser(String userId, String reason) async {
    try {
      await _userService.rejectUser(userId, reason);
      // Reload lists
      await loadPendingUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allUsers = await _userService.getAllUsers();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createUser({
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
    try {
      await _userService.createUser(
        username: username,
        email: email,
        password: password,
        givenName: givenName,
        middleName: middleName,
        lastName: lastName,
        address: address,
        age: age,
        dateOfBirth: dateOfBirth,
        placeOfBirth: placeOfBirth,
        civilStatus: civilStatus,
        gender: gender,
        phoneNumber: phoneNumber,
        role: role,
        profilePhoto: profilePhoto,
        validIdFront: validIdFront,
        validIdBack: validIdBack,
      );
      await loadAllUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Corrects another user's profile details (secretary/captain/admin). The
  /// DB trigger re-derives `full_name` from the name parts. Reloads both lists
  /// so an open queue reflects the edit.
  Future<bool> updateUserInfo({
    required String userId,
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
  }) async {
    try {
      await _userService.updateUserProfile(
        userId: userId,
        givenName: givenName,
        middleName: middleName,
        lastName: lastName,
        address: address,
        age: age,
        dateOfBirth: dateOfBirth,
        placeOfBirth: placeOfBirth,
        civilStatus: civilStatus,
        gender: gender,
        phoneNumber: phoneNumber,
      );
      await Future.wait([loadPendingUsers(), loadAllUsers()]);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String role) async {
    try {
      await _userService.updateUserRole(userId, role);
      await loadAllUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _userService.deleteUser(userId);
      await Future.wait([loadPendingUsers(), loadAllUsers()]);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, int>> getUserStatistics() async {
    try {
      return await _userService.getUserStatistics();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Subscribe to real-time updates for users_profile table
  void subscribeToUsers() {
    _usersChannel = SupabaseConfig.client
        .channel('users_profile_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users_profile',
          callback: (payload) {
            loadPendingUsers();
            loadAllUsers();
          },
        )
        .subscribe();
  }

  // Unsubscribe from real-time updates
  void unsubscribeFromUsers() {
    if (_usersChannel != null) {
      SupabaseConfig.client.removeChannel(_usersChannel!);
      _usersChannel = null;
    }
  }

  @override
  void dispose() {
    unsubscribeFromUsers();
    super.dispose();
  }
}
