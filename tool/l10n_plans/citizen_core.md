# Localization plan — citizen_core

Source files scanned (content-only; no Dart was edited):
- `lib/screens/citizen/dashboard_screen.dart`
- `lib/screens/citizen/my_requests_screen.dart`
- `lib/screens/citizen/my_reports_screen.dart`
- `lib/screens/citizen/notifications_screen.dart`

Legend: `→ keyName` = new key defined in `tool/l10n_parts/citizen_core.json`.
`→ common*` = reuse an existing key already defined in `lib/l10n/app_en.arb` (not redefined here).

Note: several labels are written with an embedded newline in the Dart source (e.g. `'Request\nDocument'`). For each, the mapped key stores the plain spaced form ("Request Document"); the UI keeps the line break when it renders.

## lib/screens/citizen/dashboard_screen.dart
- dashboard_screen.dart:134 — "Welcome back!" → citizenWelcomeBack
- dashboard_screen.dart:143 — "User" (fallback display name) → citizenFallbackName
- dashboard_screen.dart:205 — "Logout" (confirm dialog title) → commonLogout
- dashboard_screen.dart:206 — "Are you sure you want to logout?" → citizenLogoutConfirm
- dashboard_screen.dart:258 — "Quick Actions" → citizenQuickActions
- dashboard_screen.dart:278 — "Request\nDocument" (originally a line break between the two words) → citizenRequestDocument
- dashboard_screen.dart:293 — "My\nRequests" (originally a line break) → myRequestsTitle
- dashboard_screen.dart:312 — "Report\nIncident" (originally a line break) → citizenReportIncident
- dashboard_screen.dart:327 — "Verify\nDocument" (originally a line break) → citizenVerifyDocument
- dashboard_screen.dart:346 — "My\nReports" (originally a line break) → myReportsTitle
- dashboard_screen.dart:377 — "Your Requests" → citizenYourRequests
- dashboard_screen.dart:395 — "Total" → citizenStatTotal
- dashboard_screen.dart:410 — "Pending" → citizenStatPending
- dashboard_screen.dart:427 — "Approved" → citizenStatApproved
- dashboard_screen.dart:464 — "Recent Requests" → citizenRecentRequests
- dashboard_screen.dart:481 — "View All" → citizenViewAll
- dashboard_screen.dart:502 — "Loading your requests..." → citizenLoadingRequests
- dashboard_screen.dart:534 — "No requests yet" → citizenNoRequests
- dashboard_screen.dart:543 — "Create your first document request" → citizenCreateFirstRequest
- dashboard_screen.dart:638 — "Requested: ${Helpers.formatDate(request.requestedAt)}" → citizenRequestedLabel ({date} placeholder)

Excluded (not user-facing / from data): dashboard_screen.dart:116 `'U'` initials fallback, dashboard_screen.dart:184 unread-count number, dashboard_screen.dart:629 `documentTypeDisplay`, dashboard_screen.dart:663 `statusDisplay`, status-code switch cases at 821-866.

## lib/screens/citizen/my_requests_screen.dart
- my_requests_screen.dart:106 — "My Requests" → myRequestsTitle
- my_requests_screen.dart:114 — "Track your document requests" → myRequestsSubtitle
- my_requests_screen.dart:172 — "All" (filter chip) → citizenFilterAll
- my_requests_screen.dart:174 — "Pending" (filter chip) → citizenFilterPending
- my_requests_screen.dart:176 — "Payment" (filter chip) → citizenFilterPayment
- my_requests_screen.dart:178 — "Approved" (filter chip) → citizenFilterApproved
- my_requests_screen.dart:180 — "Rejected" (filter chip) → citizenFilterRejected
- my_requests_screen.dart:211 — "No ${_filter == 'all' ? 'requests' : _filter} found" → citizenNoRequestsFound (when `_filter == 'all'`) / citizenNoFilteredRequestsFound ({filter} placeholder = the localized filter chip label, when a specific filter is active)
- my_requests_screen.dart:220 — "Pull down to refresh" → citizenPullDownToRefresh
- my_requests_screen.dart:246 — "Showing your last saved requests." → citizenSavedRequestsHint
- my_requests_screen.dart:247 — "Showing saved requests from ${_formatCacheTime(savedAt)}." → citizenSavedRequestsFrom ({time} placeholder)
- my_requests_screen.dart:280 — "You're offline" (U+2019) → common* existing `offlineBanner`
- my_requests_screen.dart:315 — "yesterday at $time" → citizenYesterdayAt ({time} placeholder)
- my_requests_screen.dart:316 — "${DateFormat.MMMd().format(local)} at $time" → citizenDateAtTime ({date} and {time} placeholders)
- my_requests_screen.dart:392 — "Requested ${Helpers.formatDate(request.requestedAt)}" → citizenRequestedAt ({date} placeholder)
- my_requests_screen.dart:429 — "Purpose" → commonPurpose
- my_requests_screen.dart:484 — "View Document" → citizenViewDocument
- my_requests_screen.dart:523 — "Request Verified — Payment Required" → citizenPaymentRequiredTitle
- my_requests_screen.dart:534 — "Pay ₱${request.paymentAmount.toStringAsFixed(2)} to receive your document." → citizenPayAmountPrompt ({amount} placeholder, num)
- my_requests_screen.dart:544 — "Upload Payment Receipt" → citizenUploadPaymentReceipt
- my_requests_screen.dart:584 — "Payment receipt uploaded. Awaiting admin verification." → citizenPaymentAwaitingVerification
- my_requests_screen.dart:616 — "Your request is under review by our staff." → citizenRequestUnderReview

