# Task 4 Report — UI Approval Screen Three-Way Selector

**Status:** ✅ Complete

**Commits:** (none — worktree, not yet committed)

## Changes

### `lib/services/user_service.dart`
- `approveUser(String userId, {bool? isResident})` — changed `isResident` from `bool` with default `false` to nullable `bool?`. Passing `null` means "leave as unverified", `true` = confirmed resident, `false` = not resident. The `is_poblacion_resident` column is written directly with the nullable value.

### `lib/providers/user_provider.dart`
- `approveUser(String userId, {bool? isResident})` — signature updated to nullable; forwards to service unchanged.

### `lib/screens/admin/user_registration_detail_screen.dart`
- `_isResident` field changed from `bool` to `bool?` (null = unverified).
- `_handleApprove()` dialog: replaced the `CheckboxListTile` with a `RadioGroup<String>` offering three options:
  - **Confirmed Resident** (`'true'`)
  - **Not a Resident** (`'false'`)
  - **Unverified — skip for now** (`'null'`)
- Pre-selection logic: if `_isResident` was previously set, that wins; otherwise if `_user.kycAiResult['is_poblacion_resident'] == 'confirmed'`, pre-select "Confirmed Resident"; otherwise default to "Unverified — skip for now".
- The `isResident` parameter passed to `approveUser` is derived from the selected radio value.

### `lib/l10n/app_en.arb`
- Added `adocdetResidencyStatus` ("Residency Status") and `adocdetUnverified` ("Unverified — skip for now") keys.

## Verification

- `flutter analyze lib/screens/admin/user_registration_detail_screen.dart lib/services/user_service.dart lib/providers/user_provider.dart` — **zero errors** (no issues found).
- `flutter test` — **120/120 passed** (exit code 1 is from a pre-existing pubspec asset warning, not a test failure).

## Concerns

- None. The three-way selector is the captain's residency decision, not a confirmation step. The AI verdict auto-commits the column; the officer selector is the override. All three states are explicitly visible and selectable.