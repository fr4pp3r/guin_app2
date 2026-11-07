# Tri-State Residency Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement tri-state residency verification where users can have `confirmed`, `not_confirmed`, or `unverifiable` residency status based on AI analysis of IDs and utility bills.

**Architecture:** The `id-verifier` AI task is extended to detect Poblacion residency from ID addresses. A new `residency-verifier` task handles utility bill uploads. Users start as `null` (unverified), get auto-committed to `true` or `false` by AI, with officer override capability and self-service retry for `null` cases.

**Tech Stack:** Flutter 3.10.1, Supabase, Dart, Node.js (Supabase Edge Functions), Gemini AI

**Spec:** `docs/superpowers/specs/2026-10-29-tri-state-residency-verification.md`

## Global Constraints

- AI must never block core workflow (5-15 RPM free tier); treat null as "AI unavailable"
- No new status constants in request_status or payment_status
- Single-barangay assumption maintained; all logic tied to "Poblacion" keyword
- Existing approvals remain valid; migration moves all `false` to `null`

## Review Focus

- Existing approved users: migrate `false` → `null`, not permanently blocked
- AI `unverifiable` case: leaves `null`, allows user to retry with proof upload
- Officer three-way selector: confirmed/not_confirmed/unverifiable, not just boolean
- Residency check placement: screen-level validation, not inside provider/service
- Proof storage: minimal table tracking, not permanent image retention

---

### Task 1: Database Schema and Migration

**Files:**
- Modify: `supabase/migrations/20261029_poblacion_residency.sql`
- Modify: `setup.sql:188-193`
- Create: `supabase/migrations/20261029_residency_proofs.sql`

**Interfaces:**
- Produces: `users_profile.is_poblacion_resident` (nullable BOOLEAN)
- Produces: `document_residency_proofs` table (request_id, proof_url, status, notes, created_at)

- [ ] **Step 1: Update migration to allow NULL**

In `supabase/migrations/20261029_poblacion_residency.sql`:
```sql
-- Migrate existing false values to null (unverified) for users who need
-- to complete self-service proof upload instead of being permanently blocked.
UPDATE public.users_profile SET is_poblacion_resident = NULL
  WHERE is_poblacion_resident = false;

-- Make the column nullable so AI can return "unverifiable" instead of
-- defaulting to "not a resident".
ALTER TABLE public.users_profile
  ALTER COLUMN is_poblacion_resident DROP NOT NULL,
  ALTER COLUMN is_poblacion_resident DROP DEFAULT;
```

- [ ] **Step 2: Mirror in setup.sql**

In `setup.sql`, update the `users_profile` column definition at line ~192 to remove the `NOT NULL DEFAULT FALSE`:
```sql
is_poblacion_resident BOOLEAN,
```

- [ ] **Step 3: Create minimal proof tracking table**

