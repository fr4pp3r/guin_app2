# Localization plan — admin_workflow

Source files scanned (content-only; no Dart was edited):
- `lib/screens/admin/dashboard_screen.dart`
- `lib/screens/admin/pending_requests_screen.dart`
- `lib/screens/admin/pending_payments_screen.dart`
- `lib/screens/admin/all_requests_screen.dart`
- `lib/screens/admin/captain_approval_screen.dart`
- `lib/screens/admin/incident_reports_screen.dart`

Legend: `→ keyName` = new key defined in `tool/l10n_parts/admin_workflow.json`.
`→ common*` = reuse an existing key already defined in `lib/l10n/app_en.arb` (not redefined here).

Notes:
- Status-chip/filter values in `all_requests_screen.dart` (`all`, `pending_payment`, `pending_review`, `approved`, `rejected`) and the popup-menu values in `incident_reports_screen.dart` (`received`, `under_assessment`, `endorsed`, `in_progress`, `resolved`, `closed`) are DB identifiers used as widget values — they MUST stay unchanged. Only the displayed `Text(...)` is swapped for `l10n.key`; the value string passed to the filter/menu stays byte-identical.
- `Helpers.parseSupabaseError(e.toString())` / `'Error: $e'` snackbars are keyed per file as `{error}` placeholders; the call site passes the parsed error text.
- Em dashes (—) and ₱ are reproduced as visible. No curly apostrophes exist in these files.

## lib/screens/admin/dashboard_screen.dart
- dashboard_screen.dart:76 — "Error loading statistics: $e" → adashLoadStatsError ({error} placeholder)
- dashboard_screen.dart:100 — "${AppRoles.displayName(...)} Dashboard" → adashTitle ({role} placeholder; role value from `AppRoles.displayName`, e.g. roleCaptain/roleAdmin labels)
- dashboard_screen.dart:116 — "Logout" (AppBar tooltip) → commonLogout
- dashboard_screen.dart:128 — "Confirm Logout" (dialog title) → adashConfirmLogoutTitle
- dashboard_screen.dart:131 — "Are you sure you want to logout?" → adashConfirmLogoutMessage
- dashboard_screen.dart:135 — "Cancel" → commonCancel
- dashboard_screen.dart:145 — "Logout" (dialog button) → commonLogout
- dashboard_screen.dart:208 — "Welcome Back!" → adashWelcomeBack
- dashboard_screen.dart:217 — "Admin" (fallback display name) → adashFallbackAdmin
- dashboard_screen.dart:252 — "User Management" → adashUserManagement
- dashboard_screen.dart:266 — "Pending Users" → adashStatPendingUsers
- dashboard_screen.dart:277 — "Total Users" → adashStatTotalUsers
- dashboard_screen.dart:305 — "Document Requests" → adashDocumentRequests
- dashboard_screen.dart:323 — "Pending Payments" → adashStatPendingPayments
- dashboard_screen.dart:338 — "Pending Reviews" → adashStatPendingReviews
- dashboard_screen.dart:354 — "Approved" (stat card) → adashStatApproved
- dashboard_screen.dart:364 — "Rejected" (stat card) → adashStatRejected
- dashboard_screen.dart:393 — "Quick Actions" → adashQuickActions
- dashboard_screen.dart:407 — "View All Requests" → adashViewAllRequests
- dashboard_screen.dart:415 — "Manage Users" → adashManageUsers
- dashboard_screen.dart:423 — "Barangay Settings" → adashBarangaySettings ("Barangay" kept)
- dashboard_screen.dart:429 — "Manage Document Fees" → adashManageDocumentFees
- dashboard_screen.dart:435 — "View Document Formats" → adashViewDocumentFormats
- dashboard_screen.dart:444 — "Captain Approval Queue" → adashCaptainApprovalQueue ("Captain Approval" kept)
- dashboard_screen.dart:453 — "Incident Reports" → adashIncidentReports
- dashboard_screen.dart:461 — "Verify Document" → adashVerifyDocument

Excluded: stat counts (`_userStats?[...]`, `_documentStats?[...]`), `userProfile?.fullName`, `AppRoles.displayName(...)` role value, route names in `pushNamed`, `AppRoutes.*`, exceptions, gradient/color constants.

