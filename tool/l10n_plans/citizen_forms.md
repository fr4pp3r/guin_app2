# Localization plan — Citizen forms (part: citizen_forms)

Keys live in `tool/l10n_parts/citizen_forms.json`.
Reused shared keys: `commonCancel`, `commonSave`, `commonReject`, `commonApprove`,
`commonView`, `commonRetry`, `commonBack`, `commonNext`, `commonContinue`, `commonUpload`,
`commonOptional`, `commonRequired`, `commonYes`, `commonNo`, `commonConfirm`, `commonPurpose`,
`commonAmount`, `commonStatus`, `commonAddress`, `commonFullName`, `commonEmail`,
`commonUsername`, `commonPassword`, `commonPhoneNumber`, `commonDateOfBirth`,
`commonPlaceOfBirth`, `commonCivilStatus`, `commonGender`, `commonMale`, `commonFemale`,
`commonOther`, `commonSingle`, `commonMarried`, `commonWidowed`, `commonDivorced`,
`commonAnonymous`, `commonSensitive`, `commonTapToView`, `commonNotUploaded`,
`commonTapToUpload`, `commonDocuments`, `commonProfilePhoto`, `commonValidId`.

Legend: `→ (keep)` = proper noun / brand / neutral / official name, not translated.
`→ keyName` = new key in `citizen_forms.json`. `→ commonX` = existing shared key.
`→ (dynamic)` = value sourced from model/service/formatted — excluded.

---

## lib/screens/citizen/request_document_screen.dart