Create `supabase/migrations/20261029_residency_proofs.sql`:
```sql
-- Tracks utility bill or secondary ID uploads for residency verification.
-- Store URLs only; images are deleted after verification period.
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

- [ ] **Step 4: Verify migrations**

Run: `Select-String -Path supabase/migrations/20261029_*.sql -Pattern "DROP|ALTER|CREATE" | Measure-Object | Select-Object Count`
Expected: 3 files modified, all SQL syntax matches existing migration style (no `DROP ... CASCADE` on live tables, only additive `ALTER`/`UPDATE`/`CREATE`)

---

### Task 2: AI Handler Extensions

**Files:**
- Modify: `supabase/functions/ai/handlers/id_verifier.ts:70-111,238-291`
- Create: `supabase/functions/ai/handlers/residency_verifier.ts`
- Modify: `supabase/functions/ai/index.ts:70-71`

**Interfaces:**
- Consumes: `IdVerificationSuggestion` schema extension (already added in previous session)
- Produces: `residency-verifier` task returning `{ is_confirmed: boolean, address_match: string, notes: string[] }`
- Produces: Registration of new task in router

- [ ] **Step 1: Wire is_poblacion_resident into id-verifier response**

In `supabase/functions/ai/handlers/id_verifier.ts`, add to the response body around line 276:
```typescript
is_poblacion_resident: isPoblacionResident,
```
And ensure `isPoblacionResident` is coerced from `obj.is_poblacion_resident` with fallback to `"unverifiable"`.

- [ ] **Step 2: Create residency_verifier handler**

Create `supabase/functions/ai/handlers/residency_verifier.ts`:
```typescript
// Handles utility bill / secondary ID uploads for self-service residency proof.
// Checks: name match against profile, address mentioning "Poblacion", document type validity.
// Returns { is_confirmed, address_match, notes, confidence }.
```

Key prompt requirements:
- OCR the uploaded document for name and address fields
- Check if address contains "Poblacion" or "Brgy. Poblacion"
- Compare name (case-insensitive, partial match tolerance) against provided `full_name`
- Return confidence score and explanatory notes

- [ ] **Step 3: Register new task in router**

In `supabase/functions/ai/index.ts`, add:
```typescript
import residencyVerifier from "./handlers/residency_verifier.ts";
// ...
const routes: Record<string, TaskHandler> = {
  // ... existing routes ...
  "residency-verifier": residencyVerifier,
};
```

- [ ] **Step 4: Verify edge function syntax**

Run: `npx --yes deno@latest check supabase/functions/ai/index.ts`
Expected: Exit code 0, no type errors

---

### Task 3: Dart Model Extensions

**Files:**
- Modify: `lib/models/user_profile.dart:1-60`
- Modify: `lib/models/document_request.dart:80-100`
- Create: `lib/models/residency_proof.dart`
- Modify: `lib/services/ai_id_verifier.dart:15,28,69,113-146,152-167,213-222`

**Interfaces:**
- Consumes: `IdVerificationSuggestion` extended with `isPoblacionResident`
- Produces: `UserProfile.isPoblacionResident` (nullable bool)
- Produces: `ResidencyProof` model with CRUD support

- [ ] **Step 1: Update UserProfile model**

In `lib/models/user_profile.dart`:
```dart
final bool? isPoblacionResident; // null = unverified, true = confirmed, false = not resident
```
Update `fromJson` to parse `is_poblacion_resident` with `??` fallback (no default).
Update `toJson` and `copyWith`.
Add extension: `bool get isResidentConfirmed => isPoblacionResident == true;`

- [ ] **Step 2: Create ResidencyProof model**

Create `lib/models/residency_proof.dart`:
```dart
class ResidencyProof {
  final String id;
  final String userId;
  final String proofUrl;
  final String status; // 'pending', 'confirmed', 'rejected'
  final String? auditorNotes;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  
  // factory fromJson, toJson, copyWith
}
```

- [ ] **Step 3: Extend IdVerificationSuggestion**

In `lib/services/ai_id_verifier.dart`:
Add `final String? isPoblacionResident;` (stores enum string: 'confirmed', 'not_confirmed', 'unverifiable')
Add getter: `bool get isPoblacionConfirmed => isPoblacionResident == 'confirmed';`
Update `fromResult` to parse `is_poblacion_resident`.
Update `toStoredJson` to include the field.

- [ ] **Step 4: Add residency proof service**

Create `lib/services/residency_proof_service.dart`:
- `uploadProof(requestId, userId, File image)` → `ResidencyProof`
- `getProofsByUser(userId)` → `List<ResidencyProof>`
- `confirmProof(proofId, auditorNotes)` → void

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/models/user_profile.dart lib/models/residency_proof.dart lib/services/ai_id_verifier.dart`
Expected: Zero errors

---

### Task 4: UI - Approval Screen Three-Way Selector

**Files:**
- Modify: `lib/screens/admin/user_registration_detail_screen.dart:42-155,340-420`

**Interfaces:**
- Consumes: `UserProfile.isPoblacionResident` (nullable bool)
- Produces: `approveUser(userId, residencyStatus)` with explicit status parameter

- [ ] **Step 1: Replace checkbox with three-way selector**

In `_handleApprove()`:
Replace the single `CheckboxListTile` with a `RadioGroup` or `DropdownButton` offering:
- "Confirmed Resident" (AI-preselected if verdict was "confirmed")
- "Not a Resident" 
- "Unverified — skip for now"

