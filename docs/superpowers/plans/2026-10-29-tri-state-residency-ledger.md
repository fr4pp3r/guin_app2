# SDD ledger — plan: docs/superpowers/plans/2026-10-29-tri-state-residency.md

## Rulings
- **Existing users migration:** All `false` → `null` so current citizens aren't blocked from documents.
- **AI result flow:** Auto-commit — AI verdict sets the column directly; officer can only override later.
- **Officer UI:** Three-way selector (confirmed/not_confirmed/unverifiable).
- **Residency check placement:** Screen-level validation in `request_document_screen.dart`, not in the provider.
- **`not_confirmed` behavior:** Leaves `null` — user can retry with different proof.
- **Proof storage:** Minimal table `document_residency_proofs` tracking upload date, status, and auditor notes.

## Task Progress
- [x] Task 1: Database Schema and Migration — complete (20261029_poblacion_residency.sql: UPDATE false→null + ALTER DROP NOT NULL/DEFAULT; setup.sql:192 nullable; 20261029_residency_proofs.sql created)
- [x] Task 2: AI Handler Extensions — complete (id_verifier.ts emits is_poblacion_resident; residency_verifier.ts created + registered in index.ts; deno check exit 0)
- [x] Task 3: Dart Model Extensions — complete (UserProfile.isPoblacionResident bool?; IdVerificationSuggestion + ResidencyVerificationSuggestion; ResidencyProof model + service; AiResidencyVerifier; tests updated)
- [x] Task 4: UI - Approval Screen Three-Way Selector — complete (RadioGroup with 3 options replacing checkbox; approveUser signature nullable; l10n keys added)
- [x] Task 5: UI - Self-Service Residency Verification Screen — complete (VerifyResidencyScreen with photo picker + AI verification; blocking in request_document_screen.dart; route wired in routes.dart)
- [x] Task 6: Documentation and Localization — complete (l10n keys in all 3 .arb files; spec updated with implementation notes)