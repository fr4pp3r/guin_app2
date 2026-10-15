# guin_app

Barangay E-Document System — a Flutter app for requesting and processing barangay
certificates (Barangay Clearance, Certificate of Indigency, Barangay ID, Cedula) and
incident reports, backed by Supabase.

> **Full documentation: [DOCUMENTATION.md](DOCUMENTATION.md)**
> Setup steps, architecture, the role/permission model, the document workflow, database
> schema, AI features, and known gaps are all documented there. Read it before making changes.

## Quick start

1. Create `.env` in the repository root:

   ```dotenv
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<your-anon-key>
   ```

2. Run the whole of [`setup.sql`](setup.sql) in the Supabase **SQL Editor**. It creates
   the schema, the four storage buckets, and the first admin account. It is destructive —
   use it on a fresh project.

3. ```bash
   flutter pub get
   flutter run
   ```

Full details, including how to upgrade an existing database, are in
[DOCUMENTATION.md §8](DOCUMENTATION.md#8-setup--step-by-step).

The eight superseded SQL scripts live in [`sql-legacy/`](sql-legacy/) for history only —
do not run them.

## Project layout

```
lib/
├── main.dart        # Entry point: Supabase init + 8 providers
├── config/          # routes, theme, supabase_config
├── models/          # Typed data models
├── providers/       # ChangeNotifier state + realtime subscriptions
├── screens/         # auth / citizen / admin UI
├── services/        # Supabase queries, PDF generation, AI, cache
├── automation/      # Pure-Dart pipeline rules, validators, PDF payloads
├── widgets/         # Shared widgets (connectivity banner)
├── l10n/            # i18n (English, Filipino, Cebuano)
└── utils/           # roles, password hashing, validators
```

## Before you commit

```bash
flutter analyze
```

`flutter analyze` must produce zero errors. `flutter test` runs the offline unit tests in
`test/automation/` (~100 tests for the pure-Dart automation layer).

## Known issues

`.env` now drives Supabase config, and the `request_status` drift is fixed (`setup.sql`
uses `TEXT` + `CHECK` over all 16 statuses). The open problems are security-related:

> **Fixed (2026-10-13):** `verifyPayment()` and `encodeCashPayment()` in `document_service.dart`
> previously set `request_status` to `'pending_review'` instead of `for_approval` after payment
> confirmation, causing paid documents to loop between the secretary review queue and the payment
> queue instead of advancing to captain approval. Both now correctly transition to `for_approval`.

- Row Level Security is **enabled but permissive** — this app authenticates in Dart, so
  `auth.uid()` is always `NULL` and real RLS policies would lock it out. The anon key can
  still read and write every table.
- Passwords use salted SHA-256, not bcrypt/Argon2.
- `audit_logs` has two incompatible writers in Dart.

See [DOCUMENTATION.md §12–13](DOCUMENTATION.md#12-authentication-model-and-security-warnings)
before deploying anywhere reachable.
