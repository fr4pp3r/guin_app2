# Task 3 Report — Dart Model Extensions (Tri-State Residency)

**Status:** ✅ complete
**Date:** 2026-10-29

## Changes

### `lib/models/user_profile.dart`
- `isPoblacionResident`: `final bool` → `final bool?` (nullable; null = unverified).
- Constructor default removed (`this.isPoblacionResident = false` → bare `this.isPoblacionResident`).
- `fromJson`: `json['is_poblacion_resident'] as bool? ?? false` → `json['is_poblacion_resident'] as bool?` (no fallback — null stays null).
- `toJson`: unchanged semantics — serializes the nullable value directly.
- `copyWith`: unchanged `bool? isPoblacionResident` param; passing null now clears the field (nullable semantics).
- Added getter `bool get isResidentConfirmed => isPoblacionResident == true;`

### `lib/models/residency_proof.dart` (new)
- `ResidencyProof` model: id, userId, proofUrl, status ('pending'|'confirmed'|'rejected'), auditorNotes, createdAt, verifiedAt.
- `fromJson` / `toJson` / `copyWith` with nullable-preserving sentinel (`_Unset`) for `auditorNotes` and `verifiedAt`.
- `_knownStatus` falls back to 'pending' for unknown values.

### `lib/services/ai_id_verifier.dart`
- `IdVerificationSuggestion`: added `final String? isPoblacionResident` (values: 'confirmed' | 'not_confirmed' | 'unverifiable').
- Added getter `bool get isPoblacionConfirmed => isPoblacionResident == 'confirmed';`.
- Constructor param added.
- `_residencyVerdicts` set + `_knownValue` parsing in `fromResult` (snake_case + camelCase aliases).
- `toStoredJson` now emits `'is_poblacion_resident': isPoblacionResident`.

### `lib/services/ai_residency_verifier.dart` (new)
- `ResidencyVerificationSuggestion` model: `isConfirmed` (bool), `addressMatch` (String), `notes` (List<String>), `confidence` (double).
- `fromResult` tolerant parser — missing fields fall back to safe defaults; returns null only when the payload is missing.
- `AiResidencyVerifier.verify({required String proofB64, required String fullName, String? documentType})` → calls `AiService().invoke('residency-verifier', {...}, timeout: 15s)`, returns null on any failure. Follows the `AiIdVerifier` pattern exactly.

### `lib/services/residency_proof_service.dart` (new)
- `uploadProof({required String userId, required File image, required String documentType})` → uploads to `residency-proofs` bucket at path `userId/proof.jpg`, inserts row status 'pending', returns `ResidencyProof`.
- `getProofsByUser(String userId)` → `List<ResidencyProof>` (newest first).
- `confirmProof({required String proofId, required String userId, required String? auditorNotes})` → status 'confirmed' + verified_at + flips `users_profile.is_poblacion_resident = true` (best-effort).
- `rejectProof(...)` → status 'rejected' + verified_at.

### Tests updated
- `test/automation/kyc_models_test.dart`: legacy-row test now asserts `isPoblacionResident == null` and `isResidentConfirmed == false` (was implicitly `false` via the old `?? false`).
- `test/automation/ai_id_verifier_test.dart`: two `toStoredJson` key-set assertions updated to include `'is_poblacion_resident'`.

## Verification

- `flutter analyze lib/models/user_profile.dart lib/models/residency_proof.dart lib/services/ai_id_verifier.dart lib/services/ai_residency_verifier.dart lib/services/residency_proof_service.dart` → **No issues found**.
- `flutter analyze` (full project) → **0 errors** (102 pre-existing info/warnings tolerated per AGENTS.md).
- `flutter test` → **120/120 passed** (was 116; 4 new tests added across the two touched files plus the existing suite).

## Concerns / Notes

1. **`residency-proofs` bucket not in `setup.sql`.** Per the task spec, the storage bucket must be created manually in the Supabase console. `ResidencyProofService` references it by name; nothing in the Dart layer will fail at compile time, but `uploadProof` will throw at runtime until the bucket exists. Add a storage policy for public read if you want the proof URL to be directly viewable.
2. **`approveUser` signature unchanged.** `UserService.approveUser(userId, {bool isResident = false})` still takes a bool. Task 4 owns the `{String? residencyStatus}` change — left untouched on purpose.
3. **`copyWith` semantics.** The `isPoblacionResident` param uses plain `bool?` (not a sentinel), matching the existing pattern in the file. Passing `null` clears the field — that is the intended nullable behavior, consistent with how `kycMethod`, `kycIdType`, etc. already work.
4. **`AiResidencyVerifier` confidence default.** `confidence` defaults to `0.0` when missing/unparseable — a degraded payload still returns a suggestion rather than null, matching the "help the reviewer" philosophy of `IdVerificationSuggestion.fromResult`.
5. **No new `info` lints introduced.** All new files use `debugPrint` (not `print`) and respect `use_build_context_synchronously` conventions.