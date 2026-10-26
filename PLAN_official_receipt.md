# Plan: Treasurer-Uploaded Official Receipt (citizen view + download)

Status: **implemented 2026-10-20** — `flutter analyze`: zero errors (95 pre-existing
baseline lints, no new ones); `flutter test`: **116 passed** (112 baseline + 4 new in
`test/models/official_receipt_test.dart`).

Implementation deviations from the original plan:
- No separate `official_receipt_screen.dart` — the shared
  `lib/widgets/full_screen_image_viewer.dart` (viewer + Download/Share action) is pushed
  directly from My Requests, which is simpler and keeps one viewer implementation.
- `cross_file` is not a direct dependency: `share_plus` re-exports the `XFile` type, so
  importing it directly triggered an `unnecessary_import` lint.
- Environment note: `flutter test` on the original machine could not reach github.com for
  `pdfium_dart`'s native-asset download; the hook was satisfied by placing `pdfium.dll`
  (extracted from the official `pypdfium2` wheel on PyPI) at
  `.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/win-x64/pdfium.dll`.
  Deleting that file lets a networked machine re-fetch the pinned chromium/7811 build.

## Decisions (confirmed)
1. **Upload timing:** mandatory step inside the *Confirm Payment* dialog — confirm/reject logic otherwise unchanged.
2. **Download:** add **`share_plus`** — fetch bytes → system share sheet (save to gallery/files) on mobile, browser download on web.
3. **Storage:** reuse the existing **`payment-receipts`** bucket (public, 5 MB, images) under a request-scoped path; one new column on `document_requests`.

## What exists today (integration points)
- Citizen's GCash screenshot → `payment_receipt_url` via `DocumentProvider.uploadReceipt()`; **the treasurer side has no upload at all** — only confirm/reject (`pending_payments_screen._verifyPayment:26` → `treasurerConfirmPayment`).
- The confirm funnel has exactly **one live call site**: `lib/screens/admin/pending_payments_screen.dart:43`. It flows `DocumentProvider.treasurerConfirmPayment` (`document_provider.dart:703`) → `DocumentAutomationService.afterPaymentConfirmed` (`document_automation_service.dart:304`) → `DocumentService.treasurerConfirmPayment` (`document_service.dart:136`).
- Citizens **never render any receipt image today** — `my_requests_screen.dart` only branches on URLs for status text. The e-receipt button at `my_requests_screen.dart:534` is the exact template for a new entry button.
- Viewer precedent: `_FullScreenImageViewer` (4 private copies) and the `InteractiveViewer` dialog in `pending_payments_screen.dart:243-276`. Download precedent: `StorageService.downloadFile` + `Printing.sharePdf` (PDF-only → hence `share_plus` for images).
- Realtime is free: `document_requests` is already in the publication, and `DocumentProvider.subscribeToUserDocuments` reloads My Requests on any change.

## 1. Schema (additive migration)
**New file** `supabase/migrations/20261024_official_receipt_url.sql` (sorts after `20261023_...`):

```sql
ALTER TABLE document_requests
  ADD COLUMN IF NOT EXISTS official_receipt_url TEXT;
```

One column is enough — `payment_verified_by/_at` already record who/when (the upload happens inside confirm).

**Also edit `setup.sql`** (next to `payment_receipt_url`) — it stays the single source of schema for fresh installs. No bucket, RLS, enum, or publication changes.

## 2. Model
`lib/models/document_request.dart`:
- Add `final String? officialReceiptUrl;` next to `paymentReceiptUrl`, parse `official_receipt_url` in `fromJson`, **and write it in `toJson()`** — don't repeat known gap §13.6 for the new field.

