# Signature Support for Document PDFs

## Overview

Add signature support to document PDFs so that captains can upload a signature image, and when documents are approved, the signature is included in the PDF above the captain's name.

## Goals

- Captains can upload a signature image (PNG with transparent background) via UI
- Signature is embedded in final PDFs just above the approver name
- Works with existing PDF generation flow (barangay_clearance, indigency, cedula, etc.)
- Graceful degradation when signature is not available (show blank line like current behavior)

## Non-goals

- Electronic signature capture with stylus/touch (simple image upload only)
- Signature verification/authentication
- Storing signatures on the document itself (they remain in the PDF)

## Architecture

### 1. Data Storage

**Database Migration** (`supabase/migrations/20261125_signature_support.sql`):
- Add `signature_url` column to `users_profile` table
- Column type: TEXT, nullable (graceful degradation)

**Pattern**: Following the existing `profile_photo_url` pattern:
- File stored in Supabase Storage bucket `profile-photos` (or separate `signatures` bucket)
- Public URL stored in database
- Accessed via `UserService.getUserProfile()`

### 2. User Interface

**Signature Upload Screen** (new screen):
- Add to captain/official profile management
- Use `image_picker` for image selection (Android/iOS) or file picker (web)
- Validate: PNG format, max 2MB
- Upload to storage, get public URL
- Save URL to `users_profile.signature_url`

**Location**: Add a "Signature" section in the profile screen or a dedicated manage screen.

### 3. PDF Generation

**Modification to `PdfService.generateBarangayClearance` and all document generators**:
- Add new parameter: `String? approverSignatureUrl`
- Load signature image similar to profile photo (http.get + MemoryImage)
- If signature available, render it above the approver name
- If not available, show blank line (current default behavior)

**Signature placement** (in the signature block row):
```
[Signature Image]     [Blank Line for Name]
                        Barangay Captain
```

### 4. Workflow Integration

**Captain Approval Flow** (`captain_approval_screen.dart`):
- Pass approver's signature URL when calling PDF generation
- Get it from `auth.userProfile!.signatureUrl` after PDF is generated

**Document Automation** (`document_automation_service.dart`):
- `afterCaptainApproved` should pass signature URL to `generateFinalPdf`

## Implementation Status

### Completed ✓

1. ✓ Database migration created (`supabase/migrations/20261125_signature_support.sql`)
2. ✓ `signatureUrl` field added to `UserProfile` model
3. ✓ `uploadSignature` method added to `UserService`
4. ✓ PDF generation modified to accept and render signature (Barangay Clearance only)
5. ✓ Signature URL passed through captain approval flow

### Remaining

1. ☐ Add signature upload UI (in profile screen)
2. ☐ Update PDF generation for other document types (if needed)
3. ☐ Apply database migration to Supabase project

## Files Modified

- `supabase/migrations/20261125_signature_support.sql` (new)
- `lib/models/user_profile.dart` (added signatureUrl field)
- `lib/services/user_service.dart` (added uploadSignature method)
- `lib/services/pdf_service.dart` (added signature parameter and rendering)
- `lib/screens/admin/captain_approval_screen.dart` (pass signature URL)

## Usage

1. Captain navigates to their profile screen
2. Taps "Set Signature" button
3. Selects a PNG image (or takes a photo)
4. Image is uploaded and URL saved to their profile
5. When approving a document, the signature is included in the PDF

## Graceful Degradation

If signature is missing:
- PDF generation still works
- Blank line appears in signature block (matching current behavior)
- No error shown to user

## Security Considerations

- Signature files are stored in public bucket (same as profile photos)
- No additional auth needed (app uses shared_preferences sessions)
- File size limited to prevent abuse