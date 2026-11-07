# Spec: Document Request Flow — Residency + AI Verification

Date: 2026-10-29 · Status: proposed (awaiting approval)

## What was asked

Document requests follow: citizen submits → AI verifies → secretary checks →
treasurer checks (if payment) → captain approves. Two pieces were missing:

1. **No residency gate.** Anyone could request a document. A Poblacion
   residency confirmation had to be added.
2. **AI ran only on a manual button press** (`request_document_screen.dart`
   "AI check details"), and its verdict was shown once and thrown away. The
   secretary never saw it.

## What was decided

- **Residency is confirmed once per account**, by the captain/admin during
  registration approval (`user_registration_detail_screen.dart`). It is a
  separate checkbox from the existing Approve/Reject — a user can be approved
  without being a resident, and a resident can be rejected. Every document
  request inherits the flag, so a resident is verified once, not per request.
- **AI verification runs automatically at submission** and its result is
  stored on the request row and shown to the secretary on the review page.
  It is advisory and non-blocking: a failure degrades to "AI unavailable"
  and the request proceeds exactly as before. No new status is needed.

## Constraints honored

- AI must never block the core workflow (free tier: 5–15 RPM). The AI call is
  fire-and-forget inside `afterSubmission`, errors are swallowed, and the
  request is never held.
- AI is advisory only — final decisions rest with human reviewers.
- `setup.sql` is the single source of schema; new additive columns also ship
  as a migration (`supabase/migrations/20261029_*.sql`) so live DBs from
  before this change get them.
- Existing status constants and transitions are untouched. `rejectPayment`
  and `approveRequest` still write their legacy values — out of scope here.
- No Supabase Auth, no `auth.uid()`-based RLS.

## Files to change

| File | Change |
| --- | --- |
| `supabase/migrations/20261029_poblacion_residency.sql` | New migration |
| `supabase/migrations/20261029_document_ai_review.sql` | New migration |
| `setup.sql` | Mirror both columns |
| `lib/models/user_profile.dart` | Add `isPoblacionResident` |
| `lib/services/user_service.dart` | `approveUser` accepts + writes it |
| `lib/providers/user_provider.dart` | `approveUser` accepts + forwards it |
| `lib/screens/admin/user_registration_detail_screen.dart` | Checkbox in the approval dialog |
| `lib/models/document_request.dart` | Add `aiReview` field + JSON |
| `lib/services/document_automation_service.dart` | `afterSubmission` runs AI, stores result |
| `lib/screens/admin/document_request_detail_screen.dart` | Show AI findings |
| `lib/l10n/app_en.arb` (+ceb, +fil) | New strings |

## Verification

- `flutter analyze` → zero errors (baseline ~56 info lints tolerated).
- `flutter test` → all 116 offline tests still pass (no logic changed in
  tested paths; model JSON round-trip gains one field).
- `npx --yes deno@latest check supabase/functions/ai/index.ts` → exit 0
  (no edge-function change, but re-run to be safe).
- Manual: register → approve with residency checked → request a document →
  secretary review page shows AI findings; approve without residency →
  request still works, badge shows "not a resident".