# End-to-End Document Request Pipeline Map

**Goal**: Expand from 3→8 certificate types (each with template + fill-up form).  
This document maps every place a document type is defined, priced, validated, generated, displayed, or listed.

---

## 1. Canonical Type Lists (Source of Truth)

| File | Line(s) | Mechanism | Current Types | **Must Update For New Type** |
|------|---------|-----------|---------------|------------------------------|
| `lib/utils/constants.dart` | 73–119 | `DocumentType` enum + `value` / `displayName` / `fromString` | `barangay_clearance`, `indigency`, `barangay_id`, `cedula` | ✅ Add enum case, `value`, `displayName`, `fromString` |
| `setup.sql` | 123–128 | Postgres `document_type` ENUM | Same 4 | ✅ `ALTER TYPE … ADD VALUE …` + regenerate `setup.sql` |
| `setup.sql` | 241–248 | `document_fees.document_type` FK to ENUM | Same 4 | Auto via ENUM |
| `supabase/functions/ai/handlers/document_processor.ts` | 14–19 | `DOCUMENT_TYPES` const array | Same 4 | ✅ Add to array + prompt text |

---

## 2. Fee Definition & Lookup

| File | Line(s) | Role | Notes |
|------|---------|------|-------|
| `setup.sql` | 792–799 | Seed rows for `document_fees` | 4 rows; **add new rows** for new types |
| `lib/models/document_fee.dart` | 58–71 | `documentTypeDisplay` getter | Hardcoded switch → **add case** |
| `lib/services/barangay_service.dart` | 61–90 | `getDocumentFees()`, `getDocumentFeeByType()` | Dynamic from DB; no code change needed |
| `lib/providers/barangay_provider.dart` | 19–25 | `getFeeByType()` | Delegates to in-memory `_fees` list; no code change |

> **Admin UI**: `document_fees_screen.dart` is fully dynamic (reads from provider). No code change to add a type.

---

## 3. Intake Validation (Pure Dart)

| File | Line(s) | Mechanism | Current Rules |
|------|---------|-----------|---------------|
| `lib/automation/document_data_validator.dart` | 7–12 | `supportedTypes` Set | **Must add new type string** |
| `lib/automation/document_data_validator.dart` | 32–53 | Per-type `switch` → `_require()` | **Must add case with required fields** |
| `lib/services/document_automation_service.dart` | 61–71 | `validateIntake()` static wrapper | Delegates to validator; no extra change |

> **AI fallback**: `AiDocumentProcessor` → edge function `document_processor.ts` (same `DOCUMENT_TYPES` list).

---

## 4. Fee Assessment (Pure Dart)

| File | Line(s) | Notes |
|------|---------|-------|
| `lib/automation/fee_assessor.dart` | 7–39 | `FeeAssessor.assess(documentType, feesByType)` — **data-driven**, no hardcoding. |
| `lib/services/document_automation_service.dart` | 74–91 | `assessFee()`, `feeMapFromList()` — thin wrappers. |

---

## 5. PDF Generation (Templates)

### 5.1 Low-level generators (`pdf_service.dart`)
Each type has a dedicated static method. **Add a new method per type.**

| Method | Lines | Uses |
|--------|-------|------|
| `generateBarangayClearance` | 27–210 | `doc_automation._generatePdf` |
| `generateIndigencyCertificate` | 213–402 | `doc_automation._generatePdf` |
| `generateCedula` | 405–613 | `doc_automation._generatePdf` |
| `generateBarangayId` | 616–1057 | `doc_automation._generatePdf` + preview screen |

### 5.2 Dispatcher (`document_automation_service.dart`)

| File | Lines | Mechanism |
|------|-------|-----------|
| `lib/services/document_automation_service.dart` | 469–549 | `_generatePdf()` — **large `switch(request.documentType)`** → calls `PdfService`. **Must add case.** |
| `lib/services/document_automation_service.dart` | 420–432 | `generateDraftPdf()` — public, same dispatcher |
| `lib/services/document_automation_service.dart` | 435–456 | `generateFinalPdf()` — public, same dispatcher |

