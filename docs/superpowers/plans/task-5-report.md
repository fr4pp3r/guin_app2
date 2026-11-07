# Task 5 Implementation Report: Self-Service Residency Verification Screen

## Summary
Implemented the citizen-facing self-service residency verification screen that allows unverified users to upload proof documents (utility bills, IDs) and get AI verification for Poblacion residency. Added blocking logic in the document request flow to redirect unverified users to this screen.

## Files Changed

### New Files
1. **`lib/screens/citizen/verify_residency_screen.dart`** - New verification screen with:
   - Header explaining Poblacion residency requirement
   - Upload section with camera/gallery options using `ImagePicker` + `ImageCompressor.toBase64Png`
   - Accepted proofs list (PALECO, water bill, PTTLC, TIN ID, driver's license/voter's card)
   - "Verify with AI" button calling `ResidencyProofService.uploadProof` → `AiResidencyVerifier.verify`
   - Loading state with progress indicator
   - Success state: calls `confirmProof`, refreshes `AuthProvider` user profile, navigates back
   - Failure state: shows AI notes, offers retry and "Contact the barangay" manual escalation
   - Graceful degradation for AI unavailable (null result)

### Modified Files
2. **`lib/config/routes.dart`**:
   - Added import for `VerifyResidencyScreen`
   - Added `static const String verifyResidency = '/verify-residency'` constant
   - Added route entry in `routes` map
   - Added case in `onGenerateRoute`

3. **`lib/screens/citizen/request_document_screen.dart`**:
   - Added residency check at start of `_submitRequest()` (before `createRequest`):
     ```dart
     if (authProvider.userProfile!.isResidentConfirmed != true) {
       Helpers.showConfirmDialog(context,
         title: l10n.verifyResidencyRequired,
         message: l10n.verifyResidencyRequiredMessage,
         confirmText: l10n.commonVerify,
         cancelText: l10n.commonCancel,
       ).then((confirmed) {
         if (confirmed == true && mounted) {
           Navigator.pushNamed(context, AppRoutes.verifyResidency);
         }
       });
       return;
     }
     ```

4. **`lib/l10n/app_en.arb`** - Added 9 new localization keys:
   - `verifyResidencyRequired`, `verifyResidencyRequiredMessage`
   - `verifyResidencyTitle`, `verifyResidencySubtitle`
   - `verifyResidencyUploading`, `verifyResidencySuccess`
   - `verifyResidencyFailed`, `verifyResidencyManualEscalation`
   - `commonVerify`

5. **`lib/l10n/app_ceb.arb`** - Added same 9 keys (English placeholder values)
6. **`lib/l10n/app_fil.arb`** - Added same 9 keys (English placeholder values)

## Verification Results

### Flutter Analyze
```
flutter analyze lib/screens/citizen/verify_residency_screen.dart lib/screens/citizen/request_document_screen.dart lib/config/routes.dart
```
- **Result**: Zero errors
- Only 3 pre-existing info-level warnings in `request_document_screen.dart` (use_build_context_synchronously) — tolerated per AGENTS.md

### Flutter Test
```
flutter test
```
- **Result**: All 120 tests pass
- No test regressions

## Compliance with Plan Requirements

✅ **Screen created**: `VerifyResidencyScreen` with all specified UI elements  
✅ **Route added**: `/verify-residency` with `AppRoutes.verifyResidency` constant  
✅ **Blocking logic**: Added to `request_document_screen.dart` before `createRequest` using `Helpers.showConfirmDialog`  
✅ **Localization**: All 9 keys added to all 3 ARB files  
✅ **AI never blocks**: Null result handled gracefully with manual escalation option  
✅ **Non-resident flows unaffected**: Incident reporting and announcements still work (not modified)

## Risk Notes
- The `assets/images/` directory referenced in `pubspec.yaml` is missing (pre-existing, unrelated to this task)
- The l10n generation command outputs a warning about l10n.yaml existing but this is expected behavior