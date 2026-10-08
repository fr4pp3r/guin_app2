import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHelper {
  /// Generates a bcrypt-style hash from a password
  /// For web compatibility, we use SHA-256 with a salt
  static String hashPassword(String password) {
    // Generate a unique salt based on timestamp
    final salt = DateTime.now().millisecondsSinceEpoch.toString();

    // Combine password with salt and hash
    final bytes = utf8.encode(password + salt);
    final hash = sha256.convert(bytes);

    // Return salt:hash format for verification
    return '$salt:${hash.toString()}';
  }

  /// Verifies a password against a stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      // Split the stored hash to get salt and hash
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final originalHash = parts[1];

      // Hash the provided password with the same salt
      final bytes = utf8.encode(password + salt);
      final hash = sha256.convert(bytes);

      // Compare hashes
      return hash.toString() == originalHash;
    } catch (e) {
      return false;
    }
  }

  /// Validates password strength
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null; // Password is valid
  }
}
