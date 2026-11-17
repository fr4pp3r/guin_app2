# Notification Deep-Linking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a notification opens the exact request/report/announcement/pending user it refers to, preserving role-appropriate actions.

**Architecture:** Add nullable `reference_type`/`reference_id` to notifications and thread them from every emitter that has an entity in hand. A pure resolver maps (reference + role) to a destination; the tap handler fetches the entity and pushes the detail screen. Officials are routed to their queue screen with a focus id so the screen reuses its own action handlers.

**Tech Stack:** Flutter/Dart, Supabase Flutter (PostgREST + realtime), plain `flutter test`.

**Spec:** `docs/superpowers/specs/2026-11-17-notification-deeplink-and-email-otp-design.md` (Part 1)

## Global Constraints

- `flutter analyze` must produce **zero errors** (~56 pre-existing `info` lints tolerated; do not add new ones).
- `flutter test` must stay green. Verify order: `flutter analyze` → `flutter test`.
- No new dependencies.
- Do **not** change `notification_type` enum values or Supabase Auth/RLS (`USING (true)` everywhere).
- New user-facing copy goes in `lib/l10n/app_en.arb`, `app_ceb.arb`, `app_fil.arb` + `flutter gen-l10n`; never hardcode strings in screens.
- `setup.sql` is the schema source of truth; migrations are additive and mirrored in it.
- Reference type values are the literals `'document_request'`, `'incident_report'`, `'announcement'`, `'user_registration'`.
- Best-effort notification paths never throw or block the triggering action.

## Review Focus

- **Legacy notification with NULL reference** → route by `type` to the old list screen, never crash; pinned in Task 3 resolver test.
- **Reference id present but entity deleted / not in loaded list** → fall back to list screen + "no longer available" snackbar, no dead end; pinned in Task 5.
- **`payment_verified` sent to a treasurer (queue notice) vs a citizen (receipt)** → role disambiguates: treasurer → `pendingPayments`, citizen → document viewer; pinned in Task 3 resolver test.
- **`user_registration` notice to a signed-out/pending citizen** → mark read, no navigation; pinned in Task 3 resolver test.
- **Official detail needs `List<RequestAction>`** → never build actions in the resolver; route to queue screen with focus id so its existing `_actionsFor` runs; checked in Task 5 review.

---

### Task 1: Schema migration + model fields

**Files:**
- Create: `supabase/migrations/20261117_notification_references.sql`
- Modify: `setup.sql:401-409`
- Modify: `lib/models/notification.dart:1-63`

**Interfaces:**
- Produces: `AppNotification.referenceType` (`String?`), `AppNotification.referenceId` (`String?`), parsed in `fromJson`, emitted in `toJson`, accepted in `copyWith`.

- [ ] **Step 1: Write the migration**

```sql
-- Additive: exact-item deep-link references for notifications.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS reference_type TEXT,
  ADD COLUMN IF NOT EXISTS reference_id TEXT;
```

- [ ] **Step 2: Mirror in `setup.sql`**

Add the same two columns to the `notifications` CREATE TABLE (after `type`, before `is_read`):
`reference_type TEXT,` and `reference_id TEXT,`.

- [ ] **Step 3: Extend the model**