```
36:  "Barangay Business Clearance" → (keep — official document title)
37:  "For business permits and renewals" → reqDocBusinessClearanceDesc
43:  "Barangay Certification" → (keep — official document title)
44:  "General barangay certification" → reqDocCertificationDesc
50:  "Barangay Clearance" → (keep — official document title)
51:  "Certificate of residence and good standing" → reqDocBarangayClearanceDesc
57:  "Oath of Undertaking" → (keep — official document title)
58:  "For first-time job seekers" → reqDocOathUndertakingDesc
64:  "Certificate of Indigency" → (keep — official document title)
65:  "For financial assistance purposes" → reqDocIndigencyDesc
71:  "Certificate of Good Moral Character" → (keep — official document title)
72:  "Character reference" → reqDocGoodMoralDesc
78:  "Certificate of Residency" → (keep — official document title)
79:  "Proof of residency" → reqDocResidencyDesc
85:  "Cedula" → (keep — official document title)
86:  "Community tax certificate" → reqDocCedulaDesc
92:  "Barangay ID" → (keep — official document title)
93:  "Official barangay identification" → reqDocBarangayIdDesc
99:  "Male", "Female" (_genders dropdown items) → commonMale / commonFemale
100: "Single", "Married", "Widowed", "Divorced" (_civilStatuses dropdown items) → commonSingle / commonMarried / commonWidowed / commonDivorced
264: "Failed to pick receipt image" → reqDocFailedPickReceipt
348: "Select a document type first" → reqDocSelectTypeFirst
355: "Enter a purpose first" → reqDocEnterPurposeFirst
374: "AI check unavailable" → reqDocAiUnavailable
402: "Suggestions applied — review the fields and submit" → reqDocSuggestionsApplied
425: "Details verified — submitting as entered" → reqDocDetailsVerified
428: "Issues found" → reqDocIssuesFound
436: "• $issue" → (dynamic — AI issue text)
442: "AI suggestions" → reqDocAiSuggestions
447: "${entry.key}: ${entry.value}" → (dynamic — AI suggestion entry)
452: "Normalized purpose: ${suggestion.normalizedPurpose}" → reqDocNormalizedPurpose
459: "Apply suggestions" → reqDocApplySuggestions
473: "Please select a document type" → reqDocPleaseSelectType
480: "Please select your birth date" → reqDocPleaseSelectBirthDate
507: "Request submitted! Please wait for admin verification." → reqDocRequestSubmitted
530: "Please select receipt image" → reqDocSelectReceiptImage
557: "Receipt uploaded! Waiting for admin verification." → reqDocReceiptUploaded
577: "Request Document" → reqDocTitle
590: "Select Document Type" → reqDocSelectDocumentType
604: "Purpose" (labelText) → commonPurpose
606: "Briefly describe the purpose of this request" → reqDocPurposeHint
610: "Please enter the purpose" → reqDocPleaseEnterPurpose
638: "AI check details" → reqDocAiCheckDetails
663: "Submit Request" → reqDocSubmitRequest
684: "Certificates & Clearances" → reqDocCertificatesClearances
704: "Free" → reqDocFeeFree
705: "Fee: ₱${fee.feeAmount.toStringAsFixed(2)}" → reqDocFeeLabel
794: "Barangay ID Details" → reqDocBarangayIdDetails
802: "Full Name" (labelText) → commonFullName
804: "Required" (validator) → commonRequired
810: "Address" (labelText) → commonAddress
813: "Required" (validator) → commonRequired
820: "Contact Number" (labelText) → commonPhoneNumber
823: "Required" (validator) → commonRequired
834: "${_selectedOption?.title ?? 'Document'} Details" (indigency) → reqDocDocumentDetails
841: "Name" (labelText) → commonFullName
844: "Required" (validator) → commonRequired
850: "Address" (labelText) → commonAddress
862: "Age" (labelText) → commonAge
872: "Civil Status" (labelText) → commonCivilStatus
883: "Requester" (labelText) → reqDocRequester
891: "Requester's Address" (labelText) → reqDocRequesterAddress
900: "Purpose" (labelText) → commonPurpose
902: "e.g., Medical assistance, Educational support" → reqDocPurposeHintExample
904: "Required" (validator) → commonRequired
915: "${_selectedOption?.title ?? 'Document'} Details" (cedula) → reqDocDocumentDetails
921: "Type of Application" → reqDocTypeOfApplication
933: "New" (SegmentedButton label) → reqDocNew
934: "Renewal" (SegmentedButton label) → reqDocRenewal
963: "Last Name" (labelText) → reqDocLastName
966: "Required" (validator) → commonRequired
974: "First Name" (labelText) → reqDocFirstName
977: "Required" (validator) → commonRequired
986: "Middle Name" (labelText) → reqDocMiddleName
994: "Address" (labelText) → commonAddress
997: "Required" (validator) → commonRequired
1006: "Gender" (labelText) → commonGender
1025: "Civil Status" (labelText) → commonCivilStatus
1045: "Birth Place" (labelText) → commonPlaceOfBirth
1068: "Birth Date" (labelText) → commonDateOfBirth
1074: "Select birth date" → reqDocSelectBirthDate
1075: "${day}/${month}/${year}" → (dynamic — formatted date)
1087: "Height (cm)" (labelText) → reqDocHeight
1098: "Weight (kg)" (labelText) → reqDocWeight
1110: "TIN" (labelText) → (keep — neutral/acronym)
1118: "Pinagkakakitaan (Trabaho/Negosyo)" → reqDocOccupation  (same text for all 3 locales — Philippine-native term)
1127: "Kabuuang Kita o Sweldo ng Nakaraang Taon" → reqDocAnnualIncome  (same text for all 3 locales — Philippine-native term)
1136: "Citizenship" (labelText) → reqDocCitizenship
1154: "Request Created Successfully!" → reqDocRequestCreatedSuccess
1166: "Payment Instructions" → reqDocPaymentInstructions
1171: "1. Send payment via GCash to:" → reqDocSendPaymentGcash
1177: "   Name: ${config.gcashName}" → reqDocPaymentName
1181: "   Number: ${config.gcashNumber}" → reqDocPaymentNumber
1188: "   Amount: ₱${fee.feeAmount.toStringAsFixed(2)}" → reqDocPaymentAmount
1197: "2. Take a screenshot of the GCash receipt" → reqDocScreenshotGcashReceipt
1202: "3. Upload the receipt below" → reqDocUploadReceiptBelow
1211: "Upload GCash Receipt" → reqDocUploadGcashReceipt
1230: "Tap to upload receipt" → reqDocTapToUploadReceipt
1257: "Submit Payment Receipt" → reqDocSubmitPaymentReceipt
1267: "Cancel Request" (dialog title) → reqDocCancelRequest
1269: "Are you sure you want to cancel this request? This action cannot be undone." → reqDocCancelRequestConfirm
1274: "No" (dialog button) → commonNo
1281: "Yes, Cancel" (dialog button) → reqDocYesCancel
1309: "Request cancelled successfully" → reqDocRequestCancelled
1333: "Cancel Request" (button) → reqDocCancelRequest
```

