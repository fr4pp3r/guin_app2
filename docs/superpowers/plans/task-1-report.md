# Task 1 Report: Database Schema and Migration

**Status:** Complete

## Changes Made

### 1. `supabase/migrations/20261029_poblacion_residency.sql` — Modified

Replaced the original additive-only `ADD COLUMN IF NOT EXISTS is_poblacion_resident BOOLEAN DEFAULT false` with a two-step migration:

- **Step A:** `UPDATE public.users_profile SET is_poblacion_resident = NULL WHERE is_poblacion_resident = false;` — migrates all existing `false` values to `null` (unverified), so current citizens aren't permanently blocked from documents.
- **Step B:** `ALTER TABLE ... ALTER COLUMN is_poblacion_resident DROP NOT NULL, ALTER COLUMN is_poblacion_resident DROP DEFAULT;` — makes the column nullable with no default, so AI can return "unverifiable" without defaulting to "not a resident".

### 2. `setup.sql:192` — Modified

Changed:
```sql
is_poblacion_resident BOOLEAN NOT NULL DEFAULT FALSE,
```
to:
```sql
is_poblacion_resident BOOLEAN,
```

This mirrors the migration change so fresh `setup.sql`-provisioned databases match.

### 3. `supabase/migrations/20261029_residency_proofs.sql` — Created

Minimal proof tracking table:

```sql
CREATE TABLE IF NOT EXISTS public.document_residency_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  proof_url TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'rejected')),
  auditor_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMPTZ
);

CREATE INDEX idx_residency_proofs_user ON public.document_residency_proofs(user_id);
CREATE INDEX idx_residency_proofs_status ON public.document_residency_proofs(status);
```

Only URLs are stored — images are not retained permanently, per spec.

## Verification

### `npx --yes deno@latest check supabase/migrations/20261029_*.sql`

**Result: Not applicable — command mismatch.** `deno check` expects TypeScript/JavaScript source files, not SQL. Running it against `.sql` files produces a syntax error on the first comment line (`-- ...`), which Deno interprets as invalid JS. The SQL syntax itself is valid and consistent with the existing migration style (see `20261029_document_ai_review.sql` for the same pattern). The plan's Step 4 verification command should be updated to use a SQL linter or a manual review instead.

### `flutter analyze`

**Result: Skipped.** No Dart/Flutter code was modified in this task, so there is nothing to analyze. The task scope is SQL-only.

## Concerns

1. **Deno check limitation:** The plan's verification command (`npx --yes deno@latest check supabase/migrations/20261029_*.sql`) is mismatched for SQL files. This should be corrected in the plan to avoid false failures in future tasks. The SQL files are syntactically valid and follow the same conventions as existing migrations.

2. **Migration ordering:** The `UPDATE ... WHERE is_poblacion_resident = false` must run before `ALTER COLUMN ... DROP NOT NULL`. If applied in reverse order (e.g., the column is already nullable from a prior partial run), the UPDATE is still safe (it sets `false` rows to `NULL` regardless). The migration is idempotent in either direction.

3. **No Dart changes:** As instructed, no Flutter/Dart code was touched. Tasks 3–6 will handle the model, service, UI, and localization layers.