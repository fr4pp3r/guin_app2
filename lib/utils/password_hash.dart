import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHash {
  // Generate a simple salt (in production, use a more robust approach)
  static String _generateSalt() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(timestamp);
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  // Hash a password with salt using SHA-256
  // Note: For production, consider using bcrypt via a backend API
  // This is a simplified version for demonstration
  static String hashPassword(String password, {String? salt}) {
    final useSalt = salt ?? _generateSalt();
    final saltedPassword = password + useSalt;
    final bytes = utf8.encode(saltedPassword);
    final hash = sha256.convert(bytes);

    // Return salt:hash format so we can verify later
    return '$useSalt:${hash.toString()}';
  }

  // Verify a password against a stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      // Split stored hash into salt and hash
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final hash = parts[1];

      // Hash the provided password with the same salt
      final saltedPassword = password + salt;
      final bytes = utf8.encode(saltedPassword);
      final computedHash = sha256.convert(bytes).toString();

      // Compare hashes
      return computedHash == hash;
    } catch (e) {
      return false;
    }
  }

  // Generate a hash for a given password (convenience method)
  static String generate(String password) {
    return hashPassword(password);
  }

  // Verify convenience method
  static bool verify(String password, String hash) {
    return verifyPassword(password, hash);
  }
}