## lib/screens/citizen/submit_report_screen.dart

```
44:  "Type a short description first" → reportTypeDescriptionFirst
93:  "Incident report submitted successfully" → reportSubmittedSuccess
163: "Submit Incident Report" → reportTitle
171: "Report an incident to Barangay Guion" → reportSubtitle
194: "Report Details" (section label) → reportSectionDetails
202: "Type" (labelText) → reportTypeLabel
208: "Complaint" (dropdown item) → reportTypeComplaint
212: "Disturbance" (dropdown item) → reportTypeDisturbance
216: "Threat" (dropdown item) → reportTypeThreat
220: "Emergency" (dropdown item) → reportTypeEmergency
224: "Other" (dropdown item) → commonOther
240: "Priority" (labelText) → reportPriorityLabel
247: "Low" (_priorityItem label) → reportPriorityLow
250: "Normal" (_priorityItem label) → reportPriorityNormal
253: "High" (_priorityItem label) → reportPriorityHigh
254: "Urgent" (_priorityItem label) → reportPriorityUrgent
280: "AI suggest category" → reportAiSuggestCategory
287: "Category and priority suggested by AI — you can still change them." → reportAiSuggestedNote
295: "Incident Title" (labelText) → reportIncidentTitleLabel
297: "Brief, clear title" (hintText) → reportIncidentTitleHint
300: "Title is required" (validator) → reportTitleRequired
307: "Location" (labelText) → reportLocationLabel
309: "Where did this happen?" (hintText) → reportLocationHint
312: "Location is required" (validator) → reportLocationRequired
320: "Description" (labelText) → reportDescriptionLabel
322: "Describe the incident in detail..." (hintText) → reportDescriptionHint
326: "Description is required" (validator) → reportDescriptionRequired
332: "Privacy Options" (section label) → reportSectionPrivacy
337: "Mark as Sensitive" (option title) → reportMarkSensitive
339: "Use for threats or safety-risk reports requiring restricted access" (option subtitle) → reportMarkSensitiveSubtitle
347: "Submit Anonymously" (option title) → reportSubmitAnonymously
349: "Your identity is hidden; all access is audited by admin" (option subtitle) → reportSubmitAnonymouslySubtitle
377: "Submitting..." (button, busy) → reportSubmitting
377: "Submit Report" (button) → reportSubmitButton
```

## lib/screens/citizen/upload_payment_screen.dart

