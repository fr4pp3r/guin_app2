// Run this script to generate the admin password hash
// Command: dart generate_admin_hash.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateSalt() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final bytes = utf8.encode(timestamp);
  return sha256.convert(bytes).toString().substring(0, 16);
}

String hashPassword(String password, {String? salt}) {
  final useSalt = salt ?? generateSalt();
  final saltedPassword = password + useSalt;
  final bytes = utf8.encode(saltedPassword);
  final hash = sha256.convert(bytes);

  return '$useSalt:${hash.toString()}';
}

void main() {
  final password = 'Admin@123456';
  final hash = hashPassword(password);

  print('Password: $password');
  print('Hash: $hash');
  print('\nCopy the hash above and use it in your SQL script.');
}
