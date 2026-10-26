# Document request: profile-driven autofill

## Intent

A citizen requesting a document should not retype information the barangay
already holds. They pick a document type and type the purpose. Everything else
comes from their approved profile.

## What exists today

`lib/screens/citizen/request_document_screen.dart` shows three fill-up families
(cedula, indigency, barangayId) with ~28 hand-typed fields. `UserProfile`
already stores: full name (given/middle/last), address, age, date of birth,
place of birth, civil status, gender, phone number.

`DocumentDataValidator` requires only profile-backed keys:
`first_name`, `last_name`, `full_name`, `address`, `birth_date`,
`birth_place`, `gender`, `contact_number`, `purpose`.

## Decision (user-chosen)

Form = **document type + purpose**, plus business clearance NEW/RENEW. All
fill-up fields are prefilled from the profile and moved into a collapsed
"details" section that the citizen can open and edit.

Fields with no profile source stay editable but optional, inside that section:

- cedula: height, weight, TIN, occupation, annual income
- indigency / oath / good moral: requester, requester address
- barangay ID: nothing extra (all three fields are profile-backed)

Rejected: dropping those fields entirely (incomplete cedula); extending
`users_profile` with new columns (schema + model + edit screen for fields most
citizens use once).

## How

1. **`lib/automation/profile_prefill.dart`** (new, pure): `Map<String, dynamic>
   profileDocumentData(UserProfile, String documentType)` returning the
   profile-backed subset per family. Unit-tested against
   `DocumentDataValidator`'s required keys for every supported type.
2. **Screen `initState`**: seed the existing controllers/discrete fields from
   that map. Clamp `gender`/`civil_status` to the dropdown values (`Other`
   gender from admin-created users falls back to `Male`). `_cedulaBirthDate`
   comes from `dateOfBirth`, so the existing birth-date guard passes.
3. **Single purpose field** for every family: delete
   `_indigencyPurposeController`, `_effectivePurpose`, and the conditional that
   hid the top-level purpose for indigency; the indigency data map writes the
   shared purpose.
4. **Layout**: business NEW/RENEW segmented button stays visible; every other
   field goes inside an `ExpansionTile` titled with the existing
   `reqDocDocumentDetails(title)` string and subtitle from one new l10n key,
   `reqDocPrefilledFromProfile` (en/fil/ceb, then `flutter gen-l10n`). If
   submit-time validation fails, expand the section so the errors are visible
   (`ExpansionTileController.expand()`).
5. `_getDocumentData()` keeps reading controllers — prefilled values are what
   get submitted, edits included. Validators stay as they are.

## Non-goals

- No schema changes, no new profile columns.
- No change to fees, payment, automation, approval, or PDF code.
- Not fixing the pre-existing cedula PDF key mismatch
  (`height_cm`/`tin_number`/`profession_occupation` vs `height`/`tin`/
  `occupation`) — noted in AGENTS-level docs only if asked.

## Verification

- `flutter analyze` → zero errors (pre-existing infos tolerated).
- `flutter test` → existing 116 tests plus the new prefill test pass.
- Manual: request one doc of each family on `flutter run -d chrome`; confirm
  the submitted `document_data` in the admin detail page matches the profile,
  and that a business-clearance renewal still records `RENEW`.