## lib/screens/admin/pending_requests_screen.dart
- pending_requests_screen.dart:42 — "PDF generation is not available on web. Use mobile or desktop." → asecPdfWebUnavailable
- pending_requests_screen.dart:49 — "Generate Draft" (confirm title) → asecGenerateDraft
- pending_requests_screen.dart:51-52 — "Generate a DRAFT ${request.documentTypeDisplay} for review?\n\nThe draft will be marked \"NOT VALID FOR OFFICIAL USE\"." → asecGenerateDraftMessage ({document} placeholder)
- pending_requests_screen.dart:60 — "Generating draft..." → asecGeneratingDraft
- pending_requests_screen.dart:203 — "Draft generated successfully" → asecDraftGeneratedSuccess
- pending_requests_screen.dart:209 — "Error: ${Helpers.parseSupabaseError(...)}" → asecErrorFormatted ({error} placeholder)
- pending_requests_screen.dart:221 — "Request Revision" (dialog title) → asecRequestRevision
- pending_requests_screen.dart:225 — "Request changes to this ${request.documentTypeDisplay}" → asecRequestChangesToDocument ({document} placeholder)
- pending_requests_screen.dart:231 — "Revision notes for citizen" (label) → asecRevisionNotesForCitizen
- pending_requests_screen.dart:232 — "Describe what needs to be changed..." (hint) → asecRevisionNotesHint
- pending_requests_screen.dart:243 — "Cancel" → commonCancel
- pending_requests_screen.dart:248 — "Please provide notes" → asecPleaseProvideNotes
- pending_requests_screen.dart:254 — "Send Revision" → asecSendRevision
- pending_requests_screen.dart:263 — "Requesting revision..." → asecRequestingRevision
- pending_requests_screen.dart:274 — "Revision requested — citizen notified" → asecRevisionRequestedNotified
- pending_requests_screen.dart:291 — "Verify & Forward" (dialog title) → asecVerifyForwardTitle
- pending_requests_screen.dart:293 — "Mark as verified. An invoice will be created and the citizen will be notified to pay ₱${request.paymentAmount.toStringAsFixed(2)}." → asecVerifyPaidMessage ({amount} placeholder, num)
- pending_requests_screen.dart:294 — "No payment required. This will go directly to the Captain for final approval." → asecVerifyNoPaymentMessage
- pending_requests_screen.dart:300 — "Processing..." → asecProcessing
- pending_requests_screen.dart:312 — "Invoice sent to citizen" → asecInvoiceSent
- pending_requests_screen.dart:313 — "Forwarded to Captain for approval" → asecForwardedToCaptain
- pending_requests_screen.dart:332 — "Reject Request" (dialog title) → asecRejectRequestTitle
- pending_requests_screen.dart:336 — "Rejecting: ${request.documentTypeDisplay}" → asecRejectingDocument ({document} placeholder)
- pending_requests_screen.dart:342 — "Rejection Reason" (label) → commonRejectionReason
- pending_requests_screen.dart:343 — "Provide a reason for rejection..." (hint) → asecProvideRejectionReasonHint (differs from commonProvideReason)
- pending_requests_screen.dart:351 — "Cancel" → commonCancel
- pending_requests_screen.dart:356 — "Please provide a reason" → commonPleaseProvideReason
- pending_requests_screen.dart:362 — "Reject" → commonReject
- pending_requests_screen.dart:371 — "Rejecting..." → asecRejecting
- pending_requests_screen.dart:380 — "Request rejected" → asecRequestRejected
- pending_requests_screen.dart:436 — "Secretary — Review Requests" (header; "Secretary" kept) → asecHeaderTitle
- pending_requests_screen.dart:444 — "Generate drafts, request revisions, verify for payment" → asecHeaderSubtitle
- pending_requests_screen.dart:484 — "No pending requests" → asecNoPendingRequests
- pending_requests_screen.dart:583 — "Requested ${Helpers.formatDate(r.requestedAt)}" → asecRequestedAt ({date} placeholder)
- pending_requests_screen.dart:640 — "Purpose" (label) → commonPurpose
- pending_requests_screen.dart:672 — "Revision Notes" (label) → asecRevisionNotes
- pending_requests_screen.dart:698 — "Reject" (card button) → commonReject
- pending_requests_screen.dart:722 — "Generate Draft" (card button) → asecGenerateDraft
- pending_requests_screen.dart:745 — "Needs Revision" (card button) → asecNeedsRevision
- pending_requests_screen.dart:765 — "Send Invoice" (card button) → asecSendInvoice
- pending_requests_screen.dart:766 — "Forward to Captain" (card button) → asecForwardToCaptain
- pending_requests_screen.dart:799 — "Waiting for citizen to resubmit" → asecWaitingForResubmit

