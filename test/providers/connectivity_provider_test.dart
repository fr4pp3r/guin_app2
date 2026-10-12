import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/providers/connectivity_provider.dart';

void main() {
  group('ConnectivityProvider.isOfflineFrom', () {
    test('no results means offline', () {
      expect(ConnectivityProvider.isOfflineFrom([]), isTrue);
    });

    test('only none means offline', () {
      expect(
        ConnectivityProvider.isOfflineFrom([ConnectivityResult.none]),
        isTrue,
      );
      expect(
        ConnectivityProvider.isOfflineFrom([
          ConnectivityResult.none,
          ConnectivityResult.none,
        ]),
        isTrue,
      );
    });

    test('any real interface means online', () {
      expect(
        ConnectivityProvider.isOfflineFrom([ConnectivityResult.wifi]),
        isFalse,
      );
      expect(
        ConnectivityProvider.isOfflineFrom([
          ConnectivityResult.none,
          ConnectivityResult.mobile,
        ]),
        isFalse,
      );
    });
  });
}
