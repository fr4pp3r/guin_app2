# KYC Face Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add on-device 1:1 face verification (registration selfie vs. ID portrait) plus real face-gated auto-capture to KYC registration.

**Architecture:** One new service wraps `face_detection_tflite` (BlazeFace detect + MobileFaceNet 192-dim embed + cosine compare). The selfie screen drives the same detector over the camera stream and fires the shutter itself. The score is a nullable column on `users_profile`, advisory only — a human still approves. No selfie image is stored.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4, `face_detection_tflite ^6.10.1`, `camera ^0.11.0+2` (already present), Supabase (additive migration).

**Spec:** `docs/superpowers/specs/2026-11-02-kyc-face-recognition-design.md`

## Global Constraints

- `flutter analyze` must produce **zero errors**. Pre-existing `info` lints are tolerated; add no new ones, do not churn existing ones.
- `flutter test` must stay green (116 existing offline tests + the new ones).
- On-device features never block the core workflow. A null result means "not evaluated" and registration proceeds unchanged.
- Guard native-only calls: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)` — same shape as `lib/services/push_service.dart:94`.
- `flutter build web` must still succeed. No new pubspec asset entries, no `dart:io` use outside `kIsWeb`-guarded paths.
- Do **not** store the selfie image. No new storage bucket.
- Do **not** touch: approval/reject handlers, `role_access.dart`, `IdVerificationSuggestion`'s fields, the `id-verifier` edge handler, `kyc_method` values.
- Do **not** commit. The working tree already holds unrelated uncommitted work (residency + document AI); leave staging to the user.
- New user-visible strings go in all three of `lib/l10n/app_{en,fil,ceb}.arb`; copy the English text into `fil`/`ceb` rather than leaving them empty.

## Review Focus

- A registration where the ID portrait is undetectable (glare, print texture, tiny portrait) must store `null`, not a false `mismatch`.
- A selfie from the gallery must not be recorded as liveness-verified.
- Two faces in the selfie frame (bystander) must not silently match one of them.
- The camera screen must release the controller and detector on pop/back, or the next attempt fails to open the camera.
- Web/desktop must fall through to the existing manual path rather than throwing.

---

### Task 1: Face-match service + policy test

**Files:**
- Modify: `pubspec.yaml` (`dependencies:`, after `camera: ^0.11.0+2`)
- Create: `lib/services/face_match_service.dart`
- Test: `test/automation/face_match_policy_test.dart`

**Interfaces:**
- Produces:
  - `enum FaceMatchBand { match, uncertain, mismatch }`
  - `class FaceMatchPolicy { static const double samePersonThreshold = 0.5; static FaceMatchBand decide(double score); }`
  - `class FaceMatchResult { const FaceMatchResult({required double score, required FaceMatchBand band, required int facesInId, required int facesInSelfie}); final double score; final FaceMatchBand band; final int facesInId; final int facesInSelfie; }`
  - `class FaceMatchService { Future<FaceMatchResult?> matchSelfieToId({required Uint8List idImage, required Uint8List selfie}); }`

- [ ] **Step 1: Add the dependency**

`pubspec.yaml`, dependency block, after `camera: ^0.11.0+2`:

```yaml
  # On-device face detection + MobileFaceNet embeddings (KYC face match, no API key)
  face_detection_tflite: ^6.10.1