### 5.3 Captain approval screen (independent final-PDF path)

| File | Lines | Notes |
|------|-------|-------|
| `lib/screens/admin/captain_approval_screen.dart` | 117–189 | **Duplicate `switch`** generating final PDF with e-signature. **Must add case.** |

---

## 6. Display Names (User-facing Labels)

| File | Line(s) | Getter/Map | **Must Update** |
|------|---------|------------|-----------------|
| `lib/utils/constants.dart` | 92–103 | `DocumentType.displayName` | ✅ |
| `lib/utils/constants.dart` | 47–49 | `AppStrings` constants | Optional (legacy) |
| `lib/models/document_request.dart` | 365–378 | `documentTypeDisplay` | ✅ |
| `lib/models/document_fee.dart` | 58–71 | `documentTypeDisplay` | ✅ |
| `lib/automation/automation_constants.dart` | 14–22 | `documentTypeLabels` map + `labelFor()` | ✅ (used in notifications) |

> **Icon mapping**: `_getDocumentIcon()` in `dashboard_screen.dart` (844–854), `my_requests_screen.dart` (559–569), `captain_approval_screen.dart` (624–635), `pending_requests_screen.dart` (75–114). **Add case in each.**

---

## 7. Citizen Fill-Up Form (Request Screen)

**File**: `lib/screens/citizen/request_document_screen.dart`

| Section | Lines | What to Extend |
|---------|-------|----------------|
| Document type cards | 418–435 | Add `_buildDocumentTypeCard()` call |
| Per-type controllers | 21–39 | Add new `TextEditingController` fields |
| `_getDocumentData()` | 79–109 | Add `case` returning field map |
| `_controllerForSuggestionField()` | 133–172 | Map AI suggestion fields to new controllers |
| Field builders | 586–623 (`_buildBarangayIdFields`), 626–655 (`_buildIndigencyFields`), 658–819 (`_buildCedulaFields`) | **Add new `_buildXxxFields()` widget** |
| Fee lookup on submit | 309–315 | Dynamic via provider — no change |

> This is the **biggest lift** for a new type: new controllers, validation, and form UI.

---

## 8. Admin Preview / Format Management

**File**: `lib/screens/admin/document_formats_screen.dart`

| Section | Lines | Change |
|---------|-------|--------|
| Preview cards | 167–196 | Add `_buildFormatCard()` with `onPreview: () => _generatePreview('new_type')` |
| `_generatePreview()` switch | 383–433 | Add `case 'new_type':` calling new `PdfService.generateXxx()` |

---

## 9. Citizen Listing (Dashboard / My Requests)

| File | Lines | Hardcoded `switch` on `documentType` |
|------|-------|--------------------------------------|
| `lib/screens/citizen/dashboard_screen.dart` | 844–854 | `_getDocumentIcon()` — add case |
| `lib/screens/citizen/my_requests_screen.dart` | 559–569 | `_getDocumentIcon()` — add case |

Uses `request.documentTypeDisplay` (model getter) for label — OK once model updated.

---

## 10. Admin Workflows (Secretary / Treasurer / Captain)

| File | Lines | Note |
|------|-------|------|
| `lib/screens/admin/pending_requests_screen.dart` | 75–114, 764–768 | Icon `switch` — add case |
| `lib/screens/admin/captain_approval_screen.dart` | 624–635 | `_docIcon()` — add case |
| `lib/screens/admin/captain_approval_screen.dart` | 117–189 | Final PDF generation `switch` — **must add case** |

---

## 11. Database Schema & Migrations

### Current `setup.sql` (fresh install)

| Table/Column | Lines | Constraint |
|--------------|-------|------------|
| `document_type` ENUM | 123–128 | 4 values |
| `document_fees.document_type` | 243 | FK to ENUM, UNIQUE |
| `document_requests.document_type` | 257 | FK to ENUM |
| Seed fees | 792–799 | 4 rows |