Excluded: `request.documentTypeDisplay`, `r.statusDisplay`, `Helpers.formatDate(...)` value, `r.userFullName`/`r.userName`, `r.purpose` value, `r.secretaryNotes` value, thrown exceptions (lines 66, 71, 191), `documentType` switch cases 74-192, `_getDocumentIcon` switch 817-840.

## lib/screens/admin/pending_payments_screen.dart
- pending_payments_screen.dart:31 — "Confirm Payment" (dialog title) → atreasConfirmPayment
- pending_payments_screen.dart:33-34 — "Confirm this payment of ₱${request.paymentAmount.toStringAsFixed(2)}?\n\nThe request will be forwarded to the Captain for final approval." → atreasConfirmPaymentMessage ({amount} placeholder, num)
- pending_payments_screen.dart:39 — "Confirming payment..." → atreasConfirmingPayment
- pending_payments_screen.dart:50 — "Payment confirmed — forwarded to Captain for approval" → atreasPaymentConfirmedForwarded
- pending_payments_screen.dart:57 — "Error: ${Helpers.parseSupabaseError(...)}" → atreasErrorFormatted ({error} placeholder)
- pending_payments_screen.dart:71 — "Reject Payment" (dialog title) → atreasRejectPayment
- pending_payments_screen.dart:75 — "Please provide a reason for rejection:" → atreasRejectPaymentPrompt
- pending_payments_screen.dart:82 — "Enter reason..." (hint) → atreasEnterReasonHint
- pending_payments_screen.dart:90 — "Cancel" → commonCancel
- pending_payments_screen.dart:95 — "Please provide a reason" → commonPleaseProvideReason
- pending_payments_screen.dart:101 — "Reject" → commonReject
- pending_payments_screen.dart:112 — "Rejecting payment..." → atreasRejectingPayment
- pending_payments_screen.dart:125 — "Payment rejected — citizen notified" → atreasPaymentRejectedNotified
- pending_payments_screen.dart:148 — "Encode Cash Payment" (dialog title) → atreasEncodeCashPayment
- pending_payments_screen.dart:152 — "Amount: ₱${request.paymentAmount.toStringAsFixed(2)}" → atreasAmountLabel ({amount} placeholder, num)
- pending_payments_screen.dart:156 — "Payment Method" (label) → atreasPaymentMethod
- pending_payments_screen.dart:160 — "Cash On-Site" (dropdown item) → atreasCashOnSite
- pending_payments_screen.dart:164 — "Manual Cashier" (dropdown item) → atreasManualCashier
- pending_payments_screen.dart:173 — "Reference / OR Number (optional)" (label; "OR" kept) → atreasReferenceOrLabel
- pending_payments_screen.dart:174 — "e.g. OR-2025-001" (hint) → atreasReferenceExample
- pending_payments_screen.dart:181 — "Cancel" → commonCancel
- pending_payments_screen.dart:186 — "Confirm Payment" (dialog button) → atreasConfirmPayment
- pending_payments_screen.dart:212 — "Cash payment encoded & verified" → atreasCashEncodedVerified
- pending_payments_screen.dart:221 — "Error: $e" → atreasErrorFormatted ({error} placeholder)
- pending_payments_screen.dart:235 — "Payment Receipt" (dialog title) → atreasPaymentReceipt
- pending_payments_screen.dart:303 — "Treasurer — Payment Verification" (header; "Treasurer" kept) → atreasHeaderTitle
- pending_payments_screen.dart:311 — "Verify invoices and confirm/reject payments" → atreasHeaderSubtitle
- pending_payments_screen.dart:356 — "No pending payments" → atreasNoPendingPayments
- pending_payments_screen.dart:440 — "Unknown user" (userName fallback) → atreasUnknownUser
- pending_payments_screen.dart:480 — "Purpose" (info row label) → commonPurpose
- pending_payments_screen.dart:486 — "Amount" (info row label) → commonAmount
- pending_payments_screen.dart:493 — "Requested" (info row label) → commonRequested
- pending_payments_screen.dart:566 — "View" (receipt overlay) → commonView
- pending_payments_screen.dart:602 — "Encode Cash / Manual Payment" (card button) → atreasEncodeCashManualPayment
- pending_payments_screen.dart:638 — "Reject" (card button) → commonReject
- pending_payments_screen.dart:665 — "Verify GCash" (card button; "GCash" kept) → atreasVerifyGCash

