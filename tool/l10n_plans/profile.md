# Localization plan — profile

Source file scanned (content-only; no Dart was edited):
- `lib/screens/citizen/profile_screen.dart`

Legend: `→ keyName` = new key defined in `tool/l10n_parts/profile.json`.
`→ common*` / `→ auth*` / `→ role*` / `→ language*` = reuse an existing key already defined in `lib/l10n/app_en.arb` + a merged part (not redefined here).

Notes:
- The Language section (`_buildLanguageSection`, lines 1087–1205) is fully covered by existing keys — not keyed here.
- `profilePasswordMinLength` maps the hardcoded literal `'New password must be at least 6 characters'`; the implementer passes `6` as the `{count}` argument.
- `profileDateOfBirthSelected` maps the runtime-composed field label `'Date of Birth: ${Helpers.formatDate(...)}'`; the implementer passes the already-formatted date string as `{date}`.
- Gender / civil-status dropdown items are DB enum values rendered as-is (`child: Text(s)`); they stay English and are excluded (see Excluded).

## lib/screens/citizen/profile_screen.dart
- profile_screen.dart:98 — "Failed to pick image" (snackbar) → authFailedPickImage
- profile_screen.dart:118 — "Failed to pick ID image" (snackbar) → profileFailedPickIdImage
- profile_screen.dart:140 — "Please select date of birth" (snackbar) → authPleaseSelectDob
- profile_screen.dart:146 — "Save Changes" (confirm dialog title) → commonSaveChanges
- profile_screen.dart:148 — "Are you sure you want to save these changes? They will be subject to admin review." (confirm dialog message) → profileSaveChangesConfirm
- profile_screen.dart:153 — "Saving changes..." (loading dialog) → profileSavingChanges
- profile_screen.dart:179 — "Profile updated successfully. Changes are subject to admin review." (snackbar) → profileUpdateSuccess
- profile_screen.dart:191 — "Failed to update profile" (snackbar fallback) → profileUpdateFailed
- profile_screen.dart:207 — "Change Password" (dialog title) → profileChangePassword
- profile_screen.dart:216 — "Current Password" (dialog field label) → profileCurrentPassword
- profile_screen.dart:238 — "New Password" (dialog field label) → profileNewPassword
- profile_screen.dart:259 — "Confirm New Password" (dialog field label) → profileConfirmNewPassword
- profile_screen.dart:282 — "Cancel" (dialog action) → commonCancel
- profile_screen.dart:289 — "Please enter current password" (snackbar) → profileCurrentPasswordRequired
- profile_screen.dart:296 — "New password must be at least 6 characters" (snackbar) → profilePasswordMinLength ({count} placeholder = 6)
- profile_screen.dart:305 — "Passwords do not match" (snackbar) → authPasswordsDoNotMatch
- profile_screen.dart:310 — "Update" (dialog action) → commonUpdate
- profile_screen.dart:321 — "Updating password..." (loading dialog) → profileUpdatingPassword
- profile_screen.dart:333 — "Password updated successfully" (snackbar) → profilePasswordUpdated
- profile_screen.dart:337 — "Failed to update password" (snackbar fallback) → profilePasswordUpdateFailed
- profile_screen.dart:364 — "Profile" (app-bar title, loading state) → profileTitle
- profile_screen.dart:418 — "My Profile" (header title) → profileMyProfile
- profile_screen.dart:438 — "Edit" (header action) → commonEdit
- profile_screen.dart:454 — "Profile Photo" (full-screen viewer title) → commonProfilePhoto
- profile_screen.dart:566 — "Personal Information" (section header) → authPersonalInfoTitle
- profile_screen.dart:571 — "Full Name" (info row label) → commonFullName
- profile_screen.dart:578 — "Email" (info row label) → commonEmail
- profile_screen.dart:583 — "Username" (info row label) → commonUsername
- profile_screen.dart:588 — "Phone Number" (info row label) → commonPhoneNumber
- profile_screen.dart:593 — "Address" (info row label) → commonAddress
- profile_screen.dart:598 — "Additional Details" (section header) → profileAdditionalDetails
- profile_screen.dart:604 — "Age" (info row label) → commonAge
- profile_screen.dart:604 — "${userProfile.age} years old" (info row value) → profileAgeYearsOld ({age} placeholder)
- profile_screen.dart:608 — "Date of Birth" (info row label) → commonDateOfBirth
- profile_screen.dart:613 — "Place of Birth" (info row label) → commonPlaceOfBirth
- profile_screen.dart:618 — "Civil Status" (info row label) → commonCivilStatus
- profile_screen.dart:624 — "Gender" (info row label) → commonGender
- profile_screen.dart:630 — "Documents" (section header) → commonDocuments
- profile_screen.dart:633 — "Profile Photo" (document row label) → commonProfilePhoto
- profile_screen.dart:643 — "Valid ID" (document row label) → commonValidId
- profile_screen.dart:646 — "Valid ID" (full-screen viewer title) → commonValidId
- profile_screen.dart:655 — "Account" (section header) → authStepAccountLabel
- profile_screen.dart:661 — "Role" (info row label) → commonRole
- profile_screen.dart:665 — "Member Since" (info row label) → commonMemberSince
- profile_screen.dart:681 — "Change Password" (button) → profileChangePassword
- profile_screen.dart:705 — "Personal Information" (section header, edit mode) → authPersonalInfoTitle
- profile_screen.dart:711 — "Given Name *" (field label) → authGivenNameLabel
- profile_screen.dart:715 — "Given name is required" (validator) → authGivenNameRequired
- profile_screen.dart:721 — "Middle Name (optional)" (field label) → authMiddleNameLabel
- profile_screen.dart:729 — "Last Name *" (field label) → authLastNameLabel
- profile_screen.dart:733 — "Last name is required" (validator) → authLastNameRequired
- profile_screen.dart:741 — "Email" (read-only field label) → commonEmail
- profile_screen.dart:753 — "Username" (read-only field label) → commonUsername
- profile_screen.dart:764 — "Phone Number" (field label) → commonPhoneNumber
- profile_screen.dart:768 — "Phone number is required" (validator) → authPhoneRequired
- profile_screen.dart:776 — "Complete Address" (field label) → authCompleteAddressLabel
- profile_screen.dart:781 — "Address is required" (validator) → authAddressRequired
- profile_screen.dart:787 — "Additional Details" (section header, edit mode) → profileAdditionalDetails
- profile_screen.dart:795 — "Age (auto-calculated)" (read-only field label) → profileAgeAutoCalculated
- profile_screen.dart:809 — "Date of Birth (tap to select)" (field label, unset) → authDateOfBirthTapToSelect
- profile_screen.dart:810 — "Date of Birth: ${Helpers.formatDate(...)}" (field label, set) → profileDateOfBirthSelected ({date} placeholder)
- profile_screen.dart:820 — "Place of Birth" (field label) → commonPlaceOfBirth
- profile_screen.dart:824 — "Place of birth is required" (validator) → authPlaceOfBirthRequired
- profile_screen.dart:831 — "Civil Status" (dropdown label) → commonCivilStatus
- profile_screen.dart:851 — "Gender" (dropdown label) → commonGender
- profile_screen.dart:869 — "Documents" (section header, edit mode) → commonDocuments
- profile_screen.dart:873 — "Profile Photo" (upload row label) → commonProfilePhoto
- profile_screen.dart:880 — "Valid ID" (upload row label) → commonValidId
- profile_screen.dart:889 — "Account" (section header, edit mode) → authStepAccountLabel
- profile_screen.dart:896 — "Role" (read-only field label) → commonRole
- profile_screen.dart:907 — "Member Since" (read-only field label) → commonMemberSince
- profile_screen.dart:936 — "Cancel" (action button) → commonCancel
- profile_screen.dart:962 — "Save Changes" (action button) → commonSaveChanges
- profile_screen.dart:1240 — "Tap to view" (document row subtitle) → commonTapToView
- profile_screen.dart:1240 — "Not uploaded" (document row subtitle) → commonNotUploaded
- profile_screen.dart:1255 — "View" (document row action) → commonView
- profile_screen.dart:1342 — "Tap to upload" (upload row caption) → commonTapToUpload
- profile_screen.dart:1357 — "Barangay Captain" (role display) → roleCaptain
- profile_screen.dart:1359 — "Secretary" (role display) → roleSecretary
- profile_screen.dart:1361 — "Treasurer" (role display) → roleTreasurer
- profile_screen.dart:1363 — "Kagawad Representative" (role display) → roleKagawad
- profile_screen.dart:1365 — "Barangay Tanod" (role display) → roleTanod
- profile_screen.dart:1367 — "Administrator" (role display) → roleAdmin
- profile_screen.dart:1370 — "Citizen" (role display, default) → roleCitizen
- profile_screen.dart:1421 — "Failed to load image" (viewer error text) → profileFailedLoadImage
- profile_screen.dart:1437 — "No image available" (viewer empty text) → profileNoImageAvailable