### Additive Migrations (Existing DBs)

| Migration | Purpose |
|-----------|---------|
| `supabase/migrations/20261007_document_print_copies.sql` | Print-copy tables |
| `supabase/migrations/20261007_document_policy_columns.sql` | `expires_at`, `single_use`, `max_uses`, `use_count` on `document_requests` + `document_verifications` |

> For a new type:  
> 1. `ALTER TYPE document_type ADD VALUE 'new_type';`  
> 2. `INSERT INTO document_fees …`  
> 3. Ensure `document_requests` column accepts it (already via ENUM).

---

## 12. Per-Type Detail Tables (Optional Extended Data)

| Table | For Type | Lines in `setup.sql` |
|-------|----------|----------------------|
| `barangay_id_details` | `barangay_id` | 343–352 |
| `indigency_details` | `indigency` | 354–363 |
| `cedula_details` | `cedula` | 365–376 |
| *(none)* | `barangay_clearance` | — |

> If new types need structured extra fields, create `new_type_details` table + FK to `document_requests`.

---

## 13. Checklist: Adding a New Document Type End-to-End

| # | Area | Files to Touch | Effort |
|---|------|----------------|--------|
| 1 | **Enum / Type List** | `constants.dart` (enum), `setup.sql` (ENUM + seed), `document_processor.ts` | Low |
| 2 | **Fee Seed** | `setup.sql` INSERT, (optional migration for existing DBs) | Low |
| 3 | **Display Names** | `constants.dart` (3 places), `document_request.dart`, `document_fee.dart`, `automation_constants.dart` | Low |
| 4 | **Validation Rules** | `document_data_validator.dart` (supportedTypes + switch) | Medium |
| 5 | **PDF Template** | `pdf_service.dart` (new `generateXxx()`), `document_automation_service.dart` (dispatcher + 2 places), `captain_approval_screen.dart` (dispatcher) | High |
| 6 | **Citizen Fill-Up Form** | `request_document_screen.dart` (card, controllers, `_getDocumentData`, `_controllerForSuggestionField`, new `_buildXxxFields()`) | **Highest** |
| 7 | **Admin Preview** | `document_formats_screen.dart` (card + `_generatePreview` switch) | Medium |
| 8 | **Icons** | `dashboard_screen.dart`, `my_requests_screen.dart`, `captain_approval_screen.dart`, `pending_requests_screen.dart` | Low |
| 9 | **AI Processor** | `document_processor.ts` (DOCUMENT_TYPES array + prompt) | Low |
| 10 | **Detail Table (if needed)** | `setup.sql` + migration | Medium |

---

## 14. Architectural Notes

- **Fees are data-driven** (DB + provider). Admin UI already supports arbitrary types.
- **Validation & PDF generation are the only hardcoded logic** per type.
- **Two PDF paths exist**: automation (draft/final) + captain approval screen (final with e-sig). Both have independent `switch` dispatchers — keep in sync.
- **AI document processor** is a thin passthrough; the edge function holds the authoritative `DOCUMENT_TYPES` list.
- **No Supabase Auth** — all RLS policies are `USING (true)`. `document_type` ENUM is the only DB-level constraint.

---

## 15. Suggested Refactor (To Make Future Additions Trivial)

1. **Centralize display metadata** in a single `DocumentTypeRegistry` (Dart) or JSON asset loaded at startup: `label`, `icon`, `requiredFields[]`, `pdfGenerator`, `formBuilder`.
2. **Replace all `switch(type)`** with registry lookups.
3. **Make `request_document_screen.dart` dynamic**: iterate registry, build form via `formBuilder` callback.
4. **Move PDF dispatch** to registry; `PdfService` gets a `registerGenerator(type, fn)` at startup.
5. **Edge function**: read allowed types from Supabase `document_fees` table (or a config table) instead of static array.

> This would reduce new-type addition to: DB seed + one registry entry (or JSON asset) + one PDF generator function + one form builder widget.