Add the two nullable fields to `AppNotification`, wire them through the constructor, `fromJson` (keys `reference_type` / `reference_id`, use `as String?`), `toJson`, and `copyWith`. Leave `typeIcon`/`typeColor` untouched (separate pre-existing mismatch, out of scope).

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261117_notification_references.sql setup.sql lib/models/notification.dart
git commit -m "feat(notifications): add reference columns to notifications and model"
```

---

### Task 2: Thread references through notification services and emitters

**Files:**
- Modify: `lib/services/notification_service.dart:140-175, 212-327`
- Modify (emitters): `lib/providers/auth_provider.dart`, `lib/providers/document_provider.dart`, `lib/providers/incident_report_provider.dart`, `lib/providers/announcement_provider.dart`, `lib/services/user_service.dart`, `lib/services/document_automation_service.dart`

**Interfaces:**
- Consumes: `AppNotification.referenceType/Id` (Task 1).
- Produces: `NotificationService.createNotification`, `notifyRoles`, `notifyAllApproved`, `_insertNotificationsBatched`, `_schedulePush` all accept optional named `String? referenceType, String? referenceId` and persist/forward them.
- Produces: a constants holder (e.g. `lib/utils/notification_refs.dart`) exposing `documentRequest`, `incidentReport`, `announcement`, `userRegistration` string constants.

- [ ] **Step 1: Add optional params to the service**

Add `String? referenceType, String? referenceId` to all five methods above. In `createNotification` and `_insertNotificationsBatched`, add the two keys to the inserted map only when non-null (avoid writing explicit NULL everywhere). Forward them through `notifyRoles` → `createNotification`, `notifyAllApproved` → `_insertNotificationsBatched`, its fallback → `createNotification`, and `_schedulePush` → the push invoke body. Push consumers ignore unknown body keys, so forwarding is safe.

- [ ] **Step 2: Add reference constants file**

Create `lib/utils/notification_refs.dart` with a class of the four `static const String` values.

- [ ] **Step 3: Update emitters**

For every call that has an entity at hand, pass the matching constant + id:
- document request notices → `documentRequest`, the request's `id` (both `document_automation_service.dart` and `document_provider.dart` request-shaped sites).
- `incident_submitted` → `incidentReport`, report id.
- "New announcement" → `announcement`, announcement id.
- "New registration to review" / registration decisions → `userRegistration`, user id.
- Bare queue notices with no single entity (e.g. generic "New document request" to officials where only a count is known) → pass the request id if available, otherwise leave null.

Grep after editing: `grep -rn "createNotification(" lib` and `grep -rn "notifyRoles(\|notifyAllApproved(" lib` — every site either passes a reference or is a deliberate no-entity notice.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add lib/services/notification_service.dart lib/utils/notification_refs.dart lib/providers lib/services/user_service.dart lib/services/document_automation_service.dart
git commit -m "feat(notifications): emit exact-item references from all notification sources"
```

---

### Task 3: Pure resolver + offline tests

**Files:**
- Create: `lib/utils/notification_destination.dart`
- Create: `test/utils/notification_destination_test.dart`

**Interfaces:**
- Consumes: `AppNotification`, `AppRoles`.
- Produces: `enum NotificationDestination { documentViewer, pendingRequests, pendingPayments, captainApproval, incidentReports, announcements, pendingUsers, myRequests, myReports, none }` with a `String? get routeName` getter mapping each non-`none` value to its `AppRoutes` constant; and `NotificationDestination resolveDestination(AppNotification notification, String role)`.

- [ ] **Step 1: Write failing tests**

`test/utils/notification_destination_test.dart` — construct `AppNotification` with fixed fields via a helper `n(type, refType, refId)`. Cover:
- citizen + `document_request` → `documentViewer`
- secretary + `document_request` type `system` "New document request" → `pendingRequests`
- treasurer + `document_request` type `payment_verified` → `pendingPayments`
- citizen + `document_request` type `payment_verified` → `documentViewer`
- captain + `document_request` + `request_approved` → `captainApproval`
- tanod + `incident_report` → `incidentReports`
- any role + `announcement` → `announcements`
- captain + `user_registration` → `pendingUsers`
- citizen + `user_registration` → `none`
- any refType null + `request_*`/`payment_*`/`system` → `myRequests`; + `incident_*` → `myReports`; + `registration_*` → `none`

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/utils/notification_destination_test.dart`
Expected: FAIL (file/function missing).

- [ ] **Step 3: Implement the resolver**

Pure function, no context, no I/O. Use `AppRoles.isOfficial(role)` and the reference type; for officials with `document_request`, use notification `type` + message substring as the queue discriminator: `payment_verified`/message contains "Payment"/"payment" → `pendingPayments`; `request_approved`/message contains "approval"/"approval" → `captainApproval`; else `pendingRequests`. For null reference, use `type` prefix fallback. Return `none` for citizen registration notices.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/utils/notification_destination_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/notification_destination.dart test/utils/notification_destination_test.dart
git commit -m "feat(notifications): add pure deep-link destination resolver with tests"
```

---

