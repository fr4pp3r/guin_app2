# Design: Face-Matched Auto-Approval at Signup

Date: 2026-11-23
Status: Approved by client representative ("write doc and start implementation", 2026-11-23)
Owner: orchestrator session

## Intent & why

New residents can only sign up if their face is already on file with the barangay.
Officials pre-enroll residents' face samples; at signup the app compares the
liveness selfie against the sample enrolled under the name the user typed.
Match → account is approved instantly. No match (or not enrolled) → signup is
blocked. Manual officer review disappears from the normal signup path.

## Goals

- Officials enroll a resident (full name + DOB + one photo) in-app.
- Signup (mobile) runs the existing liveness selfie through the existing
  on-device embedding model and verifies it server-side against the enrolled
  sample for the typed name.
- Score ≥ 0.5 → auto-approve (`kyc_method='ai_verified'`, score logged to
  `kyc_face_match_score`, `kyc_reviewed_by` NULL — same "never impersonate
  humans" convention as `document_automation_service`).
- No enrolled record, or score < 0.5 (0.3–0.5 counts as no-match, per client
  rule) → signup blocked with "not on record, visit the barangay office".
- Human-approval screens and `UserService.approveUser` remain untouched for
  admin-created users and the web fallback.

## Non-goals / anti-goals

- No 1:N identification ("who is this face?") — matching is name-keyed 1:1.
- No new anti-spoofing beyond the existing liveness gate; a printed photo held
  up to the camera remains a known risk (documented, not fixed here).
- No RLS hardening of `users_profile`. The app's permission model is
  client-side by design (AGENTS.md); a tampered client could already
  self-approve rows before this feature. This feature neither fixes nor
  worsens that; server-enforced approval is a separate project.
- No bulk bucket import, no re-enrollment workflow, no admin dashboard changes.

## Constraints

- Free-tier Supabase + no Supabase Auth (salted-hash login in Dart).
- `face_detection_tflite` / `flutter_litert` are native-only: face embedding
  works on Android/iOS only. Web signups cannot face-match → they keep the
  old pending → manual-review path with a "use the mobile app" notice.
- House RLS pattern is `USING (true)` and all current buckets are public.
  **Face data must NOT follow it** (see Security).
- PH Data Privacy Act: face templates + face photos are sensitive personal
  information. One line of consent text is shown at the face-capture step.

## Approaches considered

1. **Reuse the existing on-device face model (CHOSEN)** — signup selfie and
   enrollment photo both embed via the already-shipped `FaceDetector`
   (`lib/services/face_match_service.dart`); a new small edge function
   compares embeddings server-side. No new dependencies, no AI quota burn,
   same model on both sides of the comparison.
2. Gemini "same person?" via the `ai` edge function — works on web, but LLM
   face judgment is unreliable and per-request cost/RPM make it a poor gate.
3. AWS Rekognition — forensic-grade, but a second cloud provider, recurring
   cost, and residents' biometrics leave the stack.

## Design

### Schema (`supabase/migrations/20261123_face_enrollments.sql`, mirrored into `setup.sql`)

```sql
create table public.face_enrollments (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  full_name_normalized text not null,   -- lower(trim(join(given, middle, last)))
  dob date not null,
  embedding float8[] not null,
  photo_path text not null,             -- object path in the face-samples bucket
  enrolled_by uuid references public.users_profile(id),  -- audit only, client-supplied
  created_at timestamptz not null default now()
);
create index face_enrollments_name_idx on public.face_enrollments (full_name_normalized);
alter table public.face_enrollments enable row level security;
-- DELIBERATE DEVIATION from the house USING(true) pattern:
-- RLS enabled, zero policies => denied to anon/authenticated; the edge
-- function reads/writes via the service-role key.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('face-samples', 'face-samples', false, 5242880, array['image/jpeg','image/png'])
on conflict (id) do nothing;
-- No storage.objects policy: bucket stays private, service-role only.
```

Name lookup matches on `full_name_normalized` alone; among rows with the same
name the **best score wins** (fathers/sons sharing a name are separated by the
face, not by text; DOB is recorded for audit/display, not as a lookup key — a
DOB typo at enrollment must not lock a resident out).

### Edge function `supabase/functions/face-match/`

Standalone function (house pattern of `email-otp`/`captcha`, not an `ai` task —
no Gemini involved). `config.json` pins `verify_jwt: false` like the `ai`
function, since the app has no Supabase Auth. Uses `SUPABASE_SERVICE_ROLE_KEY`.

Contract (JSON in / JSON out):

- `enroll` `{ fullName, dob, embedding: number[], photoBase64, photoMime, enrolledBy? }`
  → validates embedding (finite numbers, 32..2048 length), uploads the photo to
  `face-samples/<uuid>.<ext>`, inserts the row → `{ ok: true, enrollmentId }`
- `verify` `{ fullName, embedding: number[] }`
  → rows for `full_name_normalized`, max cosine similarity
  → `{ ok: true, matched: boolean, score: number, enrollmentId? }`
  (`matched = score >= 0.5`; `reason: "not_enrolled"` when no rows)
- `list` `{}` → `{ ok: true, enrollments: [{ id, fullName, dob, createdAt, photoUrl }] }`
  (signed URL, 1 hour) — officials verify they enrolled the right person
- `delete` `{ id }` → deletes row + bucket object → `{ ok: true }`

Decision logic (threshold) lives server-side so the threshold is not a client
constant. Known gap: the endpoint is anon-reachable like `verify-document`;
probing it requires producing model-compatible embeddings, and the whole app
runs on a client-trust posture anyway.

### Flutter

- `lib/services/face_gate_service.dart` (new):
  - `Future<List<double>?> embedFromFile(File)` — detect + embed a still photo
    using the same `FaceDetector` usage as `FaceMatchService` (mirrors its
    web/desktop null-return).
  - `Future<FaceGateResult> verify({fullName, embedding})` — calls the
    function directly (house pattern: `EmailOtpService`/`CaptchaService` call
    `functions.invoke` directly, not via `AiService`).
  - `static String normalizeName(given, middle, last)` — shared by signup,
    enrollment, and tests.
- `lib/models/face_gate.dart` (new): `FaceGateResult { matched, score, reason }`
  with `fromJson`; offline unit tests in `test/models/face_gate_test.dart`.
- `lib/screens/admin/face_enrollment_screen.dart` (new): officials-only
  (`AppRoles.canManageUsers`), reached from `ManageUsersScreen`. Fields mirror
  signup's name + DOB widgets; photo via camera/gallery (`image_picker`);
  enroll → success list below (name, DOB, date, thumbnail, delete with
  confirm). On web/desktop: notice that enrollment requires the mobile app.
- `lib/screens/auth/register_screen.dart` (gated edits):
  - After a qualifying liveness capture (mobile), compute the embedding and
    call `verify` with the already-entered name; allow recapture + re-verify.
  - Submit gate: mobile + gate supported ⇒ require `matched`, else block with
    "not on record" copy (retry + visit-office guidance).
  - After `AuthService.signUp` succeeds with a matched gate: update the new
    row — `registration_status='approved'`, `is_approved=true`,
    `kyc_method='ai_verified'`, `kyc_verified_at=now()`, `kyc_reviewed_by`
    NULL — then route to the sign-in screen with an "account approved" message
    instead of `PendingApprovalScreen`.
  - One consent line at the face-capture step ("your face scan is compared
    against barangay records…").
  - Web: unchanged flow + static "instant approval is available on the mobile
    app" notice.
- Embedding on still images needs no new package — the enrollment and signup
  paths both go through the helper in `face_gate_service.dart`.

### Graceful degradation (explicit deviation)

The house rule "AI features never block the core workflow" does **not** apply
here: the face check IS the gate, by client decision. If the `face-match`
function is unreachable, mobile signup is blocked with a retryable error —
never silently approved.

## Validation

- `npx --yes deno@latest check supabase/functions/face-match/index.ts` → exit 0
- `flutter analyze` → zero errors (pre-existing info lints tolerated)
- `flutter test` → all pass, including new `face_gate` tests
- Manual (post-deploy, not overnight): enroll a sample, sign up with a matching
  selfie → approved; unrelated face → blocked. Requires deployed function +
  applied migration; listed as follow-up for the client.

## Left to the builder (settled by builder unless flagged)

Exact widget layout/copy, error message wording, signed-URL expiry, migration
file naming. All house conventions; no open product questions.