Excluded: `request.documentTypeDisplay`, `request.statusDisplay`, `request.userName` value, `request.purpose`, `request.paymentReceiptUrl`, `_formatDate(...)` value, `'$label: '` structural formatting in `_infoRow`, `selectedMethod` DB values (`cash_onsite`, `manual_cashier`), exceptions.

## lib/screens/admin/all_requests_screen.dart
- all_requests_screen.dart:109 — "All Requests" → areqTitle
- all_requests_screen.dart:117 — "Search and filter document requests" → areqSubtitle
- all_requests_screen.dart:141 — "Search by document type or status..." (hint) → areqSearchHint
- all_requests_screen.dart:162 — "All" (filter chip; value `'all'` unchanged) → areqFilterAll
- all_requests_screen.dart:165 — "Pending Payment" (filter chip; value `'pending_payment'` unchanged) → areqFilterPendingPayment
- all_requests_screen.dart:169 — "Pending Review" (filter chip; value `'pending_review'` unchanged) → areqFilterPendingReview
- all_requests_screen.dart:171 — "Approved" (filter chip; value `'approved'` unchanged) → areqFilterApproved
- all_requests_screen.dart:173 — "Rejected" (filter chip; value `'rejected'` unchanged) → areqFilterRejected
- all_requests_screen.dart:207 — "No requests found" (search active) → areqNoRequestsFound
- all_requests_screen.dart:208 — "No requests yet" → areqNoRequestsYet
- all_requests_screen.dart:311 — "ID: ${request.id.substring(0, 8)}..." → areqIdPrefix ({id} placeholder; "ID" kept)
- all_requests_screen.dart:358 — "Delete" (popup menu) → commonDelete
- all_requests_screen.dart:373 — "More actions" (tooltip) → areqMoreActions
- all_requests_screen.dart:391 — "Requested: ${Helpers.formatDate(request.requestedAt)}" → areqRequestedAt ({date} placeholder)
- all_requests_screen.dart:419 — "View Document" (card button) → areqViewDocument
- all_requests_screen.dart:482 — "Status" (detail row label) → commonStatus
- all_requests_screen.dart:485 — "Request ID" (detail row label) → areqRequestID
- all_requests_screen.dart:487 — "Requested At" (detail row label) → areqRequestedAtLabel
- all_requests_screen.dart:491 — "Amount" (detail row label) → commonAmount
- all_requests_screen.dart:495 — "Purpose" (detail row label) → commonPurpose
- all_requests_screen.dart:498 — "Rejection Reason" (detail row label) → commonRejectionReason
- all_requests_screen.dart:512 — "View Document" (bottom-sheet button) → areqViewDocument
- all_requests_screen.dart:552 — "Delete Document" (dialog title) → areqDeleteDocument
- all_requests_screen.dart:557 — "Deleting: ${_formatDocumentType(request.documentType)}" → areqDeletingDocument ({document} placeholder)
- all_requests_screen.dart:560-562 — "This permanently removes the request, all drafts, final PDF, payment receipts, verification records, and print copies." → areqDeleteWarning
- all_requests_screen.dart:570 — "Reason for deletion" (label) → areqReasonForDeletion (differs from commonRejectionReason)
- all_requests_screen.dart:571 — "Provide a reason..." (hint) → commonProvideReason
- all_requests_screen.dart:581 — "Cancel" → commonCancel
- all_requests_screen.dart:587 — "Delete" (dialog button) → commonDelete
- all_requests_screen.dart:598 — "Deleting..." (loading dialog) → areqDeleting
- all_requests_screen.dart:606 — "Document deleted" → areqDocumentDeleted

Excluded: `_formatStatus(request.requestStatus)` output (status-code formatting 670-675), `_formatDocumentType`/`AutomationConstants.labelFor` (677-679), `request.documentType`, `request.id` value, ₱ amount values, `Helpers.formatDate(...)` values, `request.purpose`, `request.rejectionReason`, filter `_selectedFilter` DB values, `requestStatus` comparisons, exceptions.

