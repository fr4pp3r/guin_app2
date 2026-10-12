import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/user_profile.dart';
import 'package:guin_app/utils/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile _profile({String role = 'citizen', bool isApproved = true}) =>
    UserProfile.fromJson({
      'id': 'user-1',
      'username': 'juandelacruz',
      'email': 'juan@example.com',
      'given_name': 'Juan',
      'middle_name': 'Dela',
      'last_name': 'Cruz',
      'address': 'Barangay San Isidro',
      'age': 30,
      'date_of_birth': '1996-01-01',
      'place_of_birth': 'Manila',
      'civil_status': 'Single',
      'gender': 'Male',
      'phone_number': '09171234567',
      'is_approved': isApproved,
      'registration_status': 'approved',
      'role': role,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns null when no snapshot is stored', () async {
    expect(await SessionManager.getProfileSnapshot(), isNull);
  });

  test('round-trips a saved profile snapshot', () async {
    await SessionManager.saveProfileSnapshot(_profile());

    final restored = await SessionManager.getProfileSnapshot();
    expect(restored, isNotNull);
    expect(restored!.id, 'user-1');
    expect(restored.role, 'citizen');
    expect(restored.isApproved, isTrue);
    expect(restored.fullName, 'Juan Dela Cruz');
  });

  test('clearProfileSnapshot removes the snapshot', () async {
    await SessionManager.saveProfileSnapshot(_profile());
    await SessionManager.clearProfileSnapshot();
    expect(await SessionManager.getProfileSnapshot(), isNull);
  });

  test('clearSession also removes the profile snapshot', () async {
    await SessionManager.saveSession(
      userId: 'user-1',
      email: 'juan@example.com',
      username: 'juandelacruz',
      role: 'citizen',
    );
    await SessionManager.saveProfileSnapshot(_profile());

    await SessionManager.clearSession();

    expect(await SessionManager.getProfileSnapshot(), isNull);
    expect(await SessionManager.isLoggedIn(), isFalse);
  });
}
