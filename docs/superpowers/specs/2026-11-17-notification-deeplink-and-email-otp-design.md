# Notification deep-linking + email OTP verification — design

Date: 2026-11-17
Status: awaiting approval

Two independent changes, agreed order: **notification deep-linking first**, then
**email OTP**. Separate migrations, separate edge function, no shared code.

---

## Part 1 — Notification tap opens the exact item

### Intent / why

A notification tap currently only marks the row read (`notifications_screen.dart:380`).
Users must hunt through queues to find what the notification was about. A tap should
land on the specific request / report / announcement / pending user.

### Goals / non-goals

- Goal: tap → mark read → resolve the referenced entity → open its detail screen,
  with role-appropriate actions preserved.
- Non-goal: FCM push-tap navigation (`push_service.dart:303` deliberately does not
  navigate). Push payload can carry the new reference fields at no extra cost, but
  wiring the OS-level tap is out of scope.
- Non-goal: changing `notification_type` enum values or fixing mislabelled emitters
  (e.g. `payment_verified` used as a treasurer queue notice at `document_provider.dart:624`).
  Role + reference type disambiguate at resolve time.

### Approaches (decided)

| Option | Trade-off | Verdict |
|---|---|---|
| Type-only routing | One file, no migration; lands on the list, user still searches | rejected: user wants exact item |
| `reference_type` + `reference_id` on each row | Additive migration, ~20 emitter edits, queue screens gain a focus arg | **chosen** |
| JSON payload snapshot on the row | No lookup needed, but goes stale and duplicates entity data | rejected: wrong source of truth |

### Design

1. **Schema** — migration `supabase/migrations/20261117_notification_references.sql`
   (additive, mirrors `20261007_*` style):
   - `notifications.reference_type TEXT NULL`
   - `notifications.reference_id TEXT NULL`
   - no FK (polymorphic), no enum (new kinds must not need a migration).
   - Update `setup.sql` `notifications` DDL (~401) so fresh projects match.
   - Existing rows have NULL → resolver falls back to type-based list routing.

2. **Model / service** — `lib/models/notification.dart`: add nullable `referenceType`,
   `referenceId` to constructor, `fromJson`, `toJson`, `copyWith`.
   `NotificationService.createNotification` (`:140`) gains optional `referenceType`,
   `referenceId`, writes them into the insert. `notifyRoles` / `notifyAllApproved` /
   the batched insert (`:212`, `:254`, `:287`) gain the same optional pass-through.

3. **Emitters** — every `createNotification` / `notifyRoles` call that has an entity in
   hand passes its type and id:
   - document requests → `reference_type: 'document_request'`, id from the request
     (`document_automation_service.dart` ~10 sites, `document_provider.dart` ~8 sites).
   - `incident_submitted` → `'incident_report'` + report id.
   - "New announcement" → `'announcement'` + announcement id.
   - "New registration to review" and registration decisions → `'user_registration'`
     + user id.
   - Queue notices with no single entity → leave NULL.
   Use string constants in one place (`NotificationRefs` or similar) to avoid typo drift.

4. **Resolver** — a pure helper, e.g. `lib/utils/notification_destination.dart`:
   `NotificationDestination resolve(AppNotification n, String role)` returning a
   destination kind + reference id. No `BuildContext`, no I/O → unit-testable offline.
   Mapping (role from `AuthProvider`):
   - `document_request`, citizen → viewer (`DocumentViewerScreen(request)` via a new
     named route) for all request states. E-receipt stays reachable from the viewer.
   - `document_request`, official → the owning queue screen with a `focusRequestId`
     argument, so the screen fetches the request and calls its *existing* open-detail
     handler (keeps `_actionsFor` and the approval/reject handlers intact — do not
     duplicate them in the resolver):
     - "New document request" → `pendingRequests`
     - "Payment receipt submitted" / "Payment to verify" → `pendingPayments`
     - "Request awaiting approval" / "Request ready for approval" → `captainApproval`
   - `incident_report`, tanod/captain/admin → `incidentReports` with `focusReportId`.
   - `announcement` → announcements feed with `focusAnnouncementId`.
   - `user_registration`, official → `pendingUsers` with `focusUserId`.
   - `user_registration`, citizen (approved/rejected, signed out) → no navigation,
     mark read only.
   - NULL reference (legacy rows) → today's type-based list fallback.

