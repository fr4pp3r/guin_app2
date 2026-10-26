import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/utils/role_access.dart';

void main() {
  test('canEditUserInfo is limited to the captain, secretary and admin', () {
    for (final role in [
      AppRoles.captain,
      AppRoles.secretary,
      AppRoles.legacyAdmin,
    ]) {
      expect(AppRoles.canEditUserInfo(role), isTrue, reason: role);
    }
    for (final role in [
      AppRoles.citizen,
      AppRoles.treasurer,
      AppRoles.kagawadRepresentative,
      AppRoles.barangayTanod,
      '',
    ]) {
      expect(AppRoles.canEditUserInfo(role), isFalse, reason: role);
    }
  });
}
