# Face-Matched Auto-Approval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Officials enroll residents' face samples; signup matches the liveness selfie against the sample enrolled under the typed name and auto-approves on a match (blocks otherwise) — mobile only.

**Architecture:** Reuse the shipped on-device `FaceDetector` embeddings. One new standalone edge function `face-match` (service-role, PostgREST raw fetch, house `email-otp` pattern) owns a new `face_enrollments` table (RLS enabled, zero policies — deliberate deviation) and a new **private** `face-samples` bucket. The client embeds stills, the server computes cosine similarity and the threshold.

**Tech Stack:** Flutter/Dart, supabase_flutter `functions.invoke`, Deno edge function, Postgres.

**Spec:** `docs/superpowers/specs/2026-11-23-face-auto-approval-design.md` (read both; spec wins on intent)

## Global Constraints

- No new pub dependencies. Dart `^3.10.1`. Commit style `feat(scope): ...` on `main`.
- `flutter analyze`: zero errors, no NEW info lints (~56 pre-existing tolerated).
- `flutter test`: all pass. `npx --yes deno@latest check supabase/functions/face-match/index.ts` exits 0.
- Every new user-facing string gets an l10n key in ALL THREE arb files (`app_en.arb`, `app_fil.arb`, `app_ceb.arb`), then `flutter gen-l10n`.
- `face_enrollments` table: `ENABLE ROW LEVEL SECURITY` and **no policies** (service-role only via the function). The `face-samples` bucket: `public = false`, no storage policy.
- Face gate blocks on failure (`null` verify result = block). It is the one deliberate violation of the "AI never blocks" house rule; never silently approve.
- Threshold 0.5 lives ONLY in the edge function. Mirror `FaceMatchService`'s platform guard (`kIsWeb` / android / iOS) and its null-on-failure contract.
- The signup path's existing advisory selfie-vs-ID score keeps its column; the new enrolled-match score gets its own columns (`kyc_enrolled_face_score`, `kyc_enrolled_face_at`).

## Review Focus

1. **Same name, two residents** (father/son): verify must score against ALL rows with that normalized name and take the best score — pin with a server-logic walkthrough in Task 2 review; client test via `normalizeName` tests in Task 3.
2. **Function unreachable / garbage response**: mobile signup must block with a retryable message, never fall through to approval or to the old pending flow silently — pinned by Task 5's explicit `return` paths (code review).
3. **Web/desktop**: no TFLite ⇒ no gate ⇒ old pending flow byte-for-byte unchanged — pinned by Task 3's platform guard mirroring `FaceMatchService` and Task 5's `gateSupported` guard.
4. **Name drift between enroll and signup**: one `normalizeName` implementation used by both screens — pinned by Task 3 unit tests.
5. **Biometric leak**: no public URL for face photos anywhere; list endpoint returns 1-hour signed URLs only — code review in Task 2/4.

---

### Task 1: Schema — `face_enrollments`, score columns, private bucket

**Files:**
- Create: `supabase/migrations/20261124_face_auto_approval.sql`
- Modify: `setup.sql` (mirror the same objects into the full schema)

**Interfaces:**
- Produces: table `public.face_enrollments (id uuid pk default gen_random_uuid(), full_name text not null, full_name_normalized text not null, dob date not null, embedding double precision[] not null, photo_path text not null, enrolled_by uuid null references public.users_profile(id), created_at timestamptz not null default now())`; index `face_enrollments_name_idx` on `full_name_normalized`; columns `users_profile.kyc_enrolled_face_score DOUBLE PRECISION`, `users_profile.kyc_enrolled_face_at TIMESTAMPTZ`; bucket row `('face-samples','face-samples',false,5242880,ARRAY['image/jpeg','image/jpg','image/png'])`. Task 2 relies on exactly these names.