Pre-select based on `_user.isPoblacionResident` or AI suggestion if available.

- [ ] **Step 2: Update approveUser signature**

In `lib/providers/user_provider.dart` and `lib/services/user_service.dart`:
```dart
Future<bool> approveUser(String userId, {String? residencyStatus}) async
// where residencyStatus is 'true', 'false', or null
```

- [ ] **Step 3: Handle pre-selection from AI result**

If `_user.kycAiResult != null` and contains `is_poblacion_resident == 'confirmed'`, pre-select "Confirmed Resident" option.

- [ ] **Step 4: Verify UI renders correctly**

Run: `flutter analyze lib/screens/admin/user_registration_detail_screen.dart`
Expected: Zero errors

---

### Task 5: UI - Self-Service Residency Verification Screen

**Files:**
- Create: `lib/screens/citizen/verify_residency_screen.dart`
- Modify: `lib/screens/citizen/request_document_screen.dart:554-570`
- Modify: `lib/config/routes.dart`

**Interfaces:**
- Consumes: `UserProfile.isResidentConfirmed`
- Produces: Route `/verify-residency` with upload flow
- Produces: Redirect from request form when residency unverified

- [ ] **Step 1: Create verification screen**

Create `lib/screens/citizen/verify_residency_screen.dart`:
- Header explaining "You need to verify Poblacion residency to request documents"
- Upload section for:
  - PALECO/electricity bill
  - Water bill
  - PTTLC/phone bill
  - TIN ID
  - Driver's license or Voter's card (with visible Poblacion address)
- Progress indicator during AI verification
- Success state → navigate to document request
- Failure state → allow retry or contact barangay

- [ ] **Step 2: Block document requests for unverified users**

In `lib/screens/citizen/request_document_screen.dart`, before `createRequest`:
```dart
final authProvider = context.read<AuthProvider>();
if (!authProvider.userProfile!.isResidentConfirmed) {
  // Show dialog or redirect to verify residency
  Navigator.pushNamed(context, AppRoutes.verifyResidency);
  return;
}
```

- [ ] **Step 3: Add route**

In `lib/config/routes.dart`:
```dart
case AppRoutes.verifyResidency:
  return MaterialPageRoute(builder: (_) => const VerifyResidencyScreen());
```

- [ ] **Step 4: Verify no blocking on unrelated flows**

Run tests: `flutter test`
Expected: All 120 tests pass (verify incident reporting, announcements still work for non-residents)

---

### Task 6: Documentation and Localization

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ceb.arb`
- Modify: `lib/l10n/app_fil.arb`
- Update: `docs/superpowers/specs/2026-10-29-tri-state-residency-verification.md`

**Interfaces:**
- Consumes: New screen names and error messages
- Produces: Complete localization coverage for English, Cebuano, Filipino

- [ ] **Step 1: Add English strings**

In `lib/l10n/app_en.arb`:
```json
{
  "verifyResidencyTitle": "Verify Your Residency",
  "verifyResidencySubtitle": "To request official documents, you must be a verified resident of Barangay Poblacion.",
  "verifyResidencyUploadHint": "Upload one of the following:",
  "verifyResidencyAcceptedProofs": [
    "PALECO / Electricity Bill",
    "Water Bill",
    "PTTLC / Phone Bill",
    "TIN ID",
    "Driver's License or Voter's Card (with Poblacion address)"
  ],
  "verifyResidencyUploading": "Verifying your document...",
  "verifyResidencySuccess": "Residency verified! You can now request documents.",
  "verifyResidencyFailed": "Could not verify. Please try again or contact the barangay.",
  "adocdetResidencyStatus": "Residency Status",
  "adocdetUnverified": "Unverified — proof required for documents",
  "adocdetAwaitingReview": "Awaiting review"
}
```

- [ ] **Step 2: Add Cebuano and Filipino placeholders**

Copy English keys to `app_ceb.arb` and `app_fil.arb` with English values (to be localized later).

- [ ] **Step 3: Update spec with implementation notes**

Add implementation decisions from this plan to the spec doc for future reference.

- [ ] **Step 4: Final verification**

Run: `flutter analyze` and `flutter test`
Expected: Zero errors, all tests pass