5. **Navigation** — on tap (`notifications_screen.dart:380`): mark read, then call a
   single `_navigateTo(NotificationDestination)` that fetches the entity via existing
   services (`DocumentService.getRequestById:546`, `UserService.getUserProfile:36`)
   and pushes the screen. Add a `DocumentService.getIncidentById` equivalent only if
   no list-fetch path can supply the report; prefer passing `focusReportId` to the
   queue screen, which already loads the list.
   Add optional typed arguments to the queue screens and to `AppRoutes.onGenerateRoute`
   (same pattern as `citizenIncidentDetail:143`): `focusRequestId`, `focusReportId`,
   `focusUserId`, `focusAnnouncementId`. Each queue screen, after its load completes,
   finds the focused row and calls its existing detail opener once.
   Missing entity (fetch returns null, or the focused row is not in the loaded list):
   fall back to that type's list screen and show a short snackbar ("No longer
   available"). Never dead-end silently. Add named routes for `AnnouncementsScreen`
   and `DocumentViewerScreen` (currently pushed with `MaterialPageRoute` only).

6. **Tests** — offline unit tests for `resolve()`: each reference type × citizen/official
   role, and NULL reference fallback. Service/screen tests stay out (no fixtures today).

### Order / risk

Migration must be applied to the live DB or every tap falls back to the list (silent
degradation, same failure mode as other missing migrations). All emitter edits are
mechanical; the risk is a missed call site → that notification has no reference id.

---

## Part 2 — Email OTP verification via Supabase Edge Function + Gmail SMTP

### Intent / why

Registration collects a unique email (`register_screen.dart:841`) but never proves
control of it. Resend is out (usage limits / cost). Use a dedicated CiteEase Gmail
account as the SMTP relay, with credentials in Supabase secrets only.

### Goals / non-goals

- Goal: during registration, send a 6-digit code to the entered Gmail address, verify
  it server-side, and record `email_verified` on the resulting profile so the flag
  cannot be set by a client using the public anon key.
- Non-goal: adopting Supabase Auth. No `auth.users`, no Supabase sessions — those would
  conflict with the hand-rolled SHA-256 auth and `USING (true)` RLS (`setup.sql:772`).
- Non-goal: fixing `AuthService.resetPassword` (`:307`), which lets anyone set a
  password for any known email with no token. Flagged as a separate security gap.
- Non-goal: enabling an email-change flow or OTP login.

### Approaches (decided)

| Option | Trade-off | Verdict |
|---|---|---|
| `flutter_smtp` in the app | App password ships in bundle; no web support; anon RLS makes OTP forgeable anyway | rejected |
| Supabase Auth email OTP + custom SMTP | Second user store, Supabase sessions, conflicts with custom auth & RLS | rejected |
| Supabase built-in default SMTP | 2 msgs/hour, only pre-authorized team addresses | rejected |
| Edge Function → Gmail SMTP (465, implicit TLS) + protected OTP table | New function + migration + client step; credentials server-side; web works | **chosen** |

Supabase Edge Functions block outbound ports 25 and 587; 465 with implicit TLS is the
port to use. Credentials live in Supabase secrets (`GMAIL_EMAIL`,
`GMAIL_APP_PASSWORD`, `OTP_PEPPER`, `SUPABASE_SERVICE_ROLE_KEY`), never in `.env` or
client code. Supabase does **not** auto-inject the service-role key into Edge Functions
(only URL + anon key) — the function creates its own Supabase client with
`SUPABASE_SERVICE_ROLE_KEY` to read/write the protected OTP tables.

### Design

1. **Manual prerequisite (user action)** — create the dedicated Gmail account, enable
   2FA, generate a 16-character app password. The orchestrator cannot do this. Store
   via `supabase secrets set GMAIL_EMAIL=... GMAIL_APP_PASSWORD=... OTP_PEPPER=... SUPABASE_SERVICE_ROLE_KEY=...`.
   Free Gmail SMTP allowance (~500 msgs/day) is adequate for registration volume;
   document the cap and add a per-email send limit below.

