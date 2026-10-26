# Push Notifications (Firebase Cloud Messaging) — Android

How the push feature is wired, and the exact steps to switch it on for your
deployment. **Scope today: Android only.** iOS and web are deliberately out of
scope — see [Adding iOS or web later](#adding-ios-or-web-later).

The feature is built so that **nothing breaks before you finish this guide**.
Without a Firebase project the app builds, runs and behaves exactly as it does
today: in-app notifications, the bell badge and realtime updates all keep
working, and push is simply inactive.

---

## 1. How it works

```
save a document / approve / receive payment / post announcement
        │
        ▼
NotificationService.createNotification()      ← lib/services/notification_service.dart
        │  inserts the row the bell reads (unchanged behaviour, source of truth)
        │
        └─► fire-and-forget POST /functions/v1/push   ← supabase/functions/push/index.ts
                    │
                    ├─ reads device_push_tokens for that user (service role)
                    ├─ gets an FCM OAuth2 token from the service account
                    └─ sends to every device token via FCM HTTP v1
                                │
                                ▼
                     Android device receives the push
```

Announcements take a batched variant of the same path, because they fan out to
every approved user rather than one: `notifyAllApproved` inserts the rows in
bulk, then hands the whole recipient list to the function once, as `user_ids`.
That call is awaited (with a bounded timeout) instead of fire-and-forget — a
bulk fan-out finishes and the screen navigates away immediately, which would
otherwise drop the in-flight requests.

Key properties:

- **The bell is the source of truth.** Push is a side channel. A push that never
  arrives costs you nothing — the notification is already in the list.
- **Every call site degrades gracefully.** The Flutter half (`PushService`) and
  the trigger in `NotificationService` both swallow failures and only
  `debugPrint`.
- **No secrets on the device.** The Firebase private key lives in Supabase
  secrets and only the `push` Edge Function ever sees it.
- **Tokens are device-scoped.** The app does not use Supabase Auth, so a token
  row is keyed by `users_profile.id` + the FCM token. Signing out deletes this
  device's rows so the next account on the phone does not inherit them.

Files involved:

| File | Role |
| ---- | ---- |
| `lib/services/push_service.dart` | Flutter half: Firebase init, token, registration, foreground refresh |
| `lib/services/notification_service.dart` | Calls the `push` function after every notification insert |
| `lib/main.dart` | Calls `PushService.initialize()` before `runApp`; binds provider lookups |
| `lib/providers/auth_provider.dart` | Registers the token on login/restore, removes it on sign-out |
| `android/app/build.gradle.kts` | Applies the Google Services plugin **only if** `google-services.json` exists |
| `android/app/src/main/AndroidManifest.xml` | Default FCM notification channel + icon |
| `supabase/functions/push/` | Server half: looks up tokens and calls FCM |
| `supabase/migrations/20261025_device_push_tokens.sql` | The token table (additive) |

---

## 2. Setup — step by step

### Step 1 — Create the Firebase project

1. Go to <https://console.firebase.google.com> and sign in with a Google account.
2. **Add project** → name it (e.g. `citeease-barangay`).
3. Google Analytics is **not** needed — you can turn it off. It has no effect on
   FCM.
4. Wait for the project to be created, then continue.

### Step 2 — Register the Android app

The registration **must** use the app's real application id, or FCM silently
refuses to deliver. Yours is currently:

```
com.example.citeease      <- android/app/build.gradle.kts, `applicationId`
```

1. In the Firebase console, open **Project settings** (gear icon) → **General**.
2. Under *Your apps*, click the **Android** icon.
3. **Android package name**: paste `com.example.citeease`.
   - If you change the application id later, you must register a new Android app
     in Firebase with the new id.
4. **App nickname**: anything, e.g. `CiteEase Android`.
5. **Debug signing certificate SHA-1**: *optional* — leave it blank. It is only
   needed for Dynamic Links / Google Sign-In, neither of which this app uses.
6. **Register app**.

> If you already have a different application id in production, register *that*
> id instead, and register `com.example.citeease` as a second app if you also
> build debug APKs.

### Step 3 — Download `google-services.json`

1. On the page that appears (or **Project settings → Your apps → Android app**),
   click **Download google-services.json**.
2. Put the file at exactly:

   ```
   android/app/google-services.json
   ```

3. That path is **gitignored** (each deployment has its own Firebase project), so
   it will not be committed. Anyone else building push for this deployment needs
   their own copy.

Nothing else to edit — `android/app/build.gradle.kts` detects the file and
applies the Google Services plugin automatically, and `android/build.gradle.kts`
already declares the plugin on the classpath. If the file is missing, the build
prints a notice and continues without push.

### Step 4 — Create the service account (server side)

The Edge Function needs to *send* messages, which requires a private key.

1. Firebase console → **Project settings** → **Service accounts** tab.
2. Click **Generate new private key** → **Generate key**. A `.json` file
   downloads. **Treat it like a password** — it can send pushes to your app.
3. Apply the database migration (Step 5) and set the secret (Step 6) before
   deleting the file from your machine.

### Step 5 — Apply the database migration

In the Supabase dashboard, open **SQL Editor**, paste the contents of

```
supabase/migrations/20261025_device_push_tokens.sql
```

and run it. It is additive and idempotent — safe to re-run, and it does not
touch existing tables.

> A brand-new project created from `setup.sql` already has this table; on such a
> project you can skip this step.

Verify:

```sql
select count(*) from public.device_push_tokens;
```

Expected: `0` (a table exists, currently empty). If you get
`relation "public.device_push_tokens" does not exist`, the migration did not run.

### Step 6 — Deploy the function and set its secret

Install the Supabase CLI if you have not already, then from the repo root:

```bash
# Point the CLI at your project (once)
supabase link --project-ref <your-project-ref>

# Store the service-account JSON as a single-line secret
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"

# Deploy
supabase functions deploy push
```

On Windows PowerShell the secret command is:

```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(Get-Content -Raw path\to\service-account.json)"
```

Then **delete the downloaded key file** from your machine — it is no longer
needed and must not sit in the repo. Confirm it is not tracked:

```bash
git status --short        # service-account.json must not appear
```

### Step 7 — Build and install the app

```bash
flutter pub get
flutter run               # or: flutter build apk --release --split-per-abi
```

The new build must include `google-services.json` — an APK built before Step 3
has no Firebase config and will never receive pushes. Reinstall it on the test
device.

### Step 8 — Smoke test

1. Sign in on the physical Android device (emulators work, but must have Google
   Play services).
2. Accept the notification permission prompt (Android 13+).
3. Watch the logs for:

   ```
   PushService: notification permission = authorized
   PushService: ready (token acquired)
   ```

4. Confirm the token landed in the database:

   ```sql
   select user_id, platform, last_seen_at from public.device_push_tokens;
   ```

5. Now **force-stop** the app (swipe it away from recents) and trigger a real
   notification from another account — e.g. log in as an official on a second
   device and approve a document request for that citizen, or post an
   announcement. The push should arrive with the app closed.

Or test the server half directly:

```bash
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/push" \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"<users_profile uuid>","title":"Test","message":"Hello from FCM"}'
```

`{"ok":true,"sent":1,"failed":0}` means FCM accepted it. `sent:0` means that user
has no registered device — sign in on the app first.

---

## 3. Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| Announcement notifications never arrive, but other pushes (approvals, payments) do | Fixed in this revision: the fan-out used to fire one un-awaited push call per citizen, which was dropped when the post finished. It is now a single batched call that is awaited. **If you had already deployed, redeploy the function and rebuild the app** (`supabase functions deploy push`). |
| **All** pushes arrive except announcements | Check the function logs; a barangay-wide fan-out can exceed the 20s client timeout on a very large user base. `sent` in the response shows how many devices FCM accepted. |
| `PushService: Firebase not configured, push disabled` | `android/app/google-services.json` is missing, or the APK predates it. Re-download and **rebuild + reinstall**. |
| `PushService: no device token (push inactive)` | The device has no Google Play services (some emulators), or the Firebase project has no Android app matching `com.example.citeease`. Check the application id. |
| `{"error":{"code":"not_configured"}}` from the function | `FIREBASE_SERVICE_ACCOUNT` is unset or not valid JSON. Re-run Step 6. |
| `sent:0` but the token row exists | Row's `user_id` does not match the id you sent, or you are checking a different Supabase project than the app is pointed at in `.env`. |
| Function returns 401 | The caller must send `Authorization: Bearer <SUPABASE_ANON_KEY>`. `NotificationService` already does. |
| Push arrives but no sound / no banner | Android 13+ permission was denied, or the user turned the `Barangay CiteEase` channel off in system settings. The in-app bell is unaffected. |
| Notification never appears while the app is **open** | Expected on Android — FCM does not draw a banner for a foreground app by default. The foreground handler refreshes the bell within a second instead. |
| Build error mentioning `google-services` | The JSON is malformed or registered to a different package name; re-download it. |
| Tapping a push just opens the app | Correct for now. Deep-linking into the specific screen is not wired (see the note in `PushService._listenOpened`). |

Handy during development:

```bash
flutter logs | Select-String PushService      # PowerShell
flutter logs | grep PushService               # bash
```

Every log line is prefixed with `PushService:` so you can tell at a glance
whether the device half is alive.

---

## 4. Adding iOS or web later

The implementation is deliberately shaped so these are additive, not rewrites:

- **iOS** — register an iOS app in Firebase with bundle id `com.example.citeease`,
  drop `GoogleService-Info.plist` into `ios/Runner/`, and upload an APNs key
  under **Project settings → Cloud Messaging**. Requires a paid Apple Developer
  account. Then remove the `defaultTargetPlatform != TargetPlatform.android`
  guard at the top of `PushService.initialize()` — the rest of the Dart, the
  `device_push_tokens` table (which already has a `platform` column) and the Edge
  Function already handle it.
- **Web** — needs a `web/firebase-messaging-sw.js` service worker and a VAPID key
  pair generated under **Project settings → Cloud Messaging → Web Push
  certificates**. Same one-line guard change.

Nothing in the current code needs to be un-done for either.

---

## 5. Verification checklist (used while building this)

- [x] `flutter analyze` — zero errors (the ~90 pre-existing `info`/`warning`
      lints are untouched; three new `deprecated_member_use` infos come from FCM
      v17's `getToken`/`onTokenRefresh`/`deleteToken`, which are still the
      Android path the plugin documents).
- [x] `flutter test` — 116/116 pass.
- [x] `flutter build apk --debug` — builds **without** `google-services.json`,
      printing the "FCM push notifications are disabled for this build" notice.
- [x] All notification call sites keep working when the function is absent: the
      invoke is fire-and-forget and failures are swallowed.
- [ ] Manual on-device smoke test (Step 8) — requires your Firebase project.