```

Run `flutter pub get`. Expected: resolves. If it conflicts with the existing tree, stop and report — do not force versions.

- [ ] **Step 2: Write the failing test**

`test/automation/face_match_policy_test.dart`:

```dart
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
```

Replace `guin_app` with the actual package name from `pubspec.yaml` (`name:`).

- [ ] **Step 3: Run it and confirm it fails**

Run: `flutter test test/automation/face_match_policy_test.dart`
Expected: FAIL — `face_match_service.dart` does not exist.

- [ ] **Step 4: Implement `lib/services/face_match_service.dart`**

`decide`: `score >= samePersonThreshold` → `match`; `score >= 0.3` → `uncertain`; else `mismatch`.

`matchSelfieToId` mirrors `AiService`'s contract — returns null, never throws:

```dart
Future<FaceMatchResult?> matchSelfieToId({
  required Uint8List idImage,
  required Uint8List selfie,
}) async {
  // null on unsupported platform, no face, ambiguous faces, or any detector error
}
```

Body requirements:
- early `null` on unsupported platform (see Global Constraints);
- one `FaceDetector` for the whole call; `dispose()` it in `finally`;
- detect with `FaceDetectionMode.full` (eye landmarks are required for embedding alignment);
- require **exactly one** face in each image; 0 or ≥2 → `null`;
- `getFaceEmbedding(face, bytes)` for each, then `FaceDetector.compareFaces(idEmbedding, selfieEmbedding)`;
- wrap everything in `try/catch` → `debugPrint` + `null`.

`shortcut: one detector at the default model for both images; if ID portraits fail detection, create a separate detector with FaceDetectionModel.fullRange for the ID.`

- [ ] **Step 5: Run the test and the analyzer**

Run: `flutter test test/automation/face_match_policy_test.dart` → PASS.
Run: `flutter analyze` → zero errors.

---

### Task 2: Face-gated auto-capture

**Files:**
- Modify: `lib/screens/auth/register_screen.dart` (imports; new `LivenessCaptureResult`; `LivenessCaptureScreen` + its state, ~1885-2137; `_captureSelfie`, 183-197; state fields, 57-77)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fil.arb`, `lib/l10n/app_ceb.arb`

**Interfaces:**
- Produces:
  - `class LivenessCaptureResult { const LivenessCaptureResult({required File file, required bool gatePassed}); final File file; final bool gatePassed; }`
  - `LivenessCaptureScreen` now pops `LivenessCaptureResult`, not `File`.
  - New state field on `_RegisterScreenState`: `bool _selfieGatePassed = false;`
  - l10n keys (all three files, English text copied): `authFaceHoldStill` ("Hold still…"), `authFaceMoveCloser` ("Move closer"), `authFaceLookStraight` ("Look straight ahead").
- Consumed by Task 4 (`_selfieGatePassed`) and Task 5 (no new keys there — its keys are added here in Step 6).

- [ ] **Step 1: Capture result type**

Add `LivenessCaptureResult` above `LivenessCaptureScreen`. Change every `Navigator.pop(context, ...)` in the capture screen to pop a `LivenessCaptureResult`, and update `_captureSelfie` to `Navigator.push<LivenessCaptureResult>`.

- [ ] **Step 2: Camera stream**

In `_initCamera`, add `imageFormatGroup: ImageFormatGroup.yuv420` to the `CameraController` constructor (prevents JPEG fallback on Android). After `initialize()`, create the detector:

```dart
_detector = await FaceDetector.create();
```

Start the stream on the front camera and stop it in `dispose()` before disposing the controller and detector.

- [ ] **Step 3: Frame gate**

Process frames with a `bool _busy` throttle (drop the frame if busy — never queue). Per processed frame call
`_detector!.detectFacesFromCameraImage(image, rotation: rotationForFrame(...), mode: FaceDetectionMode.full, maxDim: 640)`.

Count consecutive frames where all of these hold, resetting to 0 otherwise:
- exactly one face;
- `face.widthFraction >= 0.25`;
- `face.headEulerAngleY` and `face.headEulerAngleX` non-null and `≤ 15` in absolute value;
- `face.leftEyeOpenProbability` and `face.rightEyeOpenProbability` both `> 0.5`.

At 3 consecutive frames, stop the stream and call `_capture(gatePassed: true)`.

- [ ] **Step 4: Manual fallback**

The shutter button calls `_capture(gatePassed: false)`. Replace the decorative `_challenges`/`_newChallenge` text with a live status line driven by the gate (`authFaceMoveCloser` when no face or too small, `authFaceLookStraight` when pose fails, `authFaceHoldStill` when counting frames). Keep the close button and the existing black-layout style.

- [ ] **Step 5: Wire the caller**

`_captureSelfie` (register_screen.dart:183-197): read the result, then

```dart
setState(() {
  _selfiePhoto = result.file;
  _selfieGatePassed = result.gatePassed;
});
```

The gallery fallback keeps `_selfiePhoto` and leaves `_selfieGatePassed = false`. Add the field to the state-field block (57-77).

- [ ] **Step 6: l10n**

