# Localization plan — utils_helpers

Source files scanned (content-only; no Dart was edited):
- `lib/utils/validators.dart`
- `lib/utils/helpers.dart`

Legend: `→ keyName` = new key defined in `tool/l10n_parts/utils_helpers.json`.
`→ common*` = reuse an existing key already defined in `lib/l10n/app_en.arb` (not redefined here).

Existing-key reuse is exact-string only. Near-miss messages that do NOT match an existing key
verbatim get new `util*` keys and are flagged in the notes below.

## lib/utils/validators.dart

### validateEmail (`validateEmail`)
- validators.dart:5 — "Email is required" → common* `authEmailRequired`
- validators.dart:13 — "Please enter a valid email" → utilEmailInvalid
  - Note: NOT reused `authEmailInvalid` ("Enter a valid email") — wording differs; new key keeps
    the exact source literal.

### validatePassword (`validatePassword`)
- validators.dart:22 — "Password is required" → common* `authPasswordRequired`
- validators.dart:26 — "Password must be at least 6 characters" → utilPasswordMinLength
  - Note: NOT reused `authPasswordMinLength` ("Must be at least {count} characters") — the ARB
    template has no "Password" subject. Alternative (not selected): call `authPasswordMinLength(6)`,
    which would render "Must be at least 6 characters".

### validateConfirmPassword (`validateConfirmPassword`)
- validators.dart:35 — "Please confirm your password" → utilConfirmPasswordRequired
  - Note: NOT reused `authConfirmPasswordRequired` ("Please confirm password") — source literal
    includes "your".
- validators.dart:39 — "Passwords do not match" → common* `authPasswordsDoNotMatch`

### validateRequired (`validateRequired(value, [String fieldName = 'This field'])`)
- validators.dart:48 — fieldName default value "This field" → utilThisField
- validators.dart:51 — "$fieldName is required" → utilFieldNameRequired ({fieldName} String
  placeholder, example "Last name")
- Composition (important — how the source composes):
  - Source: `return '$fieldName is required';` where `fieldName` defaults to `'This field'`.
  - Recommended wiring: keep passing a localized default (`fieldName: l10n.utilThisField`), then
    branch on the rendered result:
      `if (fieldName == l10n.utilThisField) return l10n.utilThisFieldRequired;`
      `return l10n.utilFieldNameRequired(fieldName);`
  - Do NOT blindly call `utilFieldNameRequired(utilThisField)` in fil/ceb — "Kailangan ang Ang
    field na ito" / "Kinahanglan ang Kini nga field" would be grammatically wrong; that is why
    `utilThisFieldRequired` exists as a fixed string for the default branch.
  - `utilThisField` is provided for the parameter default and for any call site that displays the
    bare fallback.

### validateUsername (`validateUsername`)
- validators.dart:59 — "Username is required" → common* `authUsernameRequired`
- validators.dart:63 — "Username must be at least 3 characters" → utilUsernameMinLength
  - Note: NOT reused `authUsernameMinLength` — same rationale as the password case above.
    Alternative: `authUsernameMinLength(3)` renders "Must be at least 3 characters".
- validators.dart:68 — "Username can only contain letters, numbers, and underscores" → utilUsernameInvalidChars

### validateAge (`validateAge`)
- validators.dart:77 — "Age is required" → utilAgeRequired
- validators.dart:82 — "Please enter a valid age" → utilAgeInvalid
- validators.dart:86 — "Please enter a valid age between 1 and 150" → utilAgeRange

### validatePhoneNumber (`validatePhoneNumber`)
- validators.dart:95 — "Phone number is required" → common* `authPhoneRequired`
- validators.dart:104 — "Please enter a valid Philippine mobile number" → utilPhoneInvalid

### validateFullName (`validateFullName`)
- validators.dart:113 — "Full name is required" → utilFullNameRequired
  - Note: NOT reused `commonFullName` ("Full Name") — that is a label, not a validation message.
- validators.dart:117 — "Full name must be at least 2 characters" → utilFullNameMinLength
- validators.dart:122 — "Full name can only contain letters and spaces" → utilFullNameInvalidChars

### validateAddress (`validateAddress`)
- validators.dart:131 — "Address is required" → common* `authAddressRequired`
- validators.dart:135 — "Please enter a complete address (at least 10 characters)" → utilAddressMinLength

### validatePurpose (`validatePurpose`)
- validators.dart:144 — "Purpose is required" → utilPurposeRequired
  - Note: NOT reused `commonPurpose` ("Purpose") — label key, not a validation message.
- validators.dart:148 — "Please provide more details (at least 10 characters)" → utilDetailsMinLength

### validateRejectionReason (`validateRejectionReason`)
- validators.dart:157 — "Rejection reason is required" → utilRejectionReasonRequired
  - Note: NOT reused `commonRejectionReason` ("Rejection Reason") — label key, not a validation
    message.
- validators.dart:161 — "Please provide more details (at least 10 characters)" → utilDetailsMinLength
  - SAME literal and same key as validators.dart:148 — one key serves both validators.

## lib/utils/helpers.dart

### showLoadingDialog (`showLoadingDialog`)
- helpers.dart:45 — "Loading..." → common* `splashLoading`

### showConfirmDialog (`showConfirmDialog` — defaults)
- helpers.dart:65 — confirmText default "Confirm" → common* `commonConfirm`
- helpers.dart:66 — cancelText default "Cancel" → common* `commonCancel`

