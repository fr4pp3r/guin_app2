# `push` Edge Function

Sends Firebase Cloud Messaging (FCM) push notifications to a user's registered
Android devices. This is the server half of the in-app notification system: the
Flutter client still writes the row into `public.notifications`, and this
function mirrors that row to FCM.

See `PUSH_NOTIFICATIONS.md` at the repo root for the full end-to-end setup.

## Contract

**Request** — `POST /functions/v1/push`

One recipient:

```json
{ "user_id": "<uuid>", "title": "...", "message": "...", "type": "system" }
```

Barangay-wide fan-out (announcements) — one lookup, one loop, N devices:

```json
{ "user_ids": ["<uuid>", "<uuid>"], "title": "...", "message": "...", "type": "system" }
```

Headers: `Authorization: Bearer <supabase-jwt>`, `Content-Type: application/json`.

`title`, `message` and `type` are optional — if omitted, the function re-reads
`public.notifications` for the (first) user and pushes the latest row. The
Flutter client (`NotificationService`) always sends them so the payload is
self-contained.

**Success** — HTTP 200

```json
{ "ok": true, "sent": 2, "failed": 0 }
```

`sent: 0` is a normal outcome (no registered devices). The Flutter client ignores
the response entirely.

**Error** — HTTP status + JSON envelope

```json
{ "error": { "code": "not_configured", "message": "..." } }
```

| Status | Code               | Meaning                                      |
| ------ | ------------------ | -------------------------------------------- |
| 200    | —                  | Push attempted; see `sent` / `failed`         |
| 400    | `bad_request`      | Missing `user_id`/`user_ids`, bad JSON       |
| 401    | `unauthorized`     | Missing/invalid bearer token                 |
| 500    | `not_configured`   | `FIREBASE_SERVICE_ACCOUNT` secret is unset   |
| 502    | `upstream_failure` | FCM rejected the send                        |

## Auth model

Same as the `ai` function: `config.json` sets `verify_jwt: false` (shipped by
`supabase functions deploy push`), so the gateway lets the call through and the
app's project anon key is the bearer token. The function then uses the
**service role** key (a platform-provided secret) to read `device_push_tokens`
and `notifications`, so it sees rows regardless of RLS.

Deploy with the plain command — do **not** add `--no-verify-jwt`:

```bash
supabase functions deploy push
```

## Secrets

| Secret                     | Where to get it                                                                 |
| -------------------------- | ------------------------------------------------------------------------------- |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase console → Project settings → **Service accounts** → *Generate new private key*. Paste the whole JSON file as a **single-line** secret value. |

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
supabase functions deploy push
```

The private key never reaches the app. If the secret is absent the function
returns `not_configured` and the app carries on with in-app notifications only.

## Smoke test

```bash
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/push" \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"<users_profile uuid>","title":"Test","message":"Hello from FCM"}'
```

Expected: `HTTP/1.1 200 OK`. `sent: 0` means that user has no registered device
yet — sign in on the Android app once and it registers its token.
