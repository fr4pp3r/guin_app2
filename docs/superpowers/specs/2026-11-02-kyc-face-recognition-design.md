# KYC face recognition + auto-capture — design

Date: 2026-11-02
Status: awaiting approval

## Intent

Thesis panel said the system's AI is "just a chatbot" and asked for face recognition.
Today `id-verifier` (Gemini) already reads the ID and the selfie and reports spoof/quality
signals, but nothing ever *compares the two faces* — `_kyc.ts` explicitly excludes face
match. The selfie is also captured by hand, and `liveness_verified` is currently set by
"a selfie File exists", which a gallery upload satisfies.

So: one on-device face match (selfie ↔ ID portrait) that produces a number a reviewer can
see and a student can report accuracy for, plus real gating before the shutter fires.

## Goals

- 1:1 face verification between the registration selfie and the ID front photo.
- A stored, visible match score with a threshold — tunable and reportable.
- Self-capture without a shutter tap, gated on a real detected face.
- Never block registration (same rule as every other AI feature in this app).

## Non-goals

- Not biometric authentication, not 1:N identification, not a replacement for human approval.
- No passive anti-spoof model. Photo-of-a-photo is only partly covered (see Limitations).
- No selfie storage, unless the approval question below says otherwise.
- No threshold auto-tuning, no per-device calibration.

## Constraints

- Cloud face verification is out: Azure face verify/identify is a gated "Limited Access"
  feature unavailable on the free tier. AWS/GCP equivalents are similarly gated.
- `flutter test` cannot run TFLite, so match decisions must sit in pure Dart to be testable.
- The app ships to web (`flutter run -d chrome` is a documented command). The chosen
  package's embedding APIs throw `UnsupportedError` on web, so web must skip and degrade.
- `flutter analyze` must stay at zero errors.

## Approaches considered

1. **Gemini prompt** (send both images, ask "same person?"). Cheapest, no new deps. Rejected:
   no threshold, no accuracy figure, and it does not answer a panel that already doubts the AI.
2. **Cloud face API.** Rejected: gated, paid, and sends biometrics off-device.
3. **`google_mlkit_face_detection` + hand-wired TFLite embedding model.** Works, but means
   sourcing and licensing a model asset, writing alignment, and managing one isolate.
4. **`face_detection_tflite` 6.10.1 (chosen).** Apache-2.0, models bundled (BlazeFace +
   MobileFaceNet 192-dim), auto eye-landmark alignment, `getFaceEmbedding()` +
   `FaceDetector.compareFaces()` returning similarity in [-1, 1] with documented bands
   (>0.6 same, >0.5 probable, <0.3 different), inference on a background isolate, eye-open
   probability and head pose in `full` mode, live `detectFacesFromCameraImage` with
   `maxDim`/`FrameThrottle`. Requires Flutter 3.47.5+ — the repo is on 3.47.5.

## Design

### Dependency

`face_detection_tflite: ^6.10.1`. Fallback if pub resolution conflicts with the existing
tree: `offline_face_recognition` (MLKit detect + MobileFaceNet, MIT, Android/iOS only).

### New service — `lib/services/face_match_service.dart`

Mirrors `AiService`'s contract: `Future<...>?` returning null on any failure, never throwing
into the caller.

- `FaceMatchResult { double score; bool sameFace; int facesFound; String promptVersion-ish const; }`
- `matchSelfieToId({required Uint8List idImage, required Uint8List selfie})` →
  detect faces in both, require exactly one clear face each, embed, compare, return score.
- `FaceMatchPolicy.decide(score)` — pure Dart, `matches` / `uncertain` / `mismatch` bands
  driven by one `const faceMatchThreshold = 0.5`. This is the only part `flutter test` covers.
- Platform guard: return null on web (`kIsWeb`) and on any detector error.

### Capture — `LivenessCaptureScreen` (register_screen.dart)

Replace the decorative text challenge with a real gate that drives auto-capture:

- front camera, `startImageStream`, detect at `maxDim: 640`, `FaceDetectionMode.fast`
  (eye-open needs `full`; use `full` only on the confirming frames), drop frames while busy,
  process roughly every 3rd frame.
