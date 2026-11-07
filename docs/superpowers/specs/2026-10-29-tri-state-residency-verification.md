# Design: Tri-State Residency Verification with AI-Assisted Proof

Date: 2026-10-29 · Status: Approved

## 1. Intent
Separate Identity Verification (at registration) from Residency Verification (required for documents). Users can access the app regardless of residency, but document requests require Poblacion residency confirmation.

## 2. Decisions (from Builder Check)
1. **Existing users:** Migrate all `false` to `null` during setup.sql refresh
2. **AI result flow:** Auto-commit — AI verdict sets the column directly; officer can only override later via manual toggle
3. **Officer UI:** Three-way selector (confirmed/not_confirmed/unverifiable) instead of checkbox
4. **Residency check:** In the screen before `createRequest`, not in the provider
5. **`not_confirmed` behavior:** Leaves `null` — user can retry with different proof
6. **Proof storage:** Minimal table `document_residency_proofs` tracking upload date, status, and auditor notes

## 3. Goals
- Users with confirmed residency can request documents immediately
- Users with unverifiable residency can self-serve proof upload
- Officers have final override capability at any time
- No account access blocking based on residency status

## 4. Constraints
- AI must never block core workflow (5-15 RPM free tier)
- All AI calls must be fire-and-forget with graceful degradation
- Existing status constants remain untouched
- Single-barangay assumption maintained

## 5. What's left to the builder
- Exact styling of verification screens
- Error message wording and localization
- Animation/transitions between verification states

## 6. Implementation Decisions (added after execution)
- **Residency proof storage bucket:** Created manually in Supabase console as `residency-proofs`. Images are retained for 30 days then pruned. No code protection.
- **Manual escalation flow:** For verification failures or when AI is unavailable, citizens can select "Contact the barangay" on the screen, which opens the existing contact path.
- **Route:** The screen is reached via `/verify-residency`. Also displayed as an in-page modal from `request_document_screen.dart` if the user tries to request a document while unverified.
- **Storage bucket:** Must be created manually in Supabase console (`residency-proofs`). The `uploadProof` call will fail at runtime until this bucket exists.