### Task 4: Named routes and focus arguments on queue screens

**Files:**
- Modify: `lib/config/routes.dart:36-250`
- Modify: `lib/screens/admin/pending_requests_screen.dart`, `lib/screens/admin/pending_payments_screen.dart`, `lib/screens/admin/captain_approval_screen.dart`, `lib/screens/admin/incident_reports_screen.dart`, `lib/screens/announcements/announcements_screen.dart`, `lib/screens/admin/manage_users_screen.dart`, `lib/screens/citizen/document_viewer_screen.dart`

**Interfaces:**
- Consumes: destination enum (Task 3).
- Produces: new `AppRoutes` constants `documentViewer` and `announcements`; each queue screen accepts one optional `final String? focusId` constructor field and opens the focused detail once after its existing load, using its existing open-detail method and `_actionsFor`.

- [ ] **Step 1: Add routes and typed arguments**

Add the two constants and route entries. `documentViewer` takes a `DocumentRequest` argument (like `eReceipt`). `announcements` takes no argument. Extend `onGenerateRoute` with cases for the new routes, following the `citizenIncidentDetail` pattern: validate the argument type, degrade to an error/scaffold page on mismatch. For existing queue routes, allow `settings.arguments as String?` to be passed as `focusId`.

- [ ] **Step 2: Add focus handling to each screen**

For each queue screen, add `final String? focusId;` to the widget constructor, store it in State, and after the existing data load completes, find the matching row by `id == focusId` and call the screen's existing detail-opening method exactly once (guard with a bool). If not found, do nothing — Task 5 handles the user-facing fallback. Reuse existing handlers; do not build action descriptors in the routes file.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add lib/config/routes.dart lib/screens
git commit -m "feat(notifications): add deep-link routes and focus-id handling on destination screens"
```

---

### Task 5: Tap handler navigation + missing-entity fallback

**Files:**
- Modify: `lib/screens/citizen/notifications_screen.dart:375-382`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ceb.arb`, `lib/l10n/app_fil.arb`

**Interfaces:**
- Consumes: `resolveDestination` (Task 3), new routes (Task 4), `DocumentService.getRequestById`, `UserService.getUserProfile`.
- Produces: `_navigateTo(NotificationDestination, AppNotification)` on the notifications screen.

- [ ] **Step 1: Add l10n strings**

Add `notificationUnavailable` ("This item is no longer available.") to all three ARB files (Cebuano/Filipino may reuse the English string if no translation is available). Run `flutter gen-l10n`.

- [ ] **Step 2: Implement tap navigation**

Replace `onTap: () => _markRead(notification)` with a handler that first `await _markRead(notification)`, then computes `final destination = resolveDestination(notification, currentRole)` (role from `Provider.of<AuthProvider>(context, listen: false)` or equivalent already used in the file). If `destination == none`, stop. Otherwise:
- `documentViewer`: `final request = await DocumentService().getRequestById(notification.referenceId!)`; if null → snackbar fallback; else `Navigator.pushNamed(context, AppRoutes.documentViewer, arguments: request)`.
- official/queue destinations (`pendingRequests`, `pendingPayments`, `captainApproval`, `incidentReports`, `pendingUsers`): `Navigator.pushNamed(context, destination.routeName!, arguments: notification.referenceId)` — the queue screen's focus handling (Task 4) opens the detail; if the focus id is not found it simply stays on the list, which is the documented fallback.
- list fallbacks (`myRequests`, `myReports`, `announcements`): `Navigator.pushNamed(context, destination.routeName!)` with no argument.
- `none`: nothing further.

For any null `referenceId` where a destination requires one: show the `notificationUnavailable` snackbar.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: zero errors.

- [ ] **Step 4: Full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/citizen/notifications_screen.dart lib/l10n
git commit -m "feat(notifications): navigate to exact item on notification tap"
```

---

## Final verification

- `flutter analyze` → zero errors.
- `flutter test` → all green.
- Manual (needs live DB with migration applied): tap a request notification as citizen → viewer opens; as secretary → pending-requests queue opens the detail with actions; tap an old NULL-reference notification → list screen; tap a notification whose entity was deleted → list + snackbar.