- capture when: exactly one face, width ≥ 25% of frame, `|yaw| ≤ 15°`, `|pitch| ≤ 15°`,
  both `EyeOpenProbability > 0.5` — held for 3 consecutive processed frames.
- keep the existing manual button as the fallback (web, no face detected, camera denied).
- `livenessVerified` becomes true only when the auto gate captured, not when any file exists.

### Wiring — registration submit

In `_handleRegister`, alongside the existing `_runIdPreCheck`: run the match on (ID front
bytes, selfie bytes), then persist score + timestamp through `AuthService.signUp`.
On-device, so it does not lengthen the Gemini wait; wrap in try/catch and continue on null.
The gallery fallback still submits, just with `score: null` → reviewer sees "not evaluated".

### Persistence

Additive migration `supabase/migrations/20261102_kyc_face_match.sql`:

- `kyc_face_match_score numeric` (null = not evaluated)
- `kyc_face_match_at timestamptz`

Mirrored in `setup.sql`'s `users_profile` block. Client model: two nullable fields on
`UserProfile` with matching `toJson`/`fromJson`/`copyWith` entries.

### Review surface

`user_registration_detail_screen.dart` gains one row next to the existing AI verdict:
score, band (match/uncertain/mismatch), "not evaluated" when null. Advisory only — the
approve/reject handlers are untouched.

### Accuracy harness (thesis artefact)

`tool/face_match_benchmark.dart`: reads a folder of `same/` and `different/` image pairs,
prints similarity per pair and the false-accept / false-reject rate across a threshold sweep.
No UI, no app wiring. Pure Dart + the same service.

## Test / verification

- `flutter test` — pure `FaceMatchPolicy` bands (new, small), existing 116 stay green.
- `flutter analyze` — zero errors.
- `flutter build web` — must still succeed with the new dependency (guarded path).
- Manual on a device: register with a matching selfie, then with a mismatched one; confirm
  score lands on the expected side of 0.5 and appears on the review page.
- Benchmark run over a small real set to produce the number for the paper.

## Limitations (to state in the paper)

- MobileFaceNet-class 192-dim embeddings do not match ArcFace/InsightFace accuracy on hard
  pairs (twins, siblings, poor lighting, ID photos with glare or heavy print texture).
- No passive liveness: a phone screen held up to the camera may still pass.
- ID portraits are small and often textured/watermarked; the ID-side detection is the
  weakest link and can return null (reported as "not evaluated", never blocking).
- Threshold 0.5 is the package's documented "probably same person" band, not a calibrated
  operating point for this dataset. Worth reporting the sweep, not a single number.

## Resolved decision: selfie storage

**Not stored.** Score + timestamp only. No new bucket, no biometric data at rest. The
reviewer sees the score beside the ID photo but not the selfie itself.

## APK size (measured, deliberately deferred)

The dependency costs far more than estimated. Measured release builds:

| Build | arm64 libs | assets | APK |
| --- | --- | --- | --- |
| `citeease-b-0.8.1` (before) | 34.7 MB | 3.0 MB | 106.8 MB universal |
| after, per-ABI arm64 | 59.0 MB | 32.3 MB | 93.4 MB |
| after, universal | 59.0 MB x3 | 32.3 MB | 207.9 MB |

Native additions on arm64: `libdartcv.so` 8.89 MB (OpenCV), `libLiteRt.so` +
`libLiteRtClGlAccelerator.so` 8.21 MB, `libtensorflowlite_jni.so` +
`libtensorflowlite_gpu_jni.so` + `libtflite_custom_ops.so` 6.75 MB. Bundled models add
29.26 MB, of which `selfie_multiclass.tflite` (15.61 MB) is never called — this feature only
uses `mobilefacenet.tflite`, the `face_detection_*` BlazeFace variants, and
`face_landmark.tflite`.

`shortcut: shipping the 207.9 MB universal APK for the panel/demo only; revisit if the
system is adopted — first lever is excluding the unused models (potentially ~20 MB), second
is `--split-per-abi` (93.4 MB arm64), third is swapping the embedder to an MLKit stack.`