Add the three `authFace*` keys **and** Task 5's keys (`auserKycFaceMatchLabel`, `auserKycFaceMatchSame`, `auserKycFaceMatchUncertain`, `auserKycFaceMatchDifferent`) to all three arb files. English values:

```
"authFaceHoldStill": "Hold still…",
"authFaceMoveCloser": "Move closer",
"authFaceLookStraight": "Look straight ahead",
"auserKycFaceMatchLabel": "Face match",
"auserKycFaceMatchSame": "Same person",
"auserKycFaceMatchUncertain": "Uncertain",
"auserKycFaceMatchDifferent": "Different person",
```

- [ ] **Step 7: Verify**

Run: `flutter analyze` → zero errors. Run: `flutter test` → green.

---

### Task 3: Persistence

**Files:**
- Modify: `lib/models/user_profile.dart` (fields ~25-45, ctor ~85-92, `fromJson` ~155-162, `toJson` ~197-204, `copyWith` ~237-244 and ~275-282)
- Modify: `lib/services/auth_service.dart` (params 27-52, insert map 84-122)
- Create: `supabase/migrations/20261102_kyc_face_match.sql`
- Modify: `setup.sql` (users_profile block, 197-222)

**Interfaces:**
- Produces: `UserProfile.kycFaceMatchScore` (`double?`), `UserProfile.kycFaceMatchAt` (`DateTime?`), and `AuthService.signUp(..., double? kycFaceMatchScore)`.
- Consumed by Task 4 (passes the score) and Task 5 (reads it).

- [ ] **Step 1: Model fields**

Add `final double? kycFaceMatchScore;` and `final DateTime? kycFaceMatchAt;` beside the other KYC fields, and thread them through the constructor, `fromJson` (`json['kyc_face_match_score']` — handle `num` as well as `double`; `kyc_face_match_at` via the existing `_timestampFromDynamic`), `toJson`, and `copyWith` with the same `??` shape as the neighbours.

- [ ] **Step 2: signUp**

Add the parameter after `kycAiResult` in the signature. In the insert map, after `'kyc_ai_result': kycAiResult,`:

```dart
            // On-device face match (selfie vs ID portrait). Advisory only.
            'kyc_face_match_score': kycFaceMatchScore,
            if (kycFaceMatchScore != null)
              'kyc_face_match_at': Helpers.now().toIso8601String(),
```

- [ ] **Step 3: Migration**

`supabase/migrations/20261102_kyc_face_match.sql` — copy the header-comment style of `supabase/migrations/20261022_incident_report_geo.sql`, and add both columns with `ADD COLUMN IF NOT EXISTS`:

```sql
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_face_match_score DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS kyc_face_match_at    TIMESTAMPTZ;
```

Comment must state: nullable means "not evaluated"; the score is advisory and never gates approval.

- [ ] **Step 4: Mirror in setup.sql**

In the `users_profile` KYC block (197-222), after `kyc_ai_result JSONB,` add the same two columns in `setup.sql` style.

- [ ] **Step 5: Verify**

Run: `flutter analyze` → zero errors. Run: `flutter test test/automation/kyc_models_test.dart` → green (round-trip tests still pass with the new nullable fields).

---

### Task 4: Submit wiring

**Files:**
- Modify: `lib/screens/auth/register_screen.dart` (`_handleRegister`, 422-525)

**Interfaces:**
- Consumes: `FaceMatchService.matchSelfieToId` (Task 1), `_selfieGatePassed` (Task 2), `AuthService.signUp(kycFaceMatchScore:)` (Task 3).

- [ ] **Step 1: Run the match**

In `_handleRegister`, after the `_runIdPreCheck()` block and before `authProvider.signUp(...)`:

```dart
FaceMatchResult? faceMatch;
final selfie = _selfiePhoto;
final idFront = _validIdFront;
if (selfie != null && idFront != null) {
  try {
    faceMatch = await FaceMatchService().matchSelfieToId(
      idImage: await idFront.readAsBytes(),
      selfie: await selfie.readAsBytes(),
    );
  } catch (e) {
    debugPrint('Face match failed: $e');
  }
}
```

- [ ] **Step 2: Pass it on**

In the `authProvider.signUp(...)` call: `livenessVerified: _selfieGatePassed,` (replacing the `_selfiePhoto != null` expression) and `kycFaceMatchScore: faceMatch?.score,`.

