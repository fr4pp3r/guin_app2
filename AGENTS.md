# AGENTS.md

Barangay E-Document System: a single-package Flutter app (Dart `^3.10.1`) backed by
Supabase. State is `provider` ChangeNotifiers. No monorepo, no task runner — plain
Flutter CLI.

## Commands

```bash
flutter pub get        # after any pubspec change
flutter analyze        # lint (flutter_lints) — the pre-commit gate
flutter test           # unit tests (test/automation/)
flutter test test/automation/fee_assessor_test.dart   # run one test file
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
  ONLY in Supabase secrets — never in `.env` or client code.
- **Free tier reality**: Flash models only (~5–15 RPM, few hundred RPD), so AI features
  must never block the core workflow; callers treat null as "AI unavailable".
- Feature status: incident classifier + document processor wired into citizen screens
  (`submit_report_screen.dart` "AI suggest category", `request_document_screen.dart`
  "AI check details"). Chatbot, identity verification, resident profiling: not built.

## Read first

- `DOCUMENTATION.md` — architecture, roles, workflow statuses, setup, security posture,
  and §13 Known Gaps. README points here.
- Trust executable sources over prose: README/DOCUMENTATION still claim "no tests" and
  "`.env` tracked in git" — both stale (tests exist in `test/automation/`; `.env` is
  gitignored).

## Architecture facts easy to get wrong

- Entry: `lib/main.dart` → `SupabaseConfig.initialize()` (loads `.env`, throws if either
  key missing) → 6 providers → routes in `lib/config/routes.dart`.
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
  Never run `sql-legacy/` (archived, historically wrong).
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
- Document security: policy (`expires_at`, `single_use`, `max_uses`, `use_count`) lives on
  the released row in `document_verifications` (parent). Each printable copy is a row in
  `document_print_copies` with its OWN random token + serial (cap 5, `PrintCopyRules`), but
  every scan/use evaluates policy against the **parent** — printing copies can never multiply
  the use budget. In-app viewing is view-only (watermark + `no_screenshot`); the ONE export
  path is the viewer's "Request printable copy" → `VerificationService.issuePrintCopy` →
  `DocumentAutomationService.generatePrintableCopyPdf` (`printing` package, native-only —
  PDF gen uses `dart:io`, so web/desktop degrade gracefully). Live-DB migration:
  `supabase/migrations/20261007_document_print_copies.sql` (additive); `setup.sql` is 18 tables now.
  Live DBs from before the security work also need
  `supabase/migrations/20261007_document_policy_columns.sql` (additive;
  `expires_at`/`single_use`/`max_uses`/`use_count`/`used_at` on both
  `document_requests` and `document_verifications`) — release/consume will throw
  "column does not exist" until it's applied via the SQL Editor.
- Dead code is parked, not broken: `DOCUMENTATION.md` §13.3 lists unreferenced screens and
  services (e.g. `admin_dashboard_screen.dart`, `upload_payment_screen.dart`,
  `document_service_backup.dart`). Don't wire them up or "repair" them.

## Testing

- Tests cover the pure-Dart automation layer (`lib/automation/` ↔ `test/automation/`,
  ~100 tests incl. document-access rules, print-copy rules, verification-QR parsing, and
  AiService.unwrapResponse). Screens, providers,
  and Supabase-bound services are untested: verify manually against the workflows in
  `DOCUMENTATION.md` §5.
- Tests are offline and dependency-free: no fixtures, services, or snapshots.
