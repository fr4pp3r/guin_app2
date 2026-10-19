import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:guin_app/services/auth_service.dart';
import 'package:guin_app/services/user_service.dart';
import 'package:guin_app/services/notification_service.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/role_access.dart';
import 'package:guin_app/utils/helpers.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userProfile != null;
  bool get isAdmin =>
      _userProfile != null && AppRoles.isOfficial(_userProfile!.role);
  bool get canVerifyPayments =>
      _userProfile != null && AppRoles.canVerifyPayments(_userProfile!.role);
  bool get canReviewDocuments =>
      _userProfile != null && AppRoles.canReviewDocuments(_userProfile!.role);
  bool get canReleaseDocuments =>
      _userProfile != null && AppRoles.canReleaseDocuments(_userProfile!.role);
  bool get canManageReports =>
      _userProfile != null && AppRoles.canManageReports(_userProfile!.role);
  bool get isApproved => _userProfile?.isApproved ?? false;
  String? get currentUserId => _userProfile?.id;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Try to restore session on app start
    await restoreSession();
  }

  Future<void> restoreSession() async {
    try {
      _userProfile = await _authService.restoreSession();
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring session: $e');
      _userProfile = null;
      notifyListeners();
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final userId = await _authService.currentUserId;
      if (userId == null) return;

      _userProfile = await _userService.getUserProfile(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signIn(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String givenName,
    required String middleName,
    required String lastName,
    required String address,
    required int age,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required String placeOfBirth,
    required String civilStatus,
    required String gender,
    File? profilePhoto,
    File? validIdFront,
    File? validIdBack,
    String? idType,
    String? idNumber,
    DateTime? idIssuedAt,
    DateTime? idExpiryAt,
    bool livenessVerified = false,
    Map<String, dynamic>? kycAiResult,
    bool isIndigent = false,
    String? indigencyReason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if username exists
      final usernameExists = await _authService.isUsernameExists(username);
      if (usernameExists) {
        _error = 'Username already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if email exists
      final emailExists = await _authService.isEmailExists(email);
      if (emailExists) {
        _error = 'Email already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Upload profile photo if provided (before creating profile)
      String? profilePhotoUrl;
      if (profilePhoto != null) {
        // We'll upload with a temporary ID, then update after user creation
        final tempId = Helpers.now().millisecondsSinceEpoch.toString();
        profilePhotoUrl = await _userService.uploadProfilePhoto(
          tempId,
          profilePhoto,
        );
      }

      // Upload the ID images. The front is stored in `valid_id_url`,
      // the back in `valid_id_back_url`.
      String? validIdUrl;
      String? validIdBackUrl;
      if (validIdFront != null) {
        final tempId = Helpers.now().millisecondsSinceEpoch.toString();
        validIdUrl = await _userService.uploadValidId(tempId, validIdFront);
      }
      if (validIdBack != null) {
        final tempId = Helpers.now().millisecondsSinceEpoch.toString();
        validIdBackUrl = await _userService.uploadValidId(tempId, validIdBack);
      }

      // Sign up with custom auth (creates profile with hashed password).
      // Registration never self-approves: the profile is inserted pending and
      // an officer decides later.
      _userProfile = await _authService.signUp(
        email: email,
        password: password,
        username: username,
        givenName: givenName,
        middleName: middleName,
        lastName: lastName,
        address: address,
        age: age,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        placeOfBirth: placeOfBirth,
        civilStatus: civilStatus,
        gender: gender,
        profilePhotoUrl: profilePhotoUrl,
        validIdUrl: validIdUrl,
        validIdBackUrl: validIdBackUrl,
        idType: idType,
        idNumber: idNumber,
        idIssuedAt: idIssuedAt,
        idExpiryAt: idExpiryAt,
        livenessVerified: livenessVerified,
        kycAiResult: kycAiResult,
        isIndigent: isIndigent,
        indigencyReason: indigencyReason,
      );

      // Official-side fan-out: a new registration is waiting for review.
      // Best-effort — a notification failure must never fail registration.
      try {
        await _notificationService.notifyRoles(
          roles: [AppRoles.captain, AppRoles.legacyAdmin],
          title: 'New registration to review',
          message:
              '${_userProfile?.fullName ?? 'A new citizen'} just registered '
              'and is awaiting approval.',
          type: 'system',
        );
      } catch (e) {
        debugPrint('Registration fan-out notification failed: $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _userProfile = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update user profile (for citizen profile editing)
  Future<bool> updateProfile({
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
    File? profilePhoto,
    File? validId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _userProfile?.id;
      if (userId == null) {
        _error = 'User not logged in';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      String? profilePhotoUrl;
      if (profilePhoto != null) {
        profilePhotoUrl = await _userService.uploadProfilePhoto(
          userId,
          profilePhoto,
        );
      }

      String? validIdUrl;
      if (validId != null) {
        validIdUrl = await _userService.uploadValidId(userId, validId);
      }

      _userProfile = await _userService.updateUserProfile(
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
        profilePhotoUrl: profilePhotoUrl,
        validIdUrl: validIdUrl,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