```
50:  "Please select receipt image" → paySelectReceiptImage
69:  "Receipt uploaded! Waiting for admin verification." → payReceiptUploaded
141: "Upload Payment Receipt" → payTitle
149: "Complete your document request" → paySubtitle
183: "${widget.request.documentTypeDisplay}  ·  ₱${...}" → (dynamic — documentTypeDisplay + amount)
234: "Payment Instructions" → payPaymentInstructions
243: "Send payment via GCash to:" (_step 1) → payStepSendPayment
275: config.gcashName → (dynamic)
300: config.gcashNumber → (dynamic)
315: "Loading GCash details..." → payLoadingGcash
328: "Amount: ₱${widget.request.paymentAmount.toStringAsFixed(2)}" → payAmountLine
338: "Screenshot your GCash confirmation" (_step 2) → payStepScreenshot
340: "Upload the screenshot below" (_step 3) → payStepUploadBelow
350: "GCash Receipt Screenshot" → payReceiptScreenshotLabel
394: "Tap to select screenshot" → payTapToSelectScreenshot
402: "JPG, PNG accepted" → payImageFormatsAccepted
445: "Change" (overlay button) → payChange
488: "Uploading..." (button, busy) → payUploading
489: "Submit Payment Receipt" (button) → paySubmitPaymentReceipt
520: "Cancel" (button) → commonCancel
```

## lib/screens/citizen/document_viewer_screen.dart

