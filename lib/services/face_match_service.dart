import 'package:flutter/foundation.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

/// Which side of the human judgement the on-device face comparison falls in.
enum FaceMatchBand { match, uncertain, mismatch }

/// Pure banding of a cosine similarity score into [FaceMatchBand].
///
/// Kept free of the detector on purpose: `flutter test` cannot run TFLite, so
/// this is the only unit-testable piece. `>= 0.5` is the package's documented
/// "probably same person" band (threshold is advisory, never gates approval).
class FaceMatchPolicy {
  const FaceMatchPolicy._();

  static const double samePersonThreshold = 0.5;

  static FaceMatchBand decide(double score) {
    if (score >= samePersonThreshold) return FaceMatchBand.match;
    if (score >= 0.3) return FaceMatchBand.uncertain;
    return FaceMatchBand.mismatch;
  }
}

/// Outcome of one 1:1 face comparison. Advisory only — a human still approves.
class FaceMatchResult {
  const FaceMatchResult({
    required this.score,
    required this.band,
    required this.facesInId,
    required this.facesInSelfie,
  });

  /// Cosine similarity in [-1, 1] between the two face embeddings.
  final double score;

  final FaceMatchBand band;

  /// Faces detected in the ID front image (1 when usable; informational).
  final int facesInId;
  final int facesInSelfie;
}

/// On-device 1:1 face verification (registration selfie vs. ID portrait).
///
/// Mirrors `AiService`'s contract: null on ANY failure (unsupported platform,
/// no face, ambiguous faces, detector/embedding error) — callers must treat
/// null as "not evaluated" and never let it block registration. No image is
/// sent anywhere; embedding inference happens on the device.
class FaceMatchService {
  FaceMatchService();

  Future<FaceMatchResult?> matchSelfieToId({
    required Uint8List idImage,
    required Uint8List selfie,
  }) async {
    // Native TFLite only: web/desktop throw from the embedding APIs.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint(
        'FaceMatchService: skipped on unsupported platform — '
        'registration proceeds without a face-match score',
      );
      return null;
    }
    try {
      final detector = await FaceDetector.create();
      try {
        // `full` mode: eye landmarks are required for embedding alignment.
        final idFaces = await detector.detectFacesFromBytes(
          idImage,
          mode: FaceDetectionMode.full,
        );
        final selfieFaces = await detector.detectFacesFromBytes(
          selfie,
          mode: FaceDetectionMode.full,
        );
        if (idFaces.length != 1 || selfieFaces.length != 1) {
          debugPrint(
            'FaceMatchService: need exactly one face in each image '
            '(id=${idFaces.length}, selfie=${selfieFaces.length}) — '
            'returning null',
          );
          return null;
        }
        final idEmbedding =
            await detector.getFaceEmbedding(idFaces.single, idImage);
        final selfieEmbedding =
            await detector.getFaceEmbedding(selfieFaces.single, selfie);
        final score = FaceDetector.compareFaces(idEmbedding, selfieEmbedding);
        return FaceMatchResult(
          score: score,
          band: FaceMatchPolicy.decide(score),
          facesInId: idFaces.length,
          facesInSelfie: selfieFaces.length,
        );
      } finally {
        await detector.dispose();
      }
    } catch (e) {
      debugPrint('FaceMatchService: match failed — returning null. ($e)');
      return null;
    }
  }
}
