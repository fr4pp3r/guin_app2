import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/services/face_match_service.dart';

void main() {
  group('FaceMatchPolicy.decide', () {
    test('scores at or above the threshold are a match', () {
      expect(FaceMatchPolicy.decide(0.92), FaceMatchBand.match);
      expect(FaceMatchPolicy.decide(0.5), FaceMatchBand.match);
    });

    test('the middle band is uncertain', () {
      expect(FaceMatchPolicy.decide(0.49), FaceMatchBand.uncertain);
      expect(FaceMatchPolicy.decide(0.3), FaceMatchBand.uncertain);
    });

    test('low scores are a mismatch', () {
      expect(FaceMatchPolicy.decide(0.29), FaceMatchBand.mismatch);
      expect(FaceMatchPolicy.decide(-1), FaceMatchBand.mismatch);
    });
  });
}