Excluded (Language section — already localized in `app_en.arb` + parts, reuse by exact key): profile_screen.dart:1094 `languageSectionTitle`, :1100 `languageSectionSubtitle`, :1115 `languageEnglish`, :1120 `languageTagalog`, :1125 `languageCebuano`, :1200 `languageChanged({language})`.

Excluded (from data — user values, not UI strings): profile_screen.dart:519 `userProfile.fullName`, :528 `@${userProfile.username}`, :578 email value, :583 username value, :609 formatted date-of-birth value, :613 place-of-birth value, :619 civil-status value, :624 gender value, :661/896 role value (via `_getRoleDisplayName` — keyed instead), :665/907 created-at value, :873/880 photo bytes / stored URLs.

Excluded (DB enum values rendered verbatim, not localized display labels): civil-status dropdown items at profile_screen.dart:836-839 `'Single'`, `'Married'`, `'Widowed'`, `'Divorced'` and gender dropdown items at :855-857 `'Male'`, `'Female'`, `'Other'` — each is both the `value:` (written to DB) and the displayed `Text(s)`; translating them would write localized strings into `users_profile.gender` / `civil_status`. Kept English.

Excluded (non-text / decorations): profile_screen.dart:369 `CircularProgressIndicator` (no text), :1289-1303 image render/no text, :485 `Helpers.getInitials(...)` initials, camera/check overlay icons.

## Reused existing keys (defined elsewhere, not redefined in profile.json)
languageSectionTitle, languageSectionSubtitle, languageEnglish, languageTagalog, languageCebuano, languageChanged,
commonCancel, commonSaveChanges, commonEdit, commonUpdate, commonView, commonFullName, commonEmail, commonUsername, commonPhoneNumber, commonAddress, commonAge, commonDateOfBirth, commonPlaceOfBirth, commonCivilStatus, commonGender, commonDocuments, commonProfilePhoto, commonValidId, commonRole, commonMemberSince, commonTapToView, commonNotUploaded, commonTapToUpload,
authPersonalInfoTitle, authGivenNameLabel, authGivenNameRequired, authMiddleNameLabel, authLastNameLabel, authLastNameRequired, authPhoneRequired, authCompleteAddressLabel, authAddressRequired, authDateOfBirthTapToSelect, authPlaceOfBirthRequired, authPleaseSelectDob, authFailedPickImage, authPasswordsDoNotMatch, authStepAccountLabel,
roleCaptain, roleSecretary, roleTreasurer, roleKagawad, roleTanod, roleAdmin, roleCitizen