Excluded (from data): my_requests_screen.dart:384 `documentTypeDisplay`, :392 date value (only the literal prefix is keyed), :437 `request.purpose`, :461 `rejectionReason`, :411 `statusDisplay`, status switch cases 646-695.

## lib/screens/citizen/my_reports_screen.dart
- my_reports_screen.dart:125 — "My Incident Reports" → myIncidentReportsTitle
- my_reports_screen.dart:133 — "Track your submitted reports" → myReportsSubtitle
- my_reports_screen.dart:220 — "No incident reports yet" → citizenNoReports
- my_reports_screen.dart:230 — "Tap the button below to submit a report" → citizenNoReportsHint
- my_reports_screen.dart:399 — "Anonymous" (badge) → commonAnonymous
- my_reports_screen.dart:401 — "Sensitive" (badge) → commonSensitive
- my_reports_screen.dart:426 — "Showing your last saved reports." → citizenSavedReportsHint
- my_reports_screen.dart:427 — "Showing saved reports from ${_formatCacheTime(savedAt)}." → citizenSavedReportsFrom ({time} placeholder)
- my_reports_screen.dart:460 — "You're offline" (U+2019) → common* existing `offlineBanner`
- my_reports_screen.dart:495 — "yesterday at $time" → citizenYesterdayAt ({time} placeholder)
- my_reports_screen.dart:496 — "${DateFormat.MMMd().format(local)} at $time" → citizenDateAtTime ({date} and {time} placeholders)
- my_reports_screen.dart:525 — "Couldn't load your reports" (U+2019 in source) → citizenLoadReportsError
- my_reports_screen.dart:534 — "Your reports didn't load. Check your connection and try again." (U+2019 in source) → citizenLoadReportsErrorMessage
- my_reports_screen.dart:546 — "Retry" → commonRetry

Excluded (from data): my_reports_screen.dart:293 `report.title`, :303 `reportType`, :324 `priority`, :349 `status`, :373 `location`, :378 formatted datetime, :383 `description`, status/priority switch cases 29-79.

## lib/screens/citizen/notifications_screen.dart
- notifications_screen.dart:130 — "Notifications" → notificationsTitle
- notifications_screen.dart:138 — "Stay updated on your requests" → notificationsSubtitle
- notifications_screen.dart:159 — "Mark all read" → notificationsMarkAllRead
- notifications_screen.dart:209 — "Couldn't load notifications" (U+2019 in source) → notificationsLoadError
- notifications_screen.dart:218 — "Your notifications didn't load. Check your connection and try again." (U+2019 in source) → notificationsLoadErrorMessage
- notifications_screen.dart:233 — "Retry" → commonRetry
- notifications_screen.dart:275 — "No notifications yet" → notificationsEmpty
- notifications_screen.dart:284 — "Notifications will appear here when you have activity" → notificationsEmptyHint
- notifications_screen.dart:309 — "New" (section header) → notificationsSectionNew
- notifications_screen.dart:317 — "Earlier" (section header) → notificationsSectionEarlier

Excluded (from data): notifications_screen.dart:355 unread count number, :419 `notification.title`, :444 `notification.message`, :455 formatted datetime, type switch cases 42-86.

## Reused existing keys (defined in lib/l10n/app_en.arb, not redefined in citizen_core.json)
commonLogout, commonPurpose, commonAnonymous, commonSensitive, commonRetry, offlineBanner
