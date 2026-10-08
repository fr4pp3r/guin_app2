# Legacy SQL (archived — do not run)

These eight scripts were moved here on consolidation. **Do not run them.**
They are kept only so the history of how the schema evolved stays readable.

Use [`../setup.sql`](../setup.sql) instead. It is the single, verified,
from-scratch setup and it supersedes everything in this folder.

| Archived script | What it did | Why it is superseded |
| --- | --- | --- |
| `supabase_drop_and_recreate.sql` | Destructive base schema. `request_status` enum with only 4 values (`pending`, `under_review`, `approved`, `rejected`). RLS left disabled. | Enum cannot represent the 16 statuses the app uses, and cannot be extended once values are in use. |
| `supabase_migration.sql` | "Update existing schema" path. Adds detail tables, notification triggers, and RLS policies built on `auth.uid()`. | Policies deny everything: this app authenticates in Dart, so `auth.uid()` is always `NULL`. Also rewrote `request_status` back down to 4 values. |
| `supabase_workflow_migration.sql` | Added the real workflow columns (secretary/invoice/captain stage) and an `audit_logs` table. | Its `audit_logs` shape is only half-used — `document_service.dart` writes it, but `audit_service.dart` uses a different shape. |
| `supabase_complete_system_migration.sql` | Added roles, payments, versions, verifications, incident tables, and the `role_permissions` seeds. | Defined a *second, conflicting* `audit_logs`. |
| `supabase_schema.sql` | Largest and most complete of the eight: all tables, incident enums, 5 trigger functions, and storage policies. | Its `request_status` enum has 15 values that still do not match the Dart code, and its `notify_*` functions assume that enum. |
| `setup_storage_buckets.sql` | Created the 4 storage buckets and their policies. | Folded into `setup.sql` §7 (now idempotent). |
| `fix_documents_bucket.sql` | One `UPDATE` making the `documents` bucket public. | Redundant — `setup.sql` already creates that bucket as public. |
| `create_admin_user.sql` | Bootstrap admin with a committed password hash. | Folded into `setup.sql` §9d. Kept here as the origin of the hash. |

## The two conflicts worth remembering

1. **`request_status` had three different definitions** across these files
   (4 values, 13 documented, 15 defined) and none matched the 16 in
   `lib/models/document_request.dart`. Resolved by making the column `TEXT` —
   which is what `supabase_workflow_migration.sql` asked for in its own
   trailing comment: *"Status Reference (enforced in app, not DB enum)"*.

2. **`audit_logs` was defined twice, incompatibly.** The app still has two
   writers, so `setup.sql` §3l creates the union of both shapes with all
   columns nullable. Consolidating the two Dart writers is still open work.

## Recovering a historical schema

Only if you need to inspect what an old intermediate state looked like. These
scripts are **not** a migration path and were never tested as one — running
them in any order will not reliably reproduce a working database.