2. **Edge function** `supabase/functions/email-otp/` — `index.ts` + `config.json`
   (`verify_jwt: false`, same as `ai`, because registration is unauthenticated and this
   app has no Supabase Auth). Follow `captcha/index.ts` conventions: `serve` from deno
   std, static imports of `corsHeaders`/`errorResponse`/`jsonResponse` from
   `../ai/_shared.ts`, static `npm:nodemailer` import (port 465, `secure: true`).
   One function, two actions selected by `body.action`:
   - `send` `{email}` → validate address + rate limit → generate 6 digits via
     `crypto.getRandomValues` → store `sha256(OTP_PEPPER + code)` → send plain + HTML
     body. Response never echoes the code. Generic success message to avoid account
     enumeration.
   - `verify` `{email, code}` → load row, check `expires_at` (5 min) and `attempts`
     (max 5), compare hash → on success write the email into a protected
     `verified_emails` table and delete the OTP row; on failure increment attempts.
   - `deno check` must exit 0; smoke-test with curl before wiring the client.

3. **Schema** — migration `supabase/migrations/20261117_email_otp.sql`:
   - `email_otps` (`email TEXT PK`, `code_hash TEXT`, `expires_at TIMESTAMPTZ`,
     `attempts INT DEFAULT 0`, `last_sent_at TIMESTAMPTZ`, `created_at TIMESTAMPTZ`).
     RLS enabled, **no policies for anon/authenticated** → only service role (the edge
     function) can read or write. This is the security boundary: the code hash and the
     verified record are not reachable with the public anon key.
   - `verified_emails` (`email TEXT PK`, `verified_at TIMESTAMPTZ`). Same RLS posture:
     service role only.
   - `users_profile.email_verified BOOLEAN NOT NULL DEFAULT false` (additive).
      Ordering is fixed by the client flow: OTP `send`/`verify` completes during step 0
      of the wizard, so the `verified_emails` row exists **before** `_handleRegister`
      inserts the profile. The insert trigger therefore derives `email_verified = true`
      on insert. Nothing inserts a `users_profile` row earlier in registration.
   - `BEFORE INSERT OR UPDATE` trigger function `SECURITY DEFINER`, `SET search_path = public`,
     sets `NEW.email_verified = EXISTS(SELECT 1 FROM verified_emails WHERE email = NEW.email)`.
     The DB derives the flag from the protected table, so an anon client cannot forge it
     by writing `email_verified` in its own insert/update. `signUp` simply stops sending
     the column (default false).
   - Mirror all of the above in `setup.sql` (users_profile DDL ~174, after table
     definitions) so a fresh project matches the live migration.

4. **Client** — `lib/services/email_otp_service.dart` wraps
   `supabase.functions.invoke('email-otp', body: ...)` with typed `sendCode` /
   `verifyCode`, returning a small result object; errors surfaced (this is a gate, not
   a graceful-degradation AI feature). Registration UI: add an OTP step to the
   4-step wizard in `register_screen.dart` (step 0 account, then code entry before
   personal details), with send/resend, 6-digit input, verify, countdown, and clear
   inline errors. `_nextStep` from the account step and `_handleRegister` both require
   a successful verify. UI is user-facing → implement with design polish, not a bare
   `TextField` dropped into the form.
   `AuthService.signUp` insert (`:85`) drops any `email_verified` key; do not trust a
   client-supplied flag.

5. **Tests / verification** — `npx --yes deno@latest check supabase/functions/email-otp/index.ts`
   exits 0. Smoke-test `send`/`verify` with curl against a real Gmail relay before
   client wiring. Flutter: `flutter analyze` (zero errors, tolerate existing infos) →
   `flutter test`. Registration + edge function cannot be exercised in offline tests;
   verify manually with a real Gmail address.

### Order / risk

Migration → secrets → function → client. If the function is not deployed or secrets
are missing, registration stalls at the OTP step — acceptable for a verification gate,
but the error state must be explicit rather than silent. Rotate the app password by
updating one secret, no app rebuild. Gmail's ~500/day SMTP cap and Supabase's 30/hour
custom-SMTP-style rate limits are the scale ceiling; per-email cooldown (60s) and max
3 sends/hour keep this bounded.

---

## Cross-cutting

- No new Flutter dependencies. `npm:nodemailer` is edge-function-side only.
- No Supabase Auth anywhere; RLS stays `USING (true)` except the two new OTP tables,
  which have no client policies.
- Both features degrade gracefully if their DB migration is missing (list fallback for
  notifications; registration blocked with a clear error for OTP).
- Callers, tests, config, exports touched: setup.sql + 2 migrations, AppNotification +
  NotificationService + ~20 emitters + NotificationsScreen + routes + queue screens,
  new edge function + EmailOtpService + register_screen, offline resolver tests.
