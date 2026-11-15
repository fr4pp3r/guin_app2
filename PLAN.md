# Residency Verification — Admin Manual Review Lane

## Problem

A citizen uploads a residency proof via `/verify-residency` (AI-assisted). When
the AI cannot confirm (returns `null` or `is_confirmed: false`), the proof row is
left in `document_residency_proofs.status = 'pending'` and **no admin screen
exists to review it**. The only way to flip `users_profile.is_poblacion_resident`
is:

1. `ResidencyProofService.confirmProof()` — caller supplies `proofId` + `userId`
2. `UserService.approveUser(userId, isResident: ...)` — only called during
   registration approval, unrelated to residency proofs

So the officer has the data (proof rows exist, the profile flag exists) but no
UI path to act on it.

## Scope

Add ONE new admin screen + route + dashboard entry + l10n keys. Touch nothing
else.

## Files to change

| File | Change |
|------|--------|
| `lib/l10n/app_en.arb` | +11 keys (en) |
| `lib/l10n/app_fil.arb` | +11 keys (fil) |
| `lib/l10n/app_ceb.arb` | +11 keys (ceb) |
| `lib/config/routes.dart` | +1 route constant + 2 route map entries |
| `lib/screens/admin/dashboard_screen.dart` | +1 quick-action button (role-gated) |
| `lib/screens/admin/residency_proofs_screen.dart` | **NEW** — the review screen |
| `lib/utils/role_access.dart` | +1 permission helper |

## New l10n keys (all three ARBs)

```
verifyResidencyReviewTitle          "Review Residency Proofs"
verifyResidencyReviewSubtitle       "Review pending residency proofs and confirm or reject them."
verifyResidencyReviewLoadError      "Could not load residency proofs"
verifyResidencyReviewEmpty          "No pending residency proofs"
verifyResidencyReviewEmptyHint      "All submitted proofs have been reviewed."
verifyResidencyReviewConfirm        "Confirm"
verifyResidencyReviewReject         "Reject"
verifyResidencyReviewConfirmTitle   "Confirm residency?"
verifyResidencyReviewConfirmBody    "This will mark the proof as confirmed and set this user as a Poblacion resident."
verifyResidencyReviewRejectTitle    "Reject residency?"
verifyResidencyReviewRejectBody     "This will mark the proof as rejected. The user remains unverified."
verifyResidencyReviewNotesHint      "Notes (optional)"
verifyResidencyReviewConfirming     "Confirming..."
verifyResidencyReviewRejecting      "Rejecting..."
verifyResidencyReviewBack           "Back"
verifyResidencyReviewProofBy        "Proof by"
verifyResidencyReviewProofStatus    "Status"
verifyResidencyReviewProofDate       "Submitted"
verifyResidencyReviewProofNotes      "Notes"
verifyResidencyReviewViewProof       "View proof"
verifyResidencyReviewNoNotes         "No notes"
```

## New route

```dart
static const String residencyProofs = '/admin/residency-proofs';
```

Register in `routes` map and `onGenerateRoute`.

## New permission

```dart
static bool canReviewResidency(String role) =>
    role == captain || role == secretary || role == legacyAdmin;
```

## New screen: `lib/screens/admin/residency_proofs_screen.dart`

- State, `initState` loads proofs via `ResidencyProofService.getProofsByUser`
  filtered to status `'pending'` — but the service only has `getProofsByUser`,
  so we fetch all and filter client-side.
- List of pending proofs, each card shows: user name (lookup via
  `UserService.getUserProfile`), submitted date, status chip, auditor notes,
  "View proof" button (open proof URL in full-screen image viewer, reusing the
  pattern from `user_registration_detail_screen.dart`), Confirm / Reject
  buttons.
- Confirm: calls `ResidencyProofService.confirmProof(proofId, userId,
  auditorNotes)` → success snackbar + remove from list.
- Reject: dialog with optional notes field → `ResidencyProofService.rejectProof`
  → success snackbar + remove from list.
- Errors: show snackbar, keep row.
- Loading state, empty state, error state.

## Reuse

- `_FullScreenImageViewer` from `user_registration_detail_screen.dart` — copy
  the widget (it's private there); or better, extract nothing and just inline a
  simple full-screen viewer. Keep it minimal: `Material` + `AppBar` +
  `InteractiveViewer` + `Image.network`. ~25 lines.
- `Helpers.showSuccess/error snack`, `Helpers.showLoadingDialog/dismissDialog`.

## Verification

1. `flutter analyze` — zero errors (baseline ~56 info lints tolerated).
2. `flutter test` — 116 offline tests still pass (no test files touched).
3. Manual: open admin dashboard → "Review Residency Proofs" → list shows
   pending proofs → Confirm/Reject flows work and row disappears.