## lib/screens/admin/captain_approval_screen.dart
- captain_approval_screen.dart:42 — "PDF generation is not available on web. Use mobile or desktop." → acapPdfWebUnavailable
- captain_approval_screen.dart:51 — "Release policy: ${_describePolicy(policy)}" (policyLine constant) → acapReleasePolicyLine ({policy} placeholder; policy value composed from acapPolicy*/acapValidity* keys below)
- captain_approval_screen.dart:60 — "Kagawad Approval" (dialog title; "Kagawad" kept) → acapKagawadApproval
- captain_approval_screen.dart:62-65 — "You are approving as Kagawad Representative.\n\nThis action is only allowed when the Captain is unavailable. This will be logged.\n\n$policyLine\n\nContinue?" → acapKagawadApprovalMessage ({policyLine} placeholder)
- captain_approval_screen.dart:71 — "Approve & Sign" (dialog title) → acapApproveAndSign
- captain_approval_screen.dart:73-76 — "Approve this ${request.documentTypeDisplay}?\n\nYour digital signature will be applied and a final document with QR verification will be released to the citizen.\n\n$policyLine" → acapApproveAndSignMessage ({document} and {policyLine} placeholders; "QR" kept)
- captain_approval_screen.dart:85 — "Generating final document..." → acapGeneratingFinalDocument
- captain_approval_screen.dart:282 — "Document approved, signed & released with QR verification!" → acapApprovedSignedReleased
- captain_approval_screen.dart:289 — "Error: ${Helpers.parseSupabaseError(...)}" → acapErrorFormatted ({error} placeholder)
- captain_approval_screen.dart:312 — "Reject Document" (dialog title) → acapRejectDocument
- captain_approval_screen.dart:316 — "Rejecting: ${request.documentTypeDisplay}" → acapRejectingDocument ({document} placeholder)
- captain_approval_screen.dart:322 — "Reason for rejection" (label) → acapReasonForRejection (differs from commonRejectionReason)
- captain_approval_screen.dart:323 — "Provide a reason..." (hint) → commonProvideReason
- captain_approval_screen.dart:336 — "Please provide a reason" → commonPleaseProvideReason
- captain_approval_screen.dart:342 — "Reject" → commonReject
- captain_approval_screen.dart:351 — "Rejecting..." → acapRejecting
- captain_approval_screen.dart:361 — "Request rejected" → acapRequestRejected
- captain_approval_screen.dart:420 — "$roleLabel — Final Approval" (header) → acapTitle ({role} placeholder; role value from `AppRoles.displayName`)
- captain_approval_screen.dart:428 — "Sign and release documents to citizens" → acapSubtitle
- captain_approval_screen.dart:468 — "No documents awaiting approval" → acapNoDocumentsAwaiting
- captain_approval_screen.dart:547 — "Requested ${Helpers.formatDate(r.requestedAt)}" → acapRequestedAt ({date} placeholder)
- captain_approval_screen.dart:566 — "For Approval" (status chip) → acapForApproval
- captain_approval_screen.dart:604 — "Purpose" (label) → commonPurpose
- captain_approval_screen.dart:632 — "Payment: ₱${r.paymentAmount.toStringAsFixed(2)} — ${r.paymentStatus}" → acapPaymentLine ({amount} num and {status} String placeholders)
- captain_approval_screen.dart:650 — "Reject" (card button) → commonReject
- captain_approval_screen.dart:671 — "Sign & Release" (card button) → acapSignAndRelease

