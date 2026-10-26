# AGENTS.md

Barangay E-Document System: a single-package Flutter app (Dart `^3.10.1`) backed by
Supabase. State is `provider` ChangeNotifiers. No monorepo, no task runner — plain
Flutter CLI.

## Commands

```bash
flutter pub get        # after any pubspec change
flutter analyze        # lint (flutter_lints) — the pre-commit gate
flutter test           # 116 offline tests (test/automation, models, providers, services, utils, widgets)
flutter test test/automation/kyc_models_test.dart   # run one test file
flutter run -d chrome  # web; `flutter run` for an attached device
```

Verify order: `flutter analyze` → `flutter test`.

- There is **no CI** (`.github/` contains no workflows). Local analyze/test is the only gate.
- `flutter analyze` baseline is not clean: ~56 pre-existing `info` lints (`avoid_print`,
  `use_build_context_synchronously`, `deprecated_member_use`) are tolerated — don't churn
  to fix them, never add new ones. It must produce zero **errors**. Zero errors currently.

## AI features (Supabase Edge Functions + Gemini free tier)

The AI edge function lives at `supabase/functions/ai/`: `index.ts` (router + JWT auth),
`_shared.ts` (callGemini helper), `handlers/{document_processor,incident_classifier}.ts`
(feature handlers). To add a new AI feature: create a handler module under `handlers/`
exporting an async `TaskHandler` as its **default export**, add a **static import** in
`index.ts` and register it in the `routes` map there — do NOT use runtime
`import()`/dynamic registry: the deploy bundler only ships statically-resolvable
imports, and handlers loaded dynamically silently 501 in production. Then add a Flutter
service calling `AiService.invoke(task, payload)`
(`lib/services/ai_service.dart`, returns `null` on any failure), and land the feature UI
with the same graceful-degradation rule.

- **Deploy** (see `supabase/functions/ai/README.md`): `supabase functions deploy ai`,
  `supabase secrets set GEMINI_API_KEY=... AI_MODEL=gemini-2.5-flash`. The AI key lives
  ONLY in Supabase secrets — never in `.env` or client code. Deploy with the plain
  command: `config.json` pins `verify_jwt: false`, which is what keeps the function
  bootable and reachable (this app has no Supabase Auth). Do NOT add `--no-verify-jwt`.
  A function that fails to boot answers **every** task with `503 BOOT_ERROR` — including
  `ping` — and the chatbot just shows its offline FAQ fallback, so always smoke-test
  `ping` first. `npx --yes deno@latest check supabase/functions/ai/index.ts` must exit 0.
- **Free tier reality**: Flash models only (~5–15 RPM, few hundred RPD), so AI features
  must never block the core workflow; callers treat null as "AI unavailable".
- Feature status: incident classifier + document processor wired into citizen screens
  (`submit_report_screen.dart` "AI suggest category", `request_document_screen.dart`
  "AI check details"). Chatbot (Barangay Assistant, `chatbot` task + `lib/screens/citizen/chatbot_screen.dart`),
  incident reviewer and receipt parser are also wired. Resident profiling: not built.

## Read first

- `DOCUMENTATION.md` — architecture, roles, workflow statuses, setup, security posture,
  and §13 Known Gaps. README points here.
- `PUSH_NOTIFICATIONS.md` — FCM push notifications (Android-only): wiring, the
  Firebase + Supabase setup steps, and troubleshooting. Push stays inactive until
  a deployment drops in `android/app/google-services.json` and sets the
  `FIREBASE_SERVICE_ACCOUNT` secret; without them the app behaves exactly as before.
- Trust executable sources over prose: README/DOCUMENTATION previously claimed "no tests" and
  "`.env` tracked in git" — both were stale and are now corrected (tests exist across `test/`;
  `.env` is gitignored).

## Architecture facts easy to get wrong

- Entry: `lib/main.dart` → `SupabaseConfig.initialize()` (loads `.env`, throws if either
  key missing) → 9 providers → routes in `lib/config/routes.dart`.
- **Supabase Auth is not used.** Login queries `users_profile` in Dart and compares a
  salted SHA-256 hash (`lib/utils/password_hash.dart`); sessions live in
  `shared_preferences`. RLS is enabled but every policy is `USING (true)` because
  `auth.uid()` is always NULL — adding `auth.uid()`-based policies or Supabase Auth calls
  will silently lock the app out.
- All permission checks are client-side; `lib/utils/role_access.dart` is the source of
  truth for role → capability.
