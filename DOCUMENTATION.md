# Barangay Guion E-Document System — Documentation

> **Single source of truth for this project.** This document replaces the 17 previously
> scattered Markdown files, now archived under [`docs/archive/`](docs/archive/) with a
> notice explaining why they should not be trusted. Every claim below was verified against
> the actual source code, SQL scripts, and configuration in this repo (verified 2026-09-26).
> If code and docs disagree, the code wins — and this document should be corrected.
> Last updated: 2026-10-13 (comprehensive feature audit).

---

## Table of Contents

1. [What This Project Is](#1-what-this-project-is)
2. [Tech Stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [Roles and Permissions](#4-roles-and-permissions)
5. [Document Request Workflow](#5-document-request-workflow)
6. [Incident Reports](#6-incident-reports)
7. [Document Verification](#7-document-verification)
8. [Setup — Step by Step](#8-setup--step-by-step)
9. [Database Schema](#9-database-schema)
10. [Storage Buckets](#10-storage-buckets)
11. [Creating the First Admin](#11-creating-the-first-admin)
12. [Authentication Model and Security Warnings](#12-authentication-model-and-security-warnings)
13. [Known Gaps and Discrepancies](#13-known-gaps-and-discrepancies)
14. [Command Reference](#14-command-reference)
15. [File Map](#15-file-map)
16. [Project History](#16-project-history)

---

## 1. What This Project Is

A **Flutter** application for a Philippine barangay (local government unit) that lets
residents request and obtain official documents online, and lets barangay officials
process those requests through a role-gated approval pipeline.

The app supports two independent business domains:

- **Document requests** — Barangay Clearance, Certificate of Indigency, Barangay ID,
  and Community Tax Certificate (Cedula), with fee assessment, GCash payment, PDF
  generation, and public verification.
- **Incident reports** — residents file incident reports; officials triage and resolve them.

Supported document types (from `lib/models/document_request.dart` and the PDF service):

| `document_type`     | Display name                    |
| ------------------- | ------------------------------- |
| `barangay_clearance`| Barangay Clearance              |
| `business_clearance`| Barangay Business Clearance     |
| `certification`     | Barangay Certification          |
| `oath_undertaking`  | Oath of Undertaking             |
| `indigency`         | Certificate of Indigency        |
| `good_moral`        | Certificate of Good Moral Character |
| `residency`         | Certificate of Residency         |
| `cedula`            | Community Tax Certificate (Cedula)|
| `barangay_id`       | Barangay ID                     |

---

## 2. Tech Stack

| Layer       | Choice                                                        |
| ----------- | ------------------------------------------------------------- |
| Framework   | Flutter / Dart — `sdk: ^3.10.1` in `pubspec.yaml`              |
| Backend     | Supabase (PostgreSQL, Storage)                                 |
| State mgmt  | `provider` (`ChangeNotifier`) — 8 providers registered in `main.dart` |
| PDF         | `pdf: ^3.11.1`                                                  |
| Files       | `file_picker`, `open_filex`, `path_provider`, `image_picker`, `image_cropper` |
| Crypto      | `crypto` (SHA-256 password hashing, document verification hashes) |
| Local state | `shared_preferences` (session persistence)                     |
| Config      | `flutter_dotenv`, `intl`, `cached_network_image`, `flutter_svg`, `shimmer` |

> **Note on Flutter version:** `pubspec.yaml` requires Dart `^3.10.1`. The "Flutter 3.10"
> phrasing in the old docs conflated the Dart SDK constraint with the Flutter version.

---

## 3. Architecture

Standard Flutter layered structure. **94 Dart files** under `lib/`.

```
lib/
├── main.dart                     # Entry point: Supabase init + 8 providers
├── config/
│   ├── routes.dart               # AppRoutes: all named routes (175 lines)
│   ├── supabase_config.dart      # .env loader (see Known Gaps #1)
│   └── theme.dart                # Material 3 theme
├── models/                       # 11 data models
├── providers/                    # 8 ChangeNotifier state containers
├── screens/
│   ├── splash_screen.dart
│   ├── verify_document_screen.dart
│   ├── auth/                     # login, register, pending_approval
│   ├── citizen/                  # dashboard, request_document, my_requests, profile,
│   │                             # notifications, submit_report, my_reports
│   │                             # (+ upload_payment_screen — dead, see §13.3)
│   └── admin/                    # dashboard, manage_users, create_user, pending_requests,
│                                 # pending_payments, captain_approval, all_requests, profile,
│                                 # settings, document_fees, document_formats, incident_reports
├── services/                     # Backend/data access (Supabase queries, AI, cache)
├── automation/                   # Pure-Dart pipeline rules, validators, PDF payloads
├── widgets/                      # Shared widgets (connectivity_banner)
├── l10n/                         # i18n (English, Filipino, Cebuano)
└── utils/                        # password hashing, sessions, validators, helpers, roles
```

**Data flow:** `screens/` → `providers/` (state + realtime subscriptions) → `services/`
(Supabase queries) → `models/` (typed DTOs) → back out as `ChangeNotifier` state.

---

## 4. Roles and Permissions

**Verified source: `lib/utils/role_access.dart`.** This multi-role model is the single most
important thing to understand about the app, and it was **completely undocumented** in the
old files.

### Roles

| Role value             | Display name          | Notes                          |
| ---------------------- | --------------------- | ------------------------------ |
| `captain`              | Barangay Captain      | Final document approval        |
| `secretary`            | Secretary             | Drafts, review, release        |
| `treasurer`            | Treasurer             | Payment verification only      |
| `kagawad_representative` | Kagawad Representative | Final document approval (substitute) |
| `barangay_tanod`       | Barangay Tanod        | Incident reports               |
| `citizen`              | Citizen               | Default role                   |
| `admin`                | Administrator         | **Legacy** superuser, retained in all permission checks |

`setup.sql` creates the `user_role` Postgres enum with all seven values up front, so no
`ALTER TYPE ... ADD VALUE` migration is needed.

### Permission matrix

| Capability                          | Allowed roles                                              |
| ----------------------------------- | ---------------------------------------------------------- |
| `canManageUsers`                    | captain, admin                                              |
| `canGenerateDrafts`                 | secretary, admin                                            |
| `canReviewDocuments`                | secretary, admin                                            |
| `canReleaseDocuments`               | secretary, admin                                            |
| `canVerifyPayments`                 | treasurer, admin                                            |
| `canApproveDocuments`               | captain, kagawad_representative, admin                      |
| `canManageReports`                  | captain, barangay_tanod, kagawad_representative, admin      |
| `canRevealSensitiveReporter`        | captain, admin                                              |
| `isOfficial` (any official role)    | all above except citizen                                    |

`isCaptain()` and `isKagawad()` helpers distinguish the two final approvers.
The `admin` role is deliberately kept as a legacy alias so existing accounts keep working —
prefer assigning real roles (`captain`, `secretary`, …) for new accounts.

---

## 5. Document Request Workflow

**Verified source: `lib/models/document_request.dart` (`DocStatus`) and
`lib/services/document_service.dart`.**

The app defines **16 request statuses**. The live workflow is a multi-stage,
role-gated pipeline:

```
  CITIZEN                SECRETARY              TREASURER            CAPTAIN / KAGAWAD
  ───────                ─────────              ─────────            ─────────────────

  [submitted]
      │
      ├──► recordDraftGenerated() ──► [draft_generated]
      │                                        │
      │                                        ├── requestRevision() ──► [needs_revision]
      │                                        │        (citizen edits, resubmits)
      │                                        │
      │                                        └── markVerifiedForPayment()
      │                                                 │
      │                          fee == 0 ──────────────┼──────────────► [for_approval]
      │                                                 │
      │                          fee > 0 ──► [invoiced] │
      │                                        │
      │                             submitPaymentReceipt()  (citizen uploads
      │                                          GCash receipt screenshot)
      │                                        │
      │                                        ├── treasurerRejectPayment()
      │                                        │      ──► [payment_rejected] ──► citizen repays
      │                                        │
      │                                        └── treasurerConfirmPayment()
      │                                                 └──► [for_approval]
      │                                                            │
      │                                    ┌───────────────────────┴────────┐
      │                              captainReject()                   (approve)
      │                                    │                              │
      │                                    ▼                              ▼
      │                             [rejected]              releaseDocument() → [released]
      │                                                                    │
      │                                       sets document_id (BRGY-GUION-…),
      │                                       final_document_url, verification token
      ▼
  (also) deleteRequest() → [cancelled]
```

### Status reference

| Constant                  | DB value                | Meaning                                        |
| ------------------------- | ----------------------- | ---------------------------------------------- |
| `submitted`               | `submitted`             | Citizen submitted, awaiting secretary           |
| `draftGenerated`          | `draft_generated`       | Secretary generated the draft                   |
| `needsRevision`           | `needs_revision`        | Secretary sent back for correction              |
| `verifiedForPayment`      | `verified_for_payment`  | Verified; fee assessment pending                |
| `invoiced`                | `invoiced`              | Invoice issued, awaiting payment                |
| `paymentSubmitted`        | `payment_submitted`     | Receipt uploaded, awaiting verification         |
| `paymentRejected`         | `payment_rejected`      | Receipt rejected; citizen must re-upload        |
| `paymentConfirmed`        | `payment_confirmed`     | Treasurer confirmed payment                     |
| `forApproval`             | `for_approval`          | Awaiting captain/kagawad final approval         |
| `approved`                | `approved`              | Approved                                        |
| `approvedForRelease`      | `approved_for_release`  | Approved, awaiting document release             |
| `released`                | `released`              | Final document released to citizen              |
| `rejected`                | `rejected`              | Rejected with reason                            |
| `cancelled`               | `cancelled`             | Cancelled by citizen                            |
| `pendingReview`           | `pending_review`        | **Legacy**                                     |
| `pendingPayment`          | `pending_payment`       | **Legacy**                                     |

> ✅ This list is now the source of truth. `setup.sql` defines `request_status` as
> `TEXT` with a CHECK constraint over exactly these 16 values, so the database cannot
> drift from the app again. See [§9](#9-database-schema) and
> [Known Gaps #2](#13-known-gaps-and-discrepancies).

### PDF generation

`lib/services/pdf_service.dart` (1,189 lines) generates all four document types:

- **Barangay Clearance** — legal size, "TO WHOM IT MAY CONCERN", dual signatures
- **Certificate of Indigency** — legal size, financial-assistance statement
- **Cedula** — certificate number `CTC-XXXXXXXX`, full personal data, tax assessment box
  (community tax due, issue date, 1-year validity)
- **Barangay ID** — credit-card size, front (blue gradient, photo, blood type, ID number)
  and back (emergency contact, reminders, signatures)

All generators accept an optional `profilePhotoUrl`, downloaded over HTTP and embedded as
`pw.MemoryImage`. Templates pull live `barangay_config` values (name, address, captain, logo).
`buildSignatureBlock()` renders the "DIGITALLY SIGNED" block.

Admins can preview all templates with sample data at
**Admin Dashboard → View Document Formats** (`/admin/document-formats`).

### AI features

The AI features route through `AiService` (`lib/services/ai_service.dart`), which invokes the
Supabase Edge Function at `supabase/functions/ai/`. Every AI call returns `null` on failure so
callers degrade gracefully.

| Service | Task | What it does |
| ------- | ---- | ------------ |
| `ai_id_verifier.dart` | `id-verifier` | Advisory ID/selfie pre-check at registration. Never auto-approves; produces `IdVerificationSuggestion` for manual review. |
| `ai_document_processor.dart` | `document-processor` | Validates/normalizes document request data on the citizen request screen ("AI check details"). |
| `ai_receipt_parser.dart` | `receipt-parser` | Parses GCash receipt screenshots (reference number, amount, date, confidence). |
| `ai_incident_classifier.dart` | `incident-classifier` | Suggests `report_type` + `priority` for citizen incident reports. |

All AI features are **advisory only** — final decisions always rest with human reviewers.

### Automation pipeline

Pure-Dart rules in `lib/automation/` (no Supabase dependency, fully unit-testable):

| File | Role |
| ---- | ---- |
| `pipeline_rules.dart` | State-machine transitions, legacy status mapping, overdue invoice check, receipt pre-check |
| `fee_assessor.dart` | Fee assessment — determines `paymentRequired` and validates amount |
| `document_data_validator.dart` | Per-document-type required-field validation (9 types) |
| `release_payload.dart` | Builds verification identity (document ID, token, QR URL, content hash) |
| `automation_constants.dart` | Shared constants (invoice due window, display labels) |

`DocumentAutomationService` orchestrates: `afterSubmission` (auto-draft + route), `afterPaymentReceipt`
(canonicalize status + notify), `afterPaymentConfirmed/Rejected` (notify), `afterCaptainApproved`
(generate final PDF + release).

### Offline cache

- `document_cache_service.dart` — caches a citizen's own document requests as JSON in SharedPreferences
- `incident_report_cache_service.dart` — caches a citizen's own incident reports

Both are write-through (saved after online fetch) and fallback (loaded when network fails).

### Connectivity

`connectivity_provider.dart` tracks network state via `connectivity_plus`. The `connectivity_banner.dart`
widget renders a floating "You're offline" pill above the navigator on every route.

### Internationalization (i18n)

`lib/l10n/` provides three locales: English (default), Filipino, Cebuano. `LocaleProvider`
persists the choice in SharedPreferences and drives `MaterialApp.locale`. Language switching
is available on both citizen and admin profile screens.

### Profile management

Both citizens and admins have profile screens (`/citizen/profile`, `/admin/profile`) with
view/edit modes, profile photo upload, password change, and language switching.

### Guarantor system

Indigent registrants without a valid government ID can be backed by an approved guarantor.
`guarantor_service.dart` manages the lifecycle: find approved guarantors, create/fetch/review
guarantor records in the `kyc_guarantors` table. Admins review pending guarantor applications
via the manage-users screen.

---

## 6. Incident Reports

**Verified source:** `lib/models/incident_report.dart`, `lib/services/incident_report_service.dart`,
`lib/screens/citizen/submit_report_screen.dart`, `lib/screens/citizen/my_reports_screen.dart`,
`lib/screens/admin/incident_reports_screen.dart`, table `incident_reports`.

Citizens file incident reports; officials (captain, tanod, kagawad) triage them.
Reporter identity is treated as sensitive — `canRevealSensitiveReporter()` restricts
anonymity protection to the captain and admin.

Supporting tables: `incident_reports`, `incident_updates`, `incident_attachments`.
The provider is `IncidentReportProvider` (registered in `main.dart`).

---

## 7. Document Verification

**Verified source:** `lib/models/document_verification.dart`, `lib/services/verification_service.dart`,
`lib/automation/document_access_rules.dart`, `lib/automation/print_copy_rules.dart`,
`lib/automation/verification_qr.dart`, `lib/screens/verify_document_screen.dart` (route `/verify`),
`lib/screens/citizen/document_viewer_screen.dart`.

When `releaseDocument()` runs, the service generates:

- `document_id` — format `BRGY-GUION-<year>-<6-digit sequence>`
- a SHA-256 **verification token** derived from document id + request id + timestamp
- a `qr_url` for scanning
- a real SHA-256 **`document_hash`** of the released PDF
- **policy columns** on the same `document_verifications` row: `expires_at`, `single_use`,
  `max_uses`, `use_count`, `used_at`

Anyone can verify a released document at `/verify` without logging in, using the document ID
or QR code. `DocumentAccessRules` (pure Dart) evaluates expiry / single-use / use-limit;
`VerificationService.consumeDocument` enforces it with an optimistic lock on the parent row's
`use_count`, so every scan that is actually used counts exactly once.

**Browser verification (no app required):** the `verify-document` Edge Function
(`supabase/functions/verify-document/`) serves a lightweight HTML page at the same QR code URL.
External agencies can scan a document QR code and verify it in any browser — the page renders
the verification result and provides a "Mark as Used" button that calls the same optimistic-locked
consume endpoint. Deploy with `supabase functions deploy verify-document`.

**View-only in the app:** `document_viewer_screen.dart` fetches the released file into memory,
checks its bytes against `document_hash`, renders it with `pdfrx`, stamps a per-view watermark,
and requests screenshot blocking (`no_screenshot`) while open. It has **no download button**.

**Printable copies (the one sanctioned export):** each printed/saved copy is a row in
`document_print_copies` with its OWN random `verification_token` and a human-readable `serial`
(`<document_id>-C01`), capped at 5 per document (`PrintCopyRules`). A decoded QR
(`https://<base>/verify/<document_id>?token=<copy token>`) resolves the copy back to the
PARENT `document_verifications` row, so expiry / single-use / use-limit policy is always
enforced against the parent — printing N copies can never multiply the use budget.
Mint → `VerificationService.issuePrintCopy`; regenerate the official PDF (signature block +
per-copy notice + token QR) → `DocumentAutomationService.generatePrintableCopyPdf`; export
via the `printing` package (platform print sheet / share-save as PDF). Errors degrade
gracefully (print cap reached, web/desktop unsupported).

> **Live database?** Instead of the destructive `setup.sql`, apply the additive, idempotent
> migrations in `supabase/migrations/` via the SQL Editor — both
> `20261007_document_print_copies.sql` **and** `20261007_document_policy_columns.sql`.
> Release/consume writes fail with "column … does not exist" until the policy-column
> migration is applied; the print-copies table is a separate prerequisite for
> "Request printable copy".

---

## 8. Setup — Step by Step

### Step 1 — Prerequisites

- Flutter SDK with Dart `^3.10.1` (run `flutter doctor`)
- A Supabase project
- Platform toolchain for your target (Android Studio / Xcode / VS Build Tools / Linux GTK deps)

### Step 2 — Get the code and dependencies

```bash
git clone <repo-url>
cd guin_app
flutter pub get
```

### Step 3 — Configure the environment file

Create `.env` in the repository root with exactly these two keys
(verified — these are the only keys the app expects):

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

Get both values from **Supabase Dashboard → Project Settings → API**.

> ✅ `.env` **is** read at runtime. `main.dart` calls `SupabaseConfig.initialize()`,
> which loads `.env` and throws if either key is missing. Editing `.env` now takes
> effect. See [Known Gaps #1](#13-known-gaps-and-discrepancies).

`.env` is also declared as a Flutter asset in `pubspec.yaml`, which is what
`flutter_dotenv` needs in release builds. ⚠️ It is currently **tracked in git** —
see the follow-up in [Known Gaps #1](#13-known-gaps-and-discrepancies).

### Step 4 — Create the database schema

Paste the whole of **`setup.sql`** into the Supabase Dashboard **SQL Editor** and
run it. That single file does everything: drops and rebuilds the schema, creates
the 4 storage buckets, and seeds fees, barangay config, role permissions, and the
first admin.

> ⚠️ `setup.sql` is **destructive** — it issues `DROP TABLE ... CASCADE` before
> rebuilding. Use it on a fresh or disposable project. For a database that already
> holds data, run only the commented-out **Incremental repair** block at the
> bottom of `setup.sql`, on its own.

The eight earlier scripts still exist under [`sql-legacy/`](sql-legacy/) but are
archived and must not be run — see that folder's README for what each one got wrong.

After running, the verification queries at the end of `setup.sql` should report
**18 tables** (`document_print_copies` is the per-print copy table) and **4 buckets**.

### Step 5 — Verify storage buckets

`setup.sql` creates all four, so this is only a check:

| Bucket             | Public | Size limit | Allowed MIME types                              |
| ------------------ | ------ | ---------- | ---------------------------------------------- |
| `profile-photos`   | yes    | 5 MB       | `image/jpeg, image/jpg, image/png, image/webp`  |
| `valid-ids`        | yes    | 5 MB       | `image/jpeg, image/jpg, image/png, image/webp`  |
| `payment-receipts` | yes    | 5 MB       | `image/jpeg, image/jpg, image/png, image/webp`  |
| `documents`        | yes    | 10 MB      | `application/pdf`                               |

These are the only four buckets the app writes to (verified across `lib/`).

### Step 6 — Seed configuration data

`setup.sql` seeds document fees, a placeholder `barangay_config` row, role
permissions, and an admin account. Document fees and barangay details are
database-driven: without a `barangay_config` row, PDF generation and payment
instructions fail with *"Barangay configuration not found"*. Update the seeded
placeholders via **Admin Dashboard → Barangay Settings** (`/admin/settings`).

### Step 7 — Run the app

```bash
flutter run                  # attached device / emulator
flutter run -d chrome        # web
```

`main.dart` sets `/` (splash) as the initial route; the splash screen restores any
saved session and routes by role and approval status.

### Step 8 — Realtime (handled by `setup.sql`)

`UserProvider`, `DocumentProvider` and `NotificationProvider` subscribe to Postgres
changes so dashboards self-update. `setup.sql` §8 adds `users_profile`,
`document_requests` and `notifications` to the `supabase_realtime` publication, so
there is nothing to do by hand.

Verify under **Supabase Dashboard → Database → Replication** if dashboards ever stop
live-updating. A table missing from the publication still opens its channel but
delivers no rows, so the failure is silent — pull-to-refresh masks it. Otherwise
pull-to-refresh works as a fallback regardless.

---

## 9. Database Schema

Everything below is created by **`setup.sql`**. The table set is the union of every
table and column referenced anywhere in `lib/`, verified against the Dart models
and services — not a copy of any single legacy script.

### Base tables

| Table                  | Purpose                                                        |
| ---------------------- | -------------------------------------------------------------- |
| `users_profile`        | Accounts, `password_hash`, approval workflow, role, KYC metadata (method/result/indigent/review audit)             |
| `document_requests`    | Requests, payment tracking, release + verification metadata    |
| `barangay_config`      | Barangay identity + GCash payment details + sample Barangay ID (front/back, single-row config)  |
| `kyc_guarantors`       | Guarantor registrations linking indigent citizens to approved guarantors                     |
| `document_fees`        | Per-`document_type` pricing                                    |
| `barangay_id_details`  | Type-specific fields for Barangay ID                           |
| `indigency_details`    | Type-specific fields for Certificate of Indigency              |
| `cedula_details`       | Type-specific fields for Cedula                                |
| `notifications`        | In-app notifications                                           |
| `role_permissions`     | Seeded role → permission keys                                  |

### Workflow and operations tables

`payments`, `document_versions`, `document_verifications`, `document_print_copies`
(per-print copy tokens/serials; policy stays on the parent `document_verifications` row),
`incident_reports`, `incident_updates`, `incident_attachments`,
`identity_access_logs`, `audit_logs`, `kyc_guarantors`.

### Enums

| Enum                  | Values                                                                                          |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `user_role`           | `admin`, `citizen`, `captain`, `secretary`, `treasurer`, `kagawad_representative`, `barangay_tanod` |
| `registration_status` | `pending`, `approved`, `rejected`                                                                 |
| `document_type`       | `barangay_clearance`, `indigency`, `barangay_id`, `cedula`                                       |
| `notification_type`   | `registration_approved`, `registration_rejected`, `request_approved`, `request_rejected`, `request_released`, `payment_verified`, `payment_rejected`, `incident_submitted`, `incident_updated`, `system` |

### Workflow columns are `TEXT`, not enums

`request_status`, `payment_status`, and `payments.status` are **`TEXT` with a CHECK
constraint**, deliberately not Postgres enums.

The three legacy scripts defined `request_status` three different ways — 4 values,
13 documented, 15 defined — and none matched the 16 statuses in
`lib/models/document_request.dart`. A Postgres enum also cannot be extended while
values are in use, so every schema change would need a new migration. `TEXT` makes
the app the single source of truth, which is what
`sql-legacy/supabase_workflow_migration.sql` asked for in its own trailing comment:
*"Status Reference (enforced in app, not DB enum)"*. See [Known Gaps #2](#13-known-gaps-and-discrepancies).

---

## 10. Storage Buckets

Four buckets, all created by `setup.sql` §7. Upload path convention is user- or
request-scoped, e.g. `profile-photos/<user_id>/<timestamp>.jpg`.

| Bucket             | Written by                          | Read by                                |
| ------------------ | ----------------------------------- | -------------------------------------- |
| `profile-photos`   | Registration, admin user creation   | Dashboards, PDF generation             |
| `valid-ids`        | Registration, admin user creation   | Pending-user review                    |
| `payment-receipts` | Citizen, via `DocumentProvider.submitPaymentReceipt()` | Treasurer (`pending_payments_screen`)  |
| `documents`        | PDF generation and release          | Citizen download, verification         |

**Common error:** `StorageException: Bucket not found (404)`. This means `setup.sql`
has not been run against the current Supabase project.

---

## 11. Creating the First Admin

### Option A — seeded by `setup.sql` (fastest)

`setup.sql` §9d inserts:

| Field    | Value                    |
| -------- | ------------------------ |
| Username | `admin`                  |
| Email    | `admin@barangay.local`   |
| Password | `Admin@123456`           |
| Role     | `admin` (legacy superuser) |

`password_hash` is stored as `<16-char salt>:<sha256(salt + password)>` — the exact
format `PasswordHash.verifyPassword()` in `lib/utils/password_hash.dart` parses. It is
**not** bcrypt; see [Known Gaps](#12-authentication-model-and-security-warnings).

> ⚠️ Change or delete this account before deploying anywhere reachable.

### Option B — promote an existing registration

1. Register through the app (4-step form: account → personal → address → documents).
2. Confirm the account appears as pending in **Admin Dashboard → Users** (`/admin/pending-users`).
3. Promote it:

```sql
UPDATE users_profile
SET role = 'captain',            -- or secretary / treasurer / kagawad_representative / barangay_tanod
    is_approved = TRUE,
    registration_status = 'approved'
WHERE id = '<user-uuid>';
```

Prefer assigning a real role over `admin`, since real roles exercise the actual
permission checks in `role_access.dart`.

### Option C — generate a password hash

`lib/utils/generate_admin_hash.dart` (and a duplicate at repo root) produces a
`salt:hash` string for a given password. Insert it into `password_hash` yourself.

> ⚠️ These dev credentials (`admin@barangay.local` / `Admin@123456`) are committed to the
> repo. **Rotate them before any deployment.**

### Registration flow (verified)

New accounts now use a two-branch automatic KYC pre-check (non-indigent) plus an
indigent bypass.

Registration accepts **any valid government ID** (barangay ID, driver's license, passport,
national ID, UMID, PRC, SSS, PhilHealth, postal ID, voter's ID, ...), and the AI pre-check is
**advisory only**: it returns `looks_ok` or `needs_review` and **never** approves or rejects a
registration — a captain/admin always reviews. It deliberately does **not** compare the selfie to
the face printed on the ID.

**Branch 1 — With a valid government ID (default)**
1. Register through the 4-step wizard: account → personal → address → documents.
2. In the Documents step the user uploads their **profile photo (selfie)** and their
   **government ID** (front, plus back for two-sided IDs) and picks the ID type.
   The "I have no valid government ID (indigent)" checkbox is **OFF**.
3. On submit, the app runs an **advisory** ID pre-check via the `id-verifier` edge
   function (`lib/services/ai_id_verifier.dart`). It reports ID authenticity/plausibility
   for the **declared** ID type, the detected ID type (and whether it matches), the selfie
   capture quality, a passive anti-spoof signal on the selfie, and per-field consistency
   against the submitted form fields. There is **no** sample-template comparison and **no**
   selfie-vs-ID face match.
4. The account is created as **pending** (`is_approved = false`, `registration_status = 'pending'`).
   A PII-safe `kyc_ai_result` (authenticity, type guess/match, selfie quality, liveness signal,
   field checks, advisory recommendation, reasons, `prompt_version`) is stored for the reviewer;
   the user is routed to `/pending-approval`.
5. Whether the pre-check is clean, unavailable (no AI call, quota/timeout/network), or
   returned an unusable payload, the registration **never blocks** and is **never auto-approved**:
   the captain/admin decides via **Admin → Manage Users → Pending** (`/admin/pending-users`).

**Branch 2 — Indigent (no valid ID)**
1. In the Documents step tick **"I have no valid government ID (indigent)"**. The
   Barangay ID upload is hidden and a required **"Reason / situation"** field appears;
   uploading a **Certificate of Indigency (optional)** stores it as `valid_id_url` for
   review.
2. On submit the app **skips the AI pre-check** entirely. The account is created as
   `pending` with `is_indigent = true`, `kyc_method = 'indigent_bypass'`, and
   `indigency_reason` set. It lands on `/pending-approval` and must be manually
   approved/rejected by the captain/admin. The Manage Users pending card shows a distinct
   **"Indigent — manual verification required"** badge.

**Admin approval/review details**
- Pending users show: the KYC/advisory badge, indigency reason + optional COI thumbnail when
  applicable, side-by-side profile photo and ID thumbnails (front and back for a two-sided ID),
  and a collapsible **AI pre-check summary** (ID authenticity, detected vs declared type,
  selfie quality, anti-spoof signal, name/birth-date/address/gender field checks, advisory
  recommendation, reasons, version) when `kyc_ai_result` exists. The summary carries the honest
  footnote: *"AI-assisted pre-check — final review by the barangay."*
- Approving a pending user sets `registration_status = 'approved'`, `is_approved = true`,
  `kyc_verified_at = NOW()`, `kyc_reviewed_by` to the approving admin/captain, and
  **coalesces `kyc_method` to `'manual_verified'`** if it was null (so a user whose
  pre-check was unavailable is marked as manually verified). Rejecting sets
  `registration_status = 'rejected'`, `is_approved = false`, and writes both
  `rejection_reason` and `kyc_rejection_reason`.

Only `captain` and `admin` can approve/reject users (`canManageUsers`). Login is
permitted while pending — the app routes to `/pending-approval` rather than blocking
sign-in outright.

---

## 12. Authentication Model and Security Warnings

### How it actually works

**Supabase Auth is NOT used.** `main.dart` initializes the Supabase *client* (for database,
storage, and realtime), but credentials are handled entirely by the app:

- Passwords are hashed in `lib/utils/password_hash.dart` as **`salt:SHA-256(password + salt)`**
- The salt is derived from the current millisecond timestamp (first 16 hex chars of its SHA-256)
- Hashes are stored in `users_profile.password_hash`
- Login = `SELECT` from `users_profile` by email, then compare the recomputed hash
- Sessions live in `shared_preferences` and are restored by `splash_screen.dart`
- `sql-legacy/create_admin_user.sql` header comments mention bcrypt, but **bcrypt is not used anywhere**

### Security posture — read before deploying

| Issue                                            | Severity | Detail                                                                 |
| ------------------------------------------------ | -------- | ---------------------------------------------------------------------- |
| SHA-256 password hashing                          | **High** | Unsalted-by-design fast hash; no bcrypt/Argon2. Trivially GPU-crackable. |
| Timestamp-derived salt                            | Medium   | Millisecond-resolution salt is low-entropy and predictable.             |
| RLS permissive, not role-based                    | **High** | `setup.sql` **enables** RLS, but every policy is `USING (true)`. This app authenticates in Dart, so `auth.uid()` is always `NULL` and any `auth.uid()`-based policy would silently deny everything. Net effect: the anon key can still read/write every table. Old docs claiming "RLS enabled with role-based policies" are false — enabling RLS is *not* the same as securing it. |
| Anonymous public storage buckets                 | Medium   | All four buckets are `public = true`; document paths are guessable from the verification ID scheme. |
| Security enforced client-side only               | **High** | All `can*` permission checks are Dart-side. A modified client bypasses every one. |
| `.env` tracked in git                             | Medium   | Now the single source of the URL + anon key, and it is committed. Harmless for a *public* anon key, but it will leak any secret added later. |
| Committed admin credentials                      | **High** | `admin` / `Admin@123456` seeded by `setup.sql` §9d and present in git history. |
| `authOptions: AuthFlowType.pkce` in config        | Low      | Set in `supabase_config.dart` but unused, since Supabase Auth is bypassed. |

**Before production, at minimum:** move to bcrypt/Argon2, move authentication to
Supabase Auth and then write real RLS policies keyed to `users_profile.role` (the
current permissive policies can simply be tightened once `auth.uid()` resolves),
make the `documents` bucket private with signed URLs, rotate the admin password, and
stop tracking `.env`.

---

## 13. Known Gaps and Discrepancies

Verified problems a resuming developer must know about.

### 1. ~~`.env` is not actually used at runtime~~ — **RESOLVED**

`main.dart` now calls `await SupabaseConfig.initialize();`, which loads `.env` via
`flutter_dotenv` and throws if `SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing. The
inline credentials and the `supabase_flutter` import were removed. Editing `.env` now
changes which project the app talks to.

Follow-up: `.env` is declared as an asset in `pubspec.yaml` (required by
`flutter_dotenv` in release builds) but is still **tracked in git**. Add it to
`.gitignore` and commit a `.env.example` instead, otherwise the first secret added to
that file is committed by accident.

### 2. ~~`request_status` enum is out of sync with the app~~ — **RESOLVED**

`setup.sql` defines `request_status` as `TEXT` with a CHECK constraint listing all 16
statuses from `lib/models/document_request.dart`. Same treatment for `payment_status`
and `payments.status`. The mismatch existed because the legacy scripts defined the enum
three different ways (4 values, 13 documented, 15 defined) and none matched the app.

Consequences of the fix:

- The legacy `notify_request_status()` / `notify_officials_new_request()` triggers were
  **dropped**, not ported. They branched on the 4-value enum and would not compile
  against a `TEXT` column. Notifications are now written by Dart. (The app never calls
  `.rpc()`, so no RPC was lost.)
- A commented-out **Incremental repair** block at the bottom of `setup.sql` converts an
  existing enum column to `TEXT` without dropping data.

### 2a. `audit_logs` has two incompatible writers — **open**

The app writes the same table in two different shapes:

| Writer                                              | Columns                                                                             |
| --------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `lib/services/audit_service.dart`                   | `actor_user_id`, `entity_type`, `entity_id`, `old_value`, `new_value`, `remarks`   |
| `lib/services/document_service.dart` → `_audit()`    | `request_id`, `actor_id`, `from_status`, `to_status`, `notes`                       |

The two legacy scripts each declared one of these, and `CREATE TABLE IF NOT EXISTS`
meant whichever ran first silently won. `setup.sql` §3l now creates the **union** of
both, with every column nullable, so neither writer fails. The duplication is still
worth collapsing: `document_service._audit()` should call `AuditService` instead.
Note its failures are swallowed by a bare `catch (_)`, so a schema mismatch there
currently loses audit rows without any visible error.

### 3. Dead / legacy code (no references anywhere in `lib/`)

| File                                  | Status                                                        |
| ------------------------------------- | ------------------------------------------------------------- |
| `lib/screens/admin/admin_dashboard_screen.dart` | Unreferenced — `routes.dart` uses `dashboard_screen.dart` aliased as `admin` |
| `lib/screens/admin/pending_users_screen.dart`   | Unreferenced — `/admin/pending-users` is wired to `ManageUsersScreen` |
| `lib/screens/citizen/upload_payment_screen.dart` | Unreferenced (547 lines) — no route registered; receipt upload happens via `DocumentProvider.submitPaymentReceipt()` inside the request flow |
| `lib/services/document_service_backup.dart`    | Unreferenced backup copy                                     |
| `lib/utils/password_helper.dart`                | Unreferenced — `password_hash.dart` is the one in use          |

Also duplicated: `generate_admin_hash.dart` exists at both the repo root and `lib/utils/`.

### 4. `captainApproval` route missing from `onGenerateRoute`

`AppRoutes.captainApproval` (`/admin/captain-approval`) **is** in the `routes` map, but
`onGenerateRoute` has no `case` for it. Named-route navigation to it falls through to
"No route defined". `captain_approval_screen.dart` is therefore reachable only through the
`routes` map / direct pushes.

### 5. Legacy 4-status code still present in `document_service.dart`

Alongside the new pipeline, older methods remain: `verifyPayment()`, `rejectPayment()`,
`approveRequest()`, `rejectRequest()`, `deleteRequest()`, `getStatistics()` (which still
counts only `pending_payment` / `pending_review` / `approved` / `rejected`). Confirm which
call sites are live before relying on them.

> **Fixed (2026-10-13):** `verifyPayment()` and `encodeCashPayment()` previously set
> `request_status` to `'pending_review'` instead of `for_approval` after payment confirmation,
> causing paid documents to loop between the secretary review queue and the payment queue
> instead of advancing to captain approval. Both now correctly transition to `for_approval`.

### 6. `password_hash` is not returned by `DocumentRequest.toJson()`

The model reads ~30 fields in `fromJson()` but `toJson()` writes only up to `reviewed_by`,
silently dropping the newer payment, approval, and release fields. Round-tripping a
`DocumentRequest` through `toJson()` loses data.

### 7. ~~No tests~~ — **RESOLVED**

`test/automation/` now holds ~100 offline, dependency-free unit tests for the pure-Dart layer
(`lib/automation/` ↔ `test/automation/`), including the document-access and print-copy rules.
Screens, providers, and Supabase-bound services are still untested — verify those manually
against §5's workflows.

---

## 14. Command Reference

```bash
flutter pub get            # install dependencies
flutter pub upgrade        # upgrade dependencies
flutter run                # run on attached device
flutter run -d chrome      # run on web
flutter analyze            # static analysis (flutter_lints)
flutter test               # run unit tests (test/automation)
flutter clean             # clear build artifacts
flutter doctor             # verify toolchain
flutter build apk          # Android release
flutter build web          # Web build
flutter build ios          # iOS build
```

Build output lands in `build/`.

---

## 15. File Map

### Entry point and configuration

| File                          | Role                                                    |
| ----------------------------- | ------------------------------------------------------- |
| `lib/main.dart`               | Supabase init via `SupabaseConfig`, 8 providers, theme, routes |
| `lib/config/routes.dart`      | All route constants + builders                           |
| `lib/config/supabase_config.dart` | `.env` loader, called from `main.dart` (§8.3)          |
| `lib/config/theme.dart`       | Material 3 theme                                         |
| `analysis_options.yaml`       | Lint configuration                                       |
| `pubspec.yaml`                | Dependencies and asset declarations (`.env` is an asset) |

### Models (`lib/models/`)

`user_profile`, `document_request`, `notification`, `barangay_config`, `document_fee`,
`payment_record`, `document_verification`, `document_print_copy`, `incident_report`,
`guarantor`

### Providers (`lib/providers/`)

`auth_provider` (283), `user_provider` (189), `document_provider` (716),
`notification_provider` (71), `barangay_provider` (109), `incident_report_provider` (106),
`connectivity_provider` (54), `locale_provider` (46)

### Services (`lib/services/`)

`auth_service` (327), `user_service` (521), `document_service` (727),
`notification_service` (144), `barangay_service` (100), `storage_service` (78),
`pdf_service` (2,369), `document_automation_service` (671), `payment_service` (68),
`incident_report_service` (84), `verification_service` (193), `audit_service` (25),
`ai_service` (61), `ai_id_verifier` (250), `ai_document_processor` (71),
`ai_receipt_parser` (77), `ai_incident_classifier` (63),
`document_cache_service` (69), `incident_report_cache_service` (67),
`guarantor_service` (125)

### Utilities (`lib/utils/`)

`role_access` (**read this first**), `password_hash`, `session_manager`, `validators`,
`helpers`, `constants`, `image_compressor`, `password_helper` *(dead)*, `generate_admin_hash`

### Automation (`lib/automation/`)

`pipeline_rules` (state machine, transitions, pre-checks), `fee_assessor` (fee logic),
`document_data_validator` (per-type validation), `release_payload` (verification identity),
`automation_constants` (shared constants)

### Widgets (`lib/widgets/`)

`connectivity_banner` — floating offline indicator

### Internationalization (`lib/l10n/`)

English (default), Filipino, Cebuano — ARB files + generated localizations

### Routes

| Path                            | Screen                       |
| ------------------------------- | ---------------------------- |
| `/`                             | Splash                       |
| `/login`, `/register`           | Auth                         |
| `/pending-approval`             | Pending approval             |
| `/citizen/dashboard`            | Citizen dashboard            |
| `/citizen/request-document`     | New request                  |
| `/citizen/my-requests`          | Request history              |
| `/citizen/my-reports`           | Incident report history      |
| `/citizen/submit-report`        | File incident report         |
| `/citizen/profile`              | Citizen profile management   |
| `/citizen/notifications`        | Notifications                |
| `/admin/dashboard`              | Admin dashboard              |
| `/admin/pending-users`          | Manage users                 |
| `/admin/pending-requests`       | Secretary review queue       |
| `/admin/pending-reviews`        | Alias of pending-requests    |
| `/admin/pending-payments`       | Treasurer queue              |
| `/admin/captain-approval`       | Captain/kagawad queue        |
| `/admin/all-requests`           | All requests                 |
| `/admin/profile`                | Admin profile management     |
| `/admin/incident-reports`       | Incident triage              |
| `/admin/settings`               | Barangay + GCash config      |
| `/admin/document-fees`          | Fee management               |
| `/admin/document-formats`       | PDF template preview         |
| `/verify`                       | Public document verification |

---

## 16. Project History

Reconstructed from the repository's root Markdown files, all of which have now been
consolidated into this document. Listed newest-first by their own stated dates.

| Date        | Milestone                                                                 |
| ----------- | ------------------------------------------------------------------------- |
| 2026-10    | AI features (ID verifier, document processor, receipt parser, incident classifier), automation pipeline, offline cache, i18n, guarantor system, profile screens |
| Dec 2025    | Phase 1 foundation: schema, models, services, theme, routing               |
|             | Multi-step (4-page) registration with photo + valid-ID upload             |
|             | Custom auth replaced Supabase Auth: SHA-256 hashing + local sessions      |
|             | Splash screen and status-based auto-routing added                         |
|             | GCash payment workflow, dynamic fees, barangay settings screen            |
| Dec 9, 2025 | PDF generation service, all four templates, format preview screen, generate-on-approval, citizen download |
|             | Photo embedding into PDFs, ID card front/back redesign                   |
| Undated     | Realtime subscriptions for users, documents, notifications                |
| Undated     | Public document verification with QR codes                                |
| Undated     | Incident reporting module                                                 |
| Undated     | Multi-role permissions (captain / secretary / treasurer / kagawad / tanod) and the 16-status document pipeline |
| Undated     | Payment records, document versions, audit logs, identity access logs      |

### What the old status documents got wrong

For anyone who reads them before this file: they were written as point-in-time completion
reports and were never reconciled with each other. Concretely, they claimed Provider was
"to be added" (it exists, 6 providers), that PDF generation was "pending" (1,189-line
service exists), that RLS was "enabled with role-based policies" (it was disabled, and is
now enabled with *permissive* policies — still not role-based), that the workflow was
4 statuses (it is 16), that `.env` drove Supabase config (it was bypassed; it now does
drive it), and they listed two different Supabase project URLs. They also named a specific
developer's local filesystem path. None of that is reproduced here.

The originals are preserved in [`docs/archive/`](docs/archive/) for history only, with a
README there explaining their unreliability.

---

*Consolidated 2026-09-26, comprehensively updated 2026-10-13. When you change the code,
update this file in the same commit.*