### _ReleasePolicySheet (captain_approval_screen.dart:718-1192)
- captain_approval_screen.dart:754 — "No expiry" (policy description) → acapPolicyNoExpiry
- captain_approval_screen.dart:755 — "Valid for ${p.validFor?.inDays ?? 30} days" → acapPolicyValidForDays ({days} placeholder, num, ICU plural)
- captain_approval_screen.dart:757 — "Single-use" (policy description) → acapPolicySingleUse
- captain_approval_screen.dart:759 — "Multi-use (unlimited)" → acapPolicyMultiUseUnlimited
- captain_approval_screen.dart:760 — "Multi-use (max ${p.maxUses} uses)" → acapPolicyMultiUseMax ({count} placeholder, num, ICU plural)
- captain_approval_screen.dart:779 — "7 days" (validity segment) → acapValidityDays (count 7, ICU plural)
- captain_approval_screen.dart:780 — "30 days" (validity segment) → acapValidityDays (count 30, ICU plural)
- captain_approval_screen.dart:781 — "90 days" (validity segment) → acapValidityDays (count 90, ICU plural)
- captain_approval_screen.dart:782 — "1 year (365 days)" (validity segment) → acapValidityOneYear
- captain_approval_screen.dart:783 — "No expiry" (validity segment) → acapPolicyNoExpiry (same key as the description form)
- captain_approval_screen.dart:852 — "Enter a whole number of 1 or more, or leave blank" (max-uses error) → acapMaxUsesError
- captain_approval_screen.dart:869 — "Enter a positive whole number" (custom-days error) → acapCustomDaysError
- captain_approval_screen.dart:985 — "Release Policy" (sheet title) → acapReleasePolicyTitle
- captain_approval_screen.dart:993 — "Set how the citizen can use this document." → acapReleasePolicySubtitle
- captain_approval_screen.dart:1007 — "VALIDITY" (section label, uppercase style) → acapValiditySection
- captain_approval_screen.dart:1056 — "Single-use" (toggle title) → acapPolicySingleUse
- captain_approval_screen.dart:1064 — "Only one claim allowed — no repeat uses." (toggle help) → acapSingleUseHelp
- captain_approval_screen.dart:1090 — "CUSTOM DAYS" (section label, uppercase style) → acapCustomDaysSection
- captain_approval_screen.dart:1098 — "Custom days" (field label) → acapCustomDaysLabel
- captain_approval_screen.dart:1099 — "Enter number of days" (hint) → acapCustomDaysHint
- captain_approval_screen.dart:1100 — "Positive whole number of days" (helper text) → acapCustomDaysHelper
- captain_approval_screen.dart:1131 — live preview `_describePolicy(_previewPolicy())` → composed from acapPolicyNoExpiry / acapPolicyValidForDays / acapPolicySingleUse / acapPolicyMultiUseUnlimited / acapPolicyMultiUseMax (joined with "•")
- captain_approval_screen.dart:1160 — "Cancel" → commonCancel
- captain_approval_screen.dart:1170 — "Confirm Policy" (button) → acapConfirmPolicy

Excluded: `AppRoles.displayName(...)` roleLabel, `request.documentTypeDisplay`, `Helpers.formatDate(...)` values, `r.userFullName`/`r.userName`, `r.purpose`, `r.paymentStatus`, ₱ amount values, thrown exceptions, `documentType` switch cases 117-263, `_docIcon` switch 694-715, `_validityOptions` int values (7/30/90/365/null) which stay numeric.

## lib/screens/admin/incident_reports_screen.dart
- incident_reports_screen.dart:135 — "Incident Reports" → aincTitle
- incident_reports_screen.dart:143 — "All citizen-submitted reports" → aincSubtitle
- incident_reports_screen.dart:188 — "No incident reports yet" → aincNoReports
- incident_reports_screen.dart:335 — "Mark Received" (menu item; value `'received'` unchanged) → aincMarkReceived
- incident_reports_screen.dart:339 — "Under Assessment" (menu item; value `'under_assessment'` unchanged) → aincUnderAssessment
- incident_reports_screen.dart:343 — "Endorse / Escalate" (menu item; value `'endorsed'` unchanged) → aincEndorseEscalate
- incident_reports_screen.dart:347 — "In Progress" (menu item; value `'in_progress'` unchanged) → aincInProgress
- incident_reports_screen.dart:351 — "Resolve" (menu item; value `'resolved'` unchanged) → aincResolve
- incident_reports_screen.dart:355 — "Close" (menu item; value `'closed'` unchanged) → aincClose
- incident_reports_screen.dart:392 — "Anonymous" (badge) → commonAnonymous
- incident_reports_screen.dart:394 — "Sensitive" (badge) → commonSensitive

Excluded: `report.title`, `reportType` (uppercased replaceAll output), `report.priority`, status chip text `report.status.replaceAll('_', ' ')` (DB value, line 316), `report.location`, `Helpers.formatDateTime(report.createdAt)`, `report.description`, remarks DB literal "Updated from mobile dashboard" (line 32 — written to DB, not displayed), `_statusColor`/`_priorityColor`/`_statusIcon` switch cases.

## Reused existing keys (defined in lib/l10n/app_en.arb, not redefined in admin_workflow.json)
commonCancel, commonReject, commonDelete, commonView, commonLogout, commonConfirm, commonPurpose, commonAmount, commonStatus, commonRejectionReason, commonProvideReason, commonPleaseProvideReason, commonAnonymous, commonSensitive, commonRequested