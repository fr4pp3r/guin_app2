import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/utils/maps_launcher.dart';

void main() {
  group('MapsLauncher.directionsUri', () {
    test('targets the incident pin as the destination', () {
      final uri = MapsLauncher.directionsUri(latitude: 10.3167, longitude: 123.8854);

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '10.3167,123.8854');
    });

    test('omits the origin so Google Maps uses the device location', () {
      final uri = MapsLauncher.directionsUri(latitude: 14.5995, longitude: 120.9842);

      // No `origin` parameter: the hand-off starts from "current location".
      expect(uri.queryParameters.containsKey('origin'), isFalse);
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('formats negative and high-precision coordinates verbatim', () {
      final uri = MapsLauncher.directionsUri(latitude: -8.23451, longitude: 124.00009);

      expect(uri.queryParameters['destination'], '-8.23451,124.00009');
    });
  });
}
