# guin_app

Barangay E-Document System — a Flutter app for requesting and processing barangay
certificates (Barangay Clearance, Certificate of Indigency, Barangay ID, Cedula) and
incident reports, backed by Supabase.

> **Full documentation: [DOCUMENTATION.md](DOCUMENTATION.md)**
> Setup steps, architecture, the role/permission model, the document workflow, database
> schema, and known gaps are all documented there. Read it before making changes.

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
├── main.dart        # Entry point: Supabase init + 6 providers
├── config/          # routes, theme, supabase_config
├── models/          # Typed data models
├── providers/       # ChangeNotifier state + realtime subscriptions
├── screens/         # auth / citizen / admin UI
├── services/        # Supabase queries, PDF generation
└── utils/           # roles, password hashing, validators
```

## Before you commit

```bash
flutter analyze
```

There is currently **no test suite** (`test/` does not exist), so verify changes manually
against the workflows in `DOCUMENTATION.md`.

## Known issues

`.env` now drives Supabase config, and the `request_status` drift is fixed (`setup.sql`
uses `TEXT` + `CHECK` over all 16 statuses). The open problems are security-related:

- Row Level Security is **enabled but permissive** — this app authenticates in Dart, so
  `auth.uid()` is always `NULL` and real RLS policies would lock it out. The anon key can
  still read and write every table.
- Passwords use salted SHA-256, not bcrypt/Argon2.
- `audit_logs` has two incompatible writers in Dart.
- There is no test suite, so nothing above is enforced automatically.

See [DOCUMENTATION.md §12–13](DOCUMENTATION.md#12-authentication-model-and-security-warnings)
before deploying anywhere reachable.