```
143: "Barangay Resident" (fallback watermark name) → viewerDefaultName
199: "The document link for this request is not in the expected format." → viewerLinkInvalidFormat
225: "No document file is attached to this request yet." → viewerNoFileAttached
323: "Official copy • view only" → viewerOfficialCopyViewOnly
347: "SECURE" (badge) → viewerSecureBadge
382: "Preparing your document…" → viewerPreparing
391: "Verifying the file and applying your personal watermark." → viewerVerifying
426: "We could not open this document" → viewerOpenErrorTitle
436: "Please try again in a moment." → viewerTryAgainMoment
450: "Try again" (button) → commonRetry
468: "Go back" (button) → commonBack
533: "This file could not be displayed." → viewerFileNotDisplayed
567: "Integrity verified — file matches record" → viewerIntegrityVerifiedTitle
569: "The file's SHA-256 content hash matches the record held by the barangay. This confirms the file was not altered after release; scan the QR code to confirm authenticity with the barangay." → viewerIntegrityVerifiedMessage
575: "Integrity check failed — may be tampered with" → viewerIntegrityFailedTitle
577: "The hash of this file does not match the hash recorded at release. Request a fresh copy if in doubt." → viewerIntegrityFailedMessage
583: "No integrity hash on record" → viewerIntegrityUnknownTitle
585: "This document was issued without a stored checksum, so its authenticity cannot be confirmed here." → viewerIntegrityUnknownMessage
696: "Unlimited" (uses remaining) → viewerUsesUnlimited
748: "Purpose: ${request.purpose}" → viewerPurposeLine
790: "DOCUMENT ID" (summary label) → viewerDocumentIdLabel
790: "Not yet issued" (fallback value) → viewerNotYetIssued
796: "USES REMAINING" (summary label) → viewerUsesRemainingLabel
808: "VALID UNTIL" (summary label) → viewerValidUntilLabel
810: "No expiry" (fallback value) → viewerNoExpiry
819: "ISSUED ON" (summary label) → viewerIssuedOnLabel
820: Helpers.formatDate(issuedAt) → (dynamic — formatted date)
884: "View QR code" → viewerViewQrCode
892: "Open a larger code to scan" → viewerOpenLargerQr
956: "Verification QR code" (sheet title) → viewerVerificationQrTitle
976: "Scan this code with a camera to check this document with the barangay. It is shown here only — nothing is shared or saved." → viewerScanQrDescription
1002: "Verification QR code" (semanticsLabel) → viewerVerificationQrTitle
1010: "This QR code could not be displayed." → viewerQrNotDisplayed
1025: "VERIFICATION LINK" (label) → viewerVerificationLinkLabel
1059: "Close" (button) → commonClose
1131: "View-only in this app: every view is watermarked and screen capture is blocked where supported. For paper or a file, request a watermarked, serial-numbered printable copy." → viewerFooterNote
1157: "A printable copy becomes available once your document ID is issued." → viewerPrintCopyNeedsId
1160: "A printable copy can be requested once this document is approved for release." → viewerPrintCopyNeedsApproval
1212: "Preparing your printable copy…" → viewerPreparingPrintCopy
1226: "Request printable copy" (button) → viewerRequestPrintCopy
1255: "${issued.displayLabel} — print or save again" → viewerPrintOrSaveAgain
1275: "Printing is not available here" → viewerPrintNotAvailableTitle
1276: "Printing and saving are available on mobile and desktop. Open this document in the barangay app on your phone or computer to get your printable copy." → viewerPrintNotAvailableMessage
1327: "Request a printable copy?" → viewerPrintCopyConfirmTitle
1339: "Your copy is regenerated from the official record the barangay holds — the same approved document, with its signature and QR code." → viewerPrintCopyConfirmBody
1352: "Watermarked with your name and stamped with a unique serial number, so every printed copy can be traced back to you." → viewerPrintCopyBulletWatermark
1358: "Printing and saving are allowed — you can print it or keep it as a PDF. Each document allows up to ${PrintCopyRules.maxCopiesPerDocument} printable copies in total." → viewerPrintCopyBulletLimit
1366: "Scanning the QR code on the copy checks this document's expiry, single-use and use limits — exactly like the original." → viewerPrintCopyBulletScan
1385: "Create my printable copy" (button) → viewerCreatePrintCopy
1396: "Cancel" (button) → commonCancel
1555: "Your printable copy is ready" → viewerPrintCopyReady
1564: "${widget.request.documentTypeDisplay} • ${copy.copyLabel}" → (dynamic — type display + copy label)
1595: "TRACEABLE, NUMBERED COPY" (label) → viewerTraceableNumberedCopy
1607: "Serial ${copy.serial} — recorded as ${copy.copyLabel} for $_viewerName. Scanning the QR code on this copy shows which copy was used, and this document's expiry and use limits still apply." → viewerSerialNotice
1648: "Preparing…" (button, busy) → viewerPreparingShort
1648: "Print" (button) → viewerPrint
1699: "Saving…" (button, busy) → viewerSaving
1699: "Save PDF" (button) → viewerSavePdf
1728: "Done" (button) → viewerDone
1761: "Print limit reached" → viewerPrintLimitTitle
1763: "This document already has its maximum of ${PrintCopyRules.maxCopiesPerDocument} printable copies. If you need another one, please visit or call the barangay office." → viewerPrintLimitMessage
1774: "Not available on this device" → viewerNotAvailableTitle
1776: "Printing and saving are available on mobile and desktop. Open this document in the barangay app on your phone or computer to get your printable copy." → viewerPrintNotAvailableMessage
1785: "We could not prepare the file" → viewerFilePrepareErrorTitle
1786: "The PDF could not be saved on this device. Please try again in a moment." → viewerFilePrepareErrorMessage
1794: "We could not create your printable copy" → viewerCreateCopyErrorTitle
1884: "Got it" (button) → viewerGotIt
```

---

## Notes

- `PrintCopyRules.maxCopiesPerDocument` appears inline inside two sentences; the values are
  excluded (dynamic) but the surrounding sentences are keyed with a `{count}` (num) placeholder:
  `viewerPrintCopyBulletLimit` and `viewerPrintLimitMessage`.
- `viewerPrintNotAvailableMessage` is reused for both the web guard (line 1276) and the
  device/unsupported error (line 1776) — identical source string.
- `viewerVerificationQrTitle` serves both the sheet heading (line 956) and the QR
  `semanticsLabel` (line 1002).
- `reqDocDocumentDetails` uses a `{document}` placeholder because the leading text is the
  dynamic official document title (`_selectedOption?.title`, fallback `'Document'`).
- `reqDocOccupation` and `reqDocAnnualIncome` are Philippine-native Filipino labels; all three
  locales keep the same text.
- `reqDocPaymentName`, `reqDocPaymentNumber`, `reqDocPaymentAmount` intentionally keep the
  three leading spaces from the source literals.