### timeAgo (`timeAgo`) — ICU plural messages, one per unit
- helpers.dart:105 — "$years ${years == 1 ? 'year' : 'years'} ago" → utilYearsAgo ({count} num)
- helpers.dart:108 — "$months ${months == 1 ? 'month' : 'months'} ago" → utilMonthsAgo ({count} num)
- helpers.dart:110 — "${difference.inDays} ${... == 1 ? 'day' : 'days'} ago" → utilDaysAgo ({count} num)
- helpers.dart:112 — "${difference.inHours} ${... == 1 ? 'hour' : 'hours'} ago" → utilHoursAgo ({count} num)
- helpers.dart:114 — "${difference.inMinutes} ${... == 1 ? 'minute' : 'minutes'} ago" → utilMinutesAgo ({count} num)
- helpers.dart:116 — "Just now" → utilJustNow
- Composition: every template is a full sentence ("{count, plural, =1{1 year ago} other{{count}
  years ago}}") — the wiring lane passes the bare integer count and no longer composes
  "count + unit + ago" by hand. fil/ceb use one identical form for the `=1` and `other` branches
  (Filipino/Cebuano do not inflect for count), which is intentional.

### parseSupabaseError (`parseSupabaseError`)
- helpers.dart:122 — "An unknown error occurred" → utilErrorUnknown
- helpers.dart:128 — "Username already exists" → utilErrorUsernameExists
- helpers.dart:131 — "Email already exists" → utilErrorEmailExists
- helpers.dart:133 — "This record already exists" → utilErrorRecordExists
- helpers.dart:137 — "Invalid email address" → utilErrorEmailInvalid
- helpers.dart:141 — "Invalid password. Must be at least 6 characters" → utilErrorPasswordInvalid
- helpers.dart:154 — "You appear to be offline. Check your connection and try again" → utilErrorOffline
  - Note: NOT reused `commonRetryConnection` ("Check your connection and try again.") — the full
    message differs and carries the "offline" prefix.
- helpers.dart:159 — "You are not authorized to perform this action" → utilErrorUnauthorized
- helpers.dart:163 — "Record not found" → utilErrorNotFound
- helpers.dart:167 — "This email is already registered" → utilErrorEmailRegistered
- helpers.dart:170 — "An error occurred. Please try again" → utilErrorGeneric
- The branch keywords (`'duplicate key'`, `'socketexception'`, `'failed host lookup'`, etc.) are
  internal matcher tokens and stay untranslated (see Excluded).

### formatFileSize (`formatFileSize`)
- helpers.dart:182 — "$bytes B" → utilSizeBytes ({bytes} num, example "482")
- helpers.dart:184 — "${(bytes / 1024).toStringAsFixed(2)} KB" → utilSizeKB ({value} String, example "1.20")
- helpers.dart:186 — "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB" → utilSizeMB ({value} String, example "3.45")
- Composition: B/KB/MB are universal units — the templates are identical in en/fil/ceb. The KB/MB
  placeholder is typed **String** so the wiring lane can pass the pre-suffixed `toStringAsFixed(2)`
  value and preserve the exact "1.20" / "3.45" rendering (a num placeholder would drop trailing
  zeros). The byte count in utilSizeBytes is a raw integer, so it is typed num.

## Reused existing keys (defined in lib/l10n/app_en.arb, not redefined in utils_helpers.json)
authEmailRequired, authPasswordRequired, authPasswordsDoNotMatch, authUsernameRequired,
authPhoneRequired, authAddressRequired, splashLoading, commonConfirm, commonCancel

## Excluded (deliberately not keyed)
- validators.dart:9, :66, :99, :102, :120 — RegExp patterns (email, username, phone-cleaning,
  phone, full-name) are internal, not user-facing.
- validators.dart:80 `int.tryParse` — logic, no literal.
- helpers.dart:90, :95 — `DateFormat('MMM dd, yyyy')` / `DateFormat('MMM dd, yyyy hh:mm a')`
  patterns: locale-aware formatting stays inside intl/DateFormat, not ARB literals.
- helpers.dart:147-153 — offline-detection substrings (`'socketexception'`, `'clientexception'`,
  `'failed host lookup'`, `'unable to resolve host'`, `'connection'`, `'network'`, `'timeout'`)
  and :126-127, :136, :140, :157-158, :162, :166 — error-branch keywords: internal matcher tokens;
  only the returned user-facing messages are keyed.
- helpers.dart:174-177 `isFileSizeValid` — pure logic, no literals.
- helpers.dart:191-207 `getInitials` / `capitalize` / `capitalizeWords` — the `''` empty string
  is not a translatable message.
- helpers.dart:184, :186 numeric prefixes ("1.20", "3.45") — computed from data; only the unit
  suffix is keyed (inside utilSizeKB / utilSizeMB).

## Notes for the orchestrator
- `tool/l10n_parts/` currently holds only `auth.json`, `citizen_core.json`, `citizen_forms.json`.
  `admin_workflow.json` / `admin_manage.json` do not exist yet, so there was no conflict surface
  with them; `utils_helpers.json` adds no keys overlapping the ARB or the existing three parts.
- All 39 new keys carry all three locales; every EN template with a placeholder has matching
  placeholders in fil/ceb with `@key` metadata directly after the key.