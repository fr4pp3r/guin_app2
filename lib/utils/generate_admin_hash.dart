import 'package:guin_app/utils/password_hash.dart';

void main() {
  // Generate password hash for admin user
  // Password: Admin@123456

  final password = 'Admin@123456';
  final hash = PasswordHash.generate(password);

  print('==============================================');
  print('ADMIN PASSWORD HASH GENERATOR');
  print('==============================================');
  print('Password: $password');
  print('Hash: $hash');
  print('==============================================');
  print('');
  print('Copy this hash and use it in create_admin_user.sql');
  print('');

  // Verify the hash works
  final isValid = PasswordHash.verify(password, hash);
  print('Verification test: ${isValid ? "PASSED ✓" : "FAILED ✗"}');
}