- [ ] **Step 1:** Write `supabase/migrations/20261124_face_auto_approval.sql`: `ALTER TABLE public.users_profile ADD COLUMN IF NOT EXISTS kyc_enrolled_face_score DOUBLE PRECISION; ADD COLUMN IF NOT EXISTS kyc_enrolled_face_at TIMESTAMPTZ;` then `CREATE TABLE IF NOT EXISTS public.face_enrollments (...)` exactly as in Interfaces, the index (`CREATE INDEX IF NOT EXISTS`), `ALTER TABLE public.face_enrollments ENABLE ROW LEVEL SECURITY;` with a SQL comment stating the zero-policy deviation, and the bucket `INSERT ... ON CONFLICT (id) DO NOTHING`.
- [ ] **Step 2:** Mirror into `setup.sql`: the two columns into the `users_profile` CREATE TABLE (next to `kyc_face_match_score`, with a comment "enrolled-sample match; gates ai_verified auto-approval"), the table into SECTION 3 (grouped with `email_otps`-style service tables, same comment about zero policies), the bucket row appended to the SECTION 7 `INSERT INTO storage.buckets ... VALUES` list. Do NOT add a storage policy and do NOT add an `app_access_*` policy for it.
- [ ] **Step 3:** Sanity-check the SQL is syntactically consistent with its neighbors (no psql available locally — visual check + matching statement style). No commit-blocking command exists for SQL; the reviewer eyeballs it.
- [ ] **Step 4:** Commit: `git add supabase/migrations/20261124_face_auto_approval.sql setup.sql && git commit -m "feat(kyc): face_enrollments table + private face-samples bucket"`

### Task 2: `face-match` edge function

**Files:**
- Create: `supabase/functions/face-match/index.ts`
- Create: `supabase/functions/face-match/config.json` → `{ "verify_jwt": false }`

**Interfaces:**
- Consumes: Task 1 schema; shared helpers `corsHeaders`, `errorResponse`, `jsonResponse` from `../ai/_shared.ts` (read them first); service-role env `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- Produces (Task 3/4/5 consume this contract verbatim): `POST /functions/v1/face-match`, JSON body/action:
  - `enroll { fullName: string, dob: "YYYY-MM-DD", embedding: number[], photoBase64: string, enrolledBy?: uuid }` → `200 { ok: true, enrollmentId }`. Validates embedding (`Array.isArray`, length 32..2048, all finite) → else `400 invalid_embedding`; compresses nothing (client sends base64 PNG via `ImageCompressor`), uploads to bucket path `enrollments/<uuid>.png` via `POST ${SUPABASE_URL}/storage/v1/face-samples/enrollments/<uuid>.png` (service-role headers, `Content-Type: image/png`, binary body from base64), inserts the row with `full_name_normalized = fullName.trim().toLowerCase()` (client already normalized, server re-normalizes defensively).
  - `verify { fullName: string, embedding: number[] }` → `200 { ok: true, matched: boolean, score: number, reason?: "not_enrolled", enrollmentId?: string }`. Fetch all rows `full_name_normalized=eq.<normalized>` (PostgREST GET, service-role headers), no rows → `{ ok: true, matched: false, score: 0, reason: "not_enrolled" }`; else best cosine similarity over rows, `matched = best >= 0.5` (constant `MATCH_THRESHOLD`), include `enrollmentId` of the best row. Cosine guard: zero-norm → score 0.
  - `list {}` → `200 { ok: true, enrollments: [{ id, fullName, dob, createdAt, photoUrl }] }` ordered `created_at.desc`; `photoUrl` = 1-hour signed URL (`POST /storage/v1/object/sign/face-samples/<path>` body `{"expiresIn":3600}`, prepend `${SUPABASE_URL}/storage/v1`). Broken/missing object → `photoUrl: null`, never an error.
  - `delete { id }` → deletes the row (PostgREST DELETE `id=eq.`) then best-effort `DELETE /storage/v1/object/face-samples/<photo_path>` → `200 { ok: true }`; unknown id → `404 not_found`.
  - All errors via `errorResponse(status, code, message)`; `500 config_error` when env missing; header comment documents the contract exactly like `email-otp/index.ts` does.

- [ ] **Step 1:** Read `supabase/functions/email-otp/index.ts` and `supabase/functions/ai/_shared.ts`; follow their structure (rest helpers, router, error handling) — do not invent a new shape.
- [ ] **Step 2:** Implement the four actions per contract.
- [ ] **Step 3:** Run `npx --yes deno@latest check supabase/functions/face-match/index.ts` — Expected: exit 0.
- [ ] **Step 4:** Commit: `git add supabase/functions/face-match && git commit -m "feat(kyc): face-match edge function (enroll/verify/list/delete)"`

### Task 3: Dart model + service + offline tests (TDD)

**Files:**
- Create: `lib/models/face_gate.dart`
- Create: `lib/services/face_gate_service.dart`
- Test: `test/models/face_gate_test.dart`

**Interfaces:**
- Consumes: Task 2 contract; `FaceMatchService`'s platform-guard + detector idioms (`face_detection_tflite` package: `FaceDetector.create()`, `detectFacesFromBytes(bytes, mode: FaceDetectionMode.full)`, `getFaceEmbedding(face, bytes)`, `detector.dispose()`); `ImageCompressor.toBase64Png`.
- Produces (Tasks 4/5 consume exactly):
  ```dart
  class FaceGateResult {
    final bool matched; final double score; final String? reason; final String? enrollmentId;
    const FaceGateResult({required this.matched, required this.score, this.reason, this.enrollmentId});
    factory FaceGateResult.fromJson(Map<String, dynamic> json) // missing score => 0.0; matched defaults false
  }
  class FaceEnrollment {
    final String id; final String fullName; final String dob; final String createdAt; final String? photoUrl;
    const FaceEnrollment({required this.id, required this.fullName, required this.dob, required this.createdAt, this.photoUrl});
    factory FaceEnrollment.fromJson(Map<String, dynamic> json)
  }
  class FaceGateService {
    static String normalizeName(String givenName, String middleName, String lastName);
    Future<List<double>?> embedFromFile(File imageFile);            // null on web/desktop/!=1 face/error
    Future<FaceGateResult?> verify({required String fullName, required List<double> embedding}); // null on any function failure
    Future<bool> enroll({required String givenName, required String middleName, required String lastName, required DateTime dob, required File photo, required List<double> embedding, String? enrolledBy});
    Future<List<FaceEnrollment>> listEnrollments();                  // [] on failure
    Future<bool> deleteEnrollment(String id);
  }
  ```
  `normalizeName` = `[given, middle, last].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ').toLowerCase()`.