- `.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) is also declared as a Flutter **asset** in
  `pubspec.yaml` — required by flutter_dotenv in release builds. Don't remove it from
  `assets:`.
- Database: `setup.sql` is the single source of schema and is **destructive**
  (`DROP ... CASCADE`) — run only against a fresh Supabase project via the SQL Editor.
  Never run `sql-legacy/` (archived, historically wrong). It now defines 22 tables
  (`device_push_tokens` is the newest).
- `request_status` / `payment_status` are `TEXT` + CHECK (16 statuses), **not** Postgres
  enums. `DOCUMENTATION.md` §13.5 says legacy 4-status code lingers in
  `document_service.dart`; new code must use the full status set from
  `lib/models/document_request.dart`. Note `submitPaymentReceipt` was deliberately stripped
  of its legacy `pending_payment` status write — automation owns that transition now
  (`markPaymentSubmitted`).
- Document automation (`lib/services/document_automation_service.dart`) is **wired into
  `DocumentProvider`**: `createRequest` → `afterSubmission` (auto draft + route), receipt
  upload → `afterPaymentReceipt`, treasurer confirm/reject → `afterPaymentConfirmed/Rejected`.
  It never blocks the caller (errors swallowed + debugPrinted) and never impersonates
  humans (`secretaryId: null`, audit actor `'system'`). Captain approve/reject is **not**
  wired — screens already do the full PDF+release flow; don't add a second call.
  `findOverdueInvoices`/`notifyOverdueInvoices` still need an external scheduler (pg_cron)
  — none exists in-app.
- Realtime self-updates require tables in the `supabase_realtime` publication
  (`setup.sql` handles it); a missing table fails silently (dashboards just stop updating).
  Live tables are `document_requests`, `users_profile`, `notifications`, `announcements`.
  `emergency_hotlines` is also in the publication list in `setup.sql`.
  `device_push_tokens` is intentionally NOT in it — nothing subscribes live.
- Notifications (`lib/services/notification_service.dart`): `createNotification` targets one
  user, `notifyRoles` fans out to every APPROVED official holding one of the roles, and
  `notifyAllApproved` fans out to all approved users (announcements). `notifications.type` is
  a Postgres ENUM — only `registration_approved|registration_rejected|request_approved|
  request_rejected|request_released|payment_verified|payment_rejected|incident_submitted|
  incident_updated|system` exist; new codes need a migration. All fan-outs are best-effort
  (errors swallowed) and never block the action that triggered them.
- Push (FCM, Android-only) piggybacks on the row above: `createNotification`'s `finally`
  fires a fire-and-forget `functions.invoke('push')`, and `supabase/functions/push/` looks up
  `device_push_tokens` and calls FCM HTTP v1 with a service-account key held in Supabase
  secrets. `lib/services/push_service.dart` owns the device half (init in `main.dart`,
  register on login/restore, delete on sign-out). It is inert without
  `android/app/google-services.json` + the `FIREBASE_SERVICE_ACCOUNT` secret — never let it
  become required for the in-app bell to work. Table: `device_push_tokens`
  (`supabase/migrations/20261025_device_push_tokens.sql`). Full guide: `PUSH_NOTIFICATIONS.md`.
- Approver review is **page-based**, not list-card based: `user_registration_detail_screen.dart`
  opens for pending registration reviews (captain/admin only; `canManageUsers`) and
  `document_request_detail_screen.dart` opens for secretary/captain/kagawad queues with a
  per-queue `actions` descriptor. Both show the requestor's full profile, run existing
  handlers unchanged (captain page still signs+releases PDFs), and return to the queue only
  when the status actually changed. No permission model changes.
- Announcements: global bulletin board (`announcements` table) — every signed-in user reads
  the same rows, no audience or read state. `AnnouncementProvider`/`AnnouncementService`,
  feed screens under `lib/screens/announcements/`, entry points on both dashboards. Posting
  and deleting are gated by `AppRoles.canPostAnnouncements` (captain / secretary / admin);
  posting also fans out a bell notification to all approved users. Posts may carry one
  optional image (`announcements.image_url` → public URL in the `announcement-images`
  bucket, uploaded from `create_announcement_screen.dart`). Live DBs need
  `supabase/migrations/20261020_announcements.sql` applied or the feed stays empty, plus
  `supabase/migrations/20261021_announcements_images.sql` for image posting (without it the
  upload fails as "Record not found" — a missing storage bucket surfaces as a 404).
- Incident map pin: optional `latitude` / `longitude` on `incident_reports` (NULL = no pin);
  live DBs need `supabase/migrations/20261022_incident_report_geo.sql`. Rendering uses
  `flutter_map` + OSM tiles (no API key). The pin is optional, so reporting is never blocked
  when GPS is unavailable.
- Document security: policy (`expires_at`, `single_use`, `max_uses`, `use_count`) lives on
  the released row in `document_verifications` (parent). Each printable copy is a row in
  `document_print_copies` with its OWN random token + serial (cap 5, `PrintCopyRules`), but
  every scan/use evaluates policy against the **parent** — printing copies can never multiply
  the use budget. In-app viewing is view-only (watermark + `no_screenshot`); the ONE export
  path is the viewer's "Request printable copy" → `VerificationService.issuePrintCopy` →
  `DocumentAutomationService.generatePrintableCopyPdf` (`printing` package, native-only —
  PDF gen uses `dart:io`, so web/desktop degrade gracefully). Live-DB migration:
  `supabase/migrations/20261007_document_print_copies.sql` (additive); `setup.sql` is 21 tables now.
  Live DBs from before the security work also need
  `supabase/migrations/20261007_document_policy_columns.sql` (additive;
  `expires_at`/`single_use`/`max_uses`/`use_count`/`used_at` on both
  `document_requests` and `document_verifications`) — release/consume will throw
  "column does not exist" until it's applied via the SQL Editor.
- Dead code is parked, not broken: `DOCUMENTATION.md` §13.3 lists unreferenced screens and
  services (e.g. `admin_dashboard_screen.dart`, `upload_payment_screen.dart`,
  `document_service_backup.dart`). Don't wire them up or "repair" them.

## Testing

- Tests are offline and dependency-free (62 total, no fixtures/services/snapshots). They cover
  the KYC / ID-verifier models (`test/automation/`), the offline document and incident caches,
  session-snapshot persistence, `Helpers.parseSupabaseError`, `ConnectivityProvider.isOfflineFrom`,
  and the connectivity banner widget. Screens and Supabase-bound services are untested, and the
  document workflow rules in `lib/automation/` have **no** tests: verify manually against the
  workflows in `DOCUMENTATION.md` §5.