- [ ] **Step 3: Verify**

`flutter analyze` → zero errors; `flutter test` → green. Then `flutter build web` → succeeds (the match is skipped on web via the platform guard).

---

### Task 5: Reviewer surface

**Files:**
- Modify: `lib/screens/admin/user_registration_detail_screen.dart` (mount point 307; row renderer 1060-1132; pill helper ~884-919)

**Interfaces:**
- Consumes: `UserProfile.kycFaceMatchScore` (Task 3), `FaceMatchPolicy.decide` (Task 1), l10n keys (Task 2).

- [ ] **Step 1: Mount the row**

At line 307, beside `if (_user.kycAiResult != null) _buildAiSection(),` add:

```dart
          if (_user.kycFaceMatchScore != null) _buildFaceMatchRow(),
```

So the match shows even when the AI pre-check failed.

- [ ] **Step 2: Render it**

`_buildFaceMatchRow()` returns the same panel shape as `_buildAiSection` (ExpansionTile, `Icons.face_retouching_natural`, label `l10n.auserKycFaceMatchLabel`), whose single child is one row:

- label `l10n.auserKycFaceMatchLabel`, width-118 label like the existing `addRow` helper;
- value = `l10n.auserKycFaceMatchSame` / `Uncertain` / `Different` from `FaceMatchPolicy.decide(_user.kycFaceMatchScore!)`, coloured teal `0xFF00796B` / orange `800` / red `700`, with the raw score to two decimals beside it;
- the existing advisory italic note underneath (`l10n.auserAiAdvisoryNote`).

- [ ] **Step 3: Verify**

`flutter analyze` → zero errors; `flutter test` → green. Manually confirm the row is absent on a user with a null score.

---

### Task 6: Accuracy reporting script

**Files:**
- Create: `tool/face_match_benchmark.dart`
- Test: `test/automation/face_match_benchmark_test.dart`

**Interfaces:**
- Produces: `class BenchmarkRow { final bool samePerson; final double score; }` and
  `String formatSweep(List<BenchmarkRow> rows)` returning the report text, plus
  `Map<double, ({double far, double frr})> sweep(List<BenchmarkRow> rows, List<double> thresholds)`.

This is pure Dart on purpose — `flutter test` can run it, and it needs no camera or engine. The scores are collected from the app (register known same/different pairs, read the score off the review page) and written to a CSV of `same|different,score`.

- [ ] **Step 1: Write the failing test**

`test/automation/face_match_benchmark_test.dart`: feed a fixed 6-row list (3 `same` at 0.81/0.64/0.44, 3 `different` at 0.41/0.22/0.77) and assert at threshold 0.5: `far == 1/3` (the 0.77 impostor) and `frr == 1/3` (the 0.44 genuine). Assert `formatSweep` output contains the header and one line per threshold.

- [ ] **Step 2: Run it, confirm it fails**

Run: `flutter test test/automation/face_match_benchmark_test.dart` → FAIL (file missing).

- [ ] **Step 3: Implement**

`tool/face_match_benchmark.dart` with a `main(List<String> args)` reading `<path>.csv` (`label,score` per line, `#` comments skipped), sweeping 0.30→0.70 step 0.05, printing a fixed-width table. Metrics: FAR = impostors accepted / impostors; FRR = genuines rejected / genuines.

- [ ] **Step 4: Run it, confirm it passes**

Run: `flutter test test/automation/face_match_benchmark_test.dart` → PASS.

---

### Task 7: Final verification

- [ ] `flutter analyze` → zero errors.
- [ ] `flutter test` → all green (116 existing + new).
- [ ] `flutter build web` → succeeds.
- [ ] `flutter build apk --debug` (or `--split-per-abi --release`) → note the size delta versus the pre-change build; record it for the paper.
- [ ] On a device: register with a matching selfie → score at or above 0.5, row appears on the review page; register with someone else's selfie → below 0.5.
- [ ] On a device: the shutter fires without a tap when a face is held still; back-navigating and re-entering the capture screen re-opens the camera.
- [ ] Update `DOCUMENTATION.md` §13 known-gaps line about KYC face matching, one sentence.