- [ ] **Step 1:** Write failing tests in `test/models/face_gate_test.dart` (pure Dart, no Supabase): `FaceGateResult.fromJson` parses `{ok:true, matched:true, score:0.87, enrollmentId:'e1'}` and `{ok:true, matched:false, score:0, reason:'not_enrolled'}`; missing `score` → 0.0; `FaceEnrollment.fromJson` parses id/fullName/dob/createdAt/photoUrl incl. null photoUrl; `normalizeName(' Juan ',' de la ','CRUZ ')` → `'juan de la cruz'`, `normalizeName('Juan','','Cruz')` → `'juan cruz'`.
- [ ] **Step 2:** `flutter test test/models/face_gate_test.dart` — Expected: FAIL (classes don't exist).
- [ ] **Step 3:** Implement `lib/models/face_gate.dart` + `lib/services/face_gate_service.dart`. Service mirrors `FaceMatchService`: platform guard first (web/desktop → null), `FaceDetector.create()`/`dispose()` in try/finally, exactly-one-face requirement, catch → null. `functions.invoke('face-match', body: {...})` exactly like `EmailOtpService` does (read it). `enroll` compresses via `ImageCompressor.toBase64Png(photo)` (null → false) and sends `photoBase64` + `enrolledBy`; converts `FunctionException`/errors to `false`/`[]`/`null` — never throws.
- [ ] **Step 4:** `flutter test test/models/face_gate_test.dart` — Expected: PASS.
- [ ] **Step 5:** `flutter analyze` — Expected: zero errors, no new infos.
- [ ] **Step 6:** Commit: `git add lib/models/face_gate.dart lib/services/face_gate_service.dart test/models/face_gate_test.dart && git commit -m "feat(kyc): face gate model + service (embedding + verify client)"`

### Task 4: Enrollment screen + entry point + l10n

**Files:**
- Create: `lib/screens/admin/face_enrollment_screen.dart`
- Modify: `lib/screens/admin/manage_users_screen.dart` (AppBar actions icon + handler)
- Modify: `lib/l10n/app_en.arb`, `app_fil.arb`, `app_ceb.arb` (owns ALL new keys for the feature, Task 5's included)

**Interfaces:**
- Consumes: Task 3 `FaceGateService.enroll/listEnrollments/deleteEnrollment/embedFromFile`, `FaceEnrollment`.
- Produces: l10n getters used by Task 5 — `faceGateBlockedTitle`, `faceGateBlockedBody`, `faceGateScanFailed`, `faceGateSelfieRequired`, `faceGateConsent`, `faceGateApproved`. New enrollment keys: `faceEnrollTitle`, `faceEnrollDesktopNotice`, `faceEnrollIntro`, `faceEnrollPickPhoto`, `faceEnrollPhotoChosen`, `faceEnrollNoFace`, `faceEnrollEnroll`, `faceEnrollEnrolling`, `faceEnrollSuccess`, `faceEnrollFailed`, `faceEnrollEmpty`, `faceEnrollDeleteTitle`, `faceEnrollDeleteMessage`, `faceEnrollDeleteSuccess`. English copy is in the spec's spirit; reuse existing keys where they already exist (grep `app_en.arb` for `authGivenName`-style name/DOB labels and `authSelectImageSource`/`authCameraOption`/`authGalleryOption` for the picker dialog) — do not duplicate existing keys.

- [ ] **Step 1:** Add the 20 keys to all three arb files (Filipino + Cebuano translations: natural, plain; e.g. "Mag-enroll ng mukha", "Pagparehistro sa nawong"). Run `flutter gen-l10n` — Expected: generated files updated without errors.
- [ ] **Step 2:** Build `FaceEnrollmentScreen`: Scaffold + gradient AppBar like `ManageUsersScreen`; body guarded — on web/desktop show `faceEnrollDesktopNotice` text and stop. Form card: given/middle/last `TextFormField`s (reuse existing label keys), DOB via `showDatePicker` row, photo row (`faceEnrollPickPhoto` button opening the same camera/gallery dialog pattern as `register_screen.dart`'s `_showImageSourceDialog`, chosen file shown as thumbnail + `faceEnrollPhotoChosen`), enroll button (`faceEnrollEnroll`; shows progress + `faceEnrollEnrolling` while running; disabled during). Flow: `embedFromFile` → null ⇒ snackbar `faceEnrollNoFace`; else `enroll(...)` → true ⇒ success snackbar + clear photo + reload list; false ⇒ snackbar `faceEnrollFailed`.
- [ ] **Step 3:** Below the form: enrolled list (`FutureBuilder`/loaded list from `listEnrollments`): `CircleAvatar` (photoUrl, fallback icon), full name, DOB, delete icon → confirm dialog (`faceEnrollDeleteTitle`/`faceEnrollDeleteMessage`) → `deleteEnrollment` → reload + `faceEnrollDeleteSuccess` snackbar. Empty state text `faceEnrollEmpty`.
- [ ] **Step 4:** `manage_users_screen.dart`: import the screen; add `actions: [IconButton(icon: Icon(Icons.face_retouching_natural), tooltip: <faceEnrollTitle>, onPressed: _openFaceEnrollment)]` on the AppBar; handler pushes `MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen())` (same style as `_openCreateUserScreen`; no route constant needed).
- [ ] **Step 5:** `flutter analyze` (zero errors, no new infos) + `flutter test` (all pass).
- [ ] **Step 6:** Commit: `git add lib/screens/admin/face_enrollment_screen.dart lib/screens/admin/manage_users_screen.dart lib/l10n && git commit -m "feat(admin): face sample enrollment screen"`

### Task 5: Signup gate + auto-approval

**Files:**
- Modify: `lib/screens/auth/register_screen.dart` (~lines 32-99 state, 511-629 `_handleRegister`, documents-step selfie UI)
- Modify: `lib/providers/auth_provider.dart` (`signUp` 106-237)
- Modify: `lib/services/user_service.dart` (new method near `approveUser`)

**Interfaces:**
- Consumes: Task 3 `FaceGateService`/`FaceGateResult`; Task 4 l10n getters.
- Produces: `AuthProvider.signUp` gains optional `double? autoApproveFaceScore`; `UserService.autoApproveFaceMatch(String userId, {required double score}) → Future<UserProfile>`.

- [ ] **Step 1:** `user_service.dart`: implement `autoApproveFaceMatch` — update `registration_status='approved'`, `is_approved=true`, `kyc_method='ai_verified'`, `kyc_verified_at=now`, `kyc_enrolled_face_score=score`, `kyc_enrolled_face_at=now`; deliberately NO `kyc_reviewed_by` (comment: system decision, no human); then best-effort approval notification reusing the same `_safeNotify` call shape as `approveUser` (`'registration_approved'`); return the updated `UserProfile`.
- [ ] **Step 2:** `auth_provider.dart`: add `autoApproveFaceScore` param; after successful `signUp`, when non-null, try `_userService.autoApproveFaceMatch(_userProfile!.id, score: ...)` → replace `_userProfile` + `SessionManager.saveProfileSnapshot(updated)`; on failure `debugPrint` and continue with the normal pending flow (never fail signup over this). Skip the `notifyRoles` "New registration to review" fan-out when auto-approved.
- [ ] **Step 3:** `register_screen.dart`: state `FaceGateResult? _faceGateResult; bool _faceGateChecking = false;`. In `_handleRegister`, after the captcha gate and BEFORE the advisory face match: compute `gateSupported` exactly like `LivenessCaptureScreen._gateSupported` (`!kIsWeb && (android||iOS)`). When supported: `_selfiePhoto == null` ⇒ snackbar `faceGateSelfieRequired` + return; `_faceGateChecking=true` (try/finally reset, guarded by `mounted`); `embedFromFile(_selfiePhoto!)` → null ⇒ snackbar `faceGateScanFailed` + return; `verify(fullName: FaceGateService.normalizeName(given, middle, last), embedding: ...)` → null ⇒ snackbar `faceGateScanFailed` + return; `!matched` ⇒ dialog (`faceGateBlockedTitle`/`faceGateBlockedBody`, dismiss-only) + return. Store result in `_faceGateResult`. Guard the submit button against double-tap while `_faceGateChecking`.
- [ ] **Step 4:** Pass `autoApproveFaceScore: (_faceGateResult?.matched ?? false) ? _faceGateResult!.score : null` to `authProvider.signUp`. On success: auto-approved ⇒ snackbar `faceGateApproved` + `pushReplacementNamed(AppRoutes.citizenDashboard)`; otherwise keep the existing pending flow exactly as-is (web/desktop included — zero behavior change there).
- [ ] **Step 5:** Add a one-line consent `Text` (l10n `faceGateConsent`) under the selfie tile in the documents step.
- [ ] **Step 6:** `flutter analyze` (zero errors, no new infos) + `flutter test` (all pass).
- [ ] **Step 7:** Commit: `git add lib/screens/auth/register_screen.dart lib/providers/auth_provider.dart lib/services/user_service.dart && git commit -m "feat(auth): face-matched auto-approval at signup"`

### Task 6: Docs + full verification (orchestrator)

**Files:**
- Modify: `AGENTS.md` (table count 22→23; new face-gate bullet: enroll screen, `face-match` function, `face_enrollments` zero-policy RLS deviation, private bucket, mobile-only gate, deploy note `supabase functions deploy face-match` with no new secrets)
- Modify: `DOCUMENTATION.md` (feature section; §13 note: web signups keep manual review; consent + PH DPA note)

- [ ] **Step 1:** Update both docs.
- [ ] **Step 2:** Full gate: `flutter analyze` → zero errors; `flutter test` → all pass; `npx --yes deno@latest check supabase/functions/face-match/index.ts` → exit 0. Record exact outputs.
- [ ] **Step 3:** Commit: `git commit -m "docs: face-matched auto-approval (enrollment, gate, edge function)"`

## Post-deploy manual checklist (client, not tonight)

1. Apply migration in Supabase SQL editor (live DB) + `supabase functions deploy face-match`.
2. Enroll one official's own face from a phone; sign up with a matching live selfie → instant approval; different person's face → blocked dialog.
3. Verify no-match signup lands in nothing (blocked pre-submit), and a web signup still creates a pending row.