## 3. Service / provider plumbing
- **`DocumentService.uploadOfficialReceipt({required String requestId, required File image})`** — mirror of `uploadPaymentReceipt` (`document_service.dart:226-239`): upload to `payment-receipts` at **`<requestId>/official_<timestamp>.<jpg|png>`** (request-scoped, visibly distinct from the citizen's `<userId>/receipt_*`), return `getPublicUrl(...)`. Keep the exact `File`-based signature the citizen path uses (same platform behavior).
- **Thread `String? officialReceiptUrl` through the confirm funnel** — three signatures, one extra map entry:
  - `DocumentService.treasurerConfirmPayment` (:136): add `'official_receipt_url': officialReceiptUrl` to the **same UPDATE** that sets `for_approval` — status and receipt land atomically or not at all.
  - `DocumentAutomationService.afterPaymentConfirmed` (:304): pass through.
  - `DocumentProvider.treasurerConfirmPayment` (:703): pass to automation **and** to the fallback `_documentService.treasurerConfirmPayment` (:724).

## 4. Treasurer UI — confirm dialog with photo step
`lib/screens/admin/pending_payments_screen.dart` `_verifyPayment` (:26-62):
- Replace `Helpers.showConfirmDialog` with a dedicated dialog (`lib/screens/admin/confirm_payment_dialog.dart`) containing:
  - the existing amount message,
  - an **"Official receipt photo" slot**: tap → source sheet (camera/gallery) → `ImagePicker().pickImage(maxWidth: 1080, maxHeight: 1080, imageQuality: 85)` — identical parameters to `upload_payment_screen.dart:33-46`,
  - thumbnail preview with *retake / remove*,
  - **Confirm disabled until an image is chosen**.
- Dialog returns the picked `File?`. `_verifyPayment` then runs, inside its existing loading/try structure: `uploadOfficialReceipt` → `treasurerConfirmPayment(..., officialReceiptUrl: url)`. Upload-first ordering means a failed upload never touches status; a failed confirm leaves at worst one orphan file (harmless).
- **Rejection flow untouched.**
- **l10n:** new keys in all three arb files (`app_en.arb`, `app_fil.arb`, `app_ceb.arb`). (Notification copy stays hardcoded English, per existing convention.)

## 5. Citizen UI — view + download
- **`pubspec.yaml`:** add `share_plus` → `flutter pub get`.
- **New shared widget** `lib/widgets/full_screen_image_viewer.dart` — extract of the existing `_FullScreenImageViewer` (`document_request_detail_screen.dart:1003`) **plus a download/share AppBar action**. Use it for the new feature only; the 4 existing private copies stay as-is (optional cleanup later).
- **New screen** `lib/screens/citizen/official_receipt_screen.dart`: full-screen `InteractiveViewer` + `CachedNetworkImage`, AppBar action **Download/Share**:
  1. `http.get(Uri.parse(officialReceiptUrl))` (precedent: `pdf_service.dart:49`),
  2. `Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'official_receipt_<requestId>.jpg')])` — mobile → save-to-gallery/files via the share sheet; web → browser download.
- **Entry point** in `my_requests_screen.dart`: after the e-receipt button (:554), a `View official receipt` button rendered when `request.officialReceiptUrl != null`.
- Realtime/pull-to-refresh makes the button appear as soon as the treasurer confirms.

## 6. Notification (no migration)
The citizen already gets `payment_verified` from `afterPaymentConfirmed` (`document_automation_service.dart:316-322`). **Extend that message only when `officialReceiptUrl != null`**: *"Your official receipt is ready to view and download in My Requests."* Reuses the closed enum — no new `notification_type`.

## 7. Tests (offline, dependency-free)
- `test/models/...`: `fromJson` parses `official_receipt_url`; absent key → `null`.
- If the storage-path builder is a pure function, a small test for its output shape.
- No screen/service tests (untested by convention).

## 8. Documentation (same commit)
- `DOCUMENTATION.md`: §5 workflow diagram, §10 storage table (`payment-receipts` "Written by" gains treasurer), notifications table, changelog line.
- Fix stale §13.3 row: `upload_payment_screen.dart` **is live** (pushed via `MaterialPageRoute` from `my_requests_screen.dart:738` and `dashboard_screen.dart:1214`).

## Verification
1. `flutter analyze` → zero **errors** (leave ~56 baseline infos alone, add none) → `flutter test`.
2. Manual: treasurer confirm with photo; confirm disabled without photo; rejection/cash-encode unaffected; citizen views + shares on Android and Chrome; `payment_verified` mentions the receipt; missing migration produces "column does not exist" (then apply it).

## Risks / deploy order
- **Apply the migration before shipping the build** — the required-photo confirm writes `official_receipt_url`, so a missing column would block payment confirmation entirely.
- **Mandatory photo = mandatory capability**: gallery is always present; making the param optional (`String?`) is the one-line fallback if this bites.
- **Public bucket**: same posture as every other bucket today (DOCUMENTATION §10); `createSignedUrl` (`storage_service.dart`) is the alternative if that's unacceptable.
- `share_plus` is the only new dependency; `File`-based upload keeps the existing native-first web caveat (same as citizen upload).

## Optional follow-ups (out of core scope)
- Same picker in `_encodeCashPayment` — cash payments currently get no receipt.
- Re-upload/replace after confirm.
- "Official receipt" button on the citizen dashboard invoice card.
- Collapse the 4 private `_FullScreenImageViewer` copies into the shared widget.
