# `ai` Edge Function

Single server-side gateway for all future AI features. Holds the Gemini API key
as a Supabase secret — the Flutter app never sees it. See the main
`DOCUMENTATION.md` for the overall architecture.

## Contract

**Request** — `POST /functions/v1/ai`

```json
{ "task": "ping", "payload": {} }
```

Headers: `Authorization: Bearer <supabase-anon-key>`, `Content-Type: application/json`.

**Success** — HTTP 200

- `ping` → `{ "ok": true }`
- feature tasks → `{ "result": { ... } }`

**Error** — HTTP status + JSON envelope

```json
{ "error": { "code": "quota_exhausted", "message": "AI quota exhausted" } }
```

| Status | Code               | Meaning                                  |
| ------ | ------------------ | ---------------------------------------- |
| 200    | —                  | `{ok:true}` or `{result: {...}}`         |
| 400    | `bad_request`      | Missing/unknown task, bad JSON, bad payload |
| 401    | `unauthorized`     | Missing/invalid bearer token             |
| 429    | `quota_exhausted`  | Gemini free-tier quota exhausted         |
| 500    | `config_error`     | `GEMINI_API_KEY` secret is unset         |
| 502    | `upstream_failure` | Gemini upstream error                    |
| 503    | `BOOT_ERROR`       | **Not a handler response.** The function refused to start — it is not running at all. See [When every task returns 503 BOOT_ERROR](#when-every-task-returns-503-boot_error). |

Error envelope: `{ "error": { "code": string, "message": string } }`.

**Tasks today:** `ping` (connectivity test), `document-processor` (AI document
validation), `incident-classifier` (AI incident categorization), `incident-reviewer` (AI analysis + review),
`id-verifier` (advisory ID plausibility pre-check), `receipt-parser` (GCash
receipt parsing) and `chatbot` (Barangay Assistant — answers citizen
information queries and FAQ questions) — all live.

> `chatbot` is **informational only**: it answers questions about documents,
> fees/payment, request statuses, incident reporting, announcements and document
> verification, grounded in a fixed fact list plus the app's own FAQ table. It
> performs no action and, when the AI is unreachable, the Flutter screen falls
> back to a local keyword match over `lib/utils/faqs.dart`. The FAQ table is
> sent per-locale (English / Filipino / Cebuano) and the caller passes a
> `language` hint, so answers follow the app's active locale.

> `id-verifier` is **advisory only**: it returns `looks_ok` or `needs_review` and
> never approves or rejects a registration — a captain always reviews. It does
> **not** compare the selfie to the face on the ID, and there is no
> `guarantor-verifier` task (guarantors are existing approved users).

## Adding a feature

Handler modules live in `handlers/*.ts` and export an async `TaskHandler` as their
**default export**. Import them **statically** in `index.ts` and register in the
`routes` map. Do NOT use runtime `import()` with computed specifiers — the deploy
bundler only ships statically-resolvable imports, and dynamically-loaded handlers
silently 501 in production.

## Auth model

`supabase/functions/ai/config.json` sets `verify_jwt: false`, and `supabase functions deploy ai`
ships that file with the bundle — so the gateway lets the request through to this
function, which then enforces its own check in `index.ts` (`verifyJwt`): a
non-empty `Authorization: Bearer <...>` header. Because the app does not use
Supabase Auth there is no Supabase Auth JWT to send; the client sends the
**project anon key**, which is exactly the credential every other Supabase call
from the app already carries. That gates the function to clients that hold a
project credential and prevents open internet abuse — it is not an identity, and
the function is intentionally callable by any project credential, the same
posture as the app's direct database access.

Do **not** deploy with `--no-verify-jwt` and do not delete `config.json`: without
it the platform default applies and deployments have been observed to land in a
state where the function never boots (503 `BOOT_ERROR`), taking every task down
with it — including ones that never touch the database.

Optionally set `SUPABASE_JWT_SECRET` to add in-function re-verification of a
project JWT. Standard deployments skip it (the CLI refuses to set
`SUPABASE_`-prefixed secret names), which is why the gateway config, not the
secret, is what actually controls access.

## When every task returns 503 BOOT_ERROR

Symptom: **every** task — including `ping` — returns

```json
{"code":"BOOT_ERROR","message":"Function failed to start (please check logs)"}
```

with HTTP 503, and the chatbot shows its "assistant unavailable" fallback on
every question. This is the platform failing to start the function, so nothing
in the handlers is even reached. Work through it in this order:

1. **Confirm it is a boot failure, not a bad request.** A malformed body still
   returns a normal `400`; a `503 BOOT_ERROR` means the isolate never ran. Note
   that a request with *no* `Authorization` header also returns `503` here
   (the gateway answers before the function exists), so an unauthenticated probe
   is not evidence either way — probe with the anon key.

2. **Check the runtime logs.** Dashboard → **Edge Functions → ai → Logs** (or
   **Invocations**). A boot failure logs the reason at startup, before any
   `ai task=...` line.

3. **Type-check the bundle locally** — this catches the most common cause, a
   module that does not compile:

   ```bash
   npx --yes deno@latest check supabase/functions/ai/index.ts
   ```

   It must print `Check ...` and exit `0`. Fix and redeploy if not.

4. **Redeploy the whole function:**

   ```bash
   supabase functions deploy ai
   ```

   Do not add `--no-verify-jwt`. `config.json` is shipped automatically and is
   what keeps the gateway from demanding a Supabase Auth JWT.

5. **Verify with the ping task** before blaming a feature handler:

   ```bash
   curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/ai" \
     -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"task":"ping","payload":{}}'
   ```

   `{"ok":true}` means the function is healthy; a feature failing after that is
   a handler or secret problem, not a boot problem.

If `ping` succeeds but a feature still fails, check that feature's secrets
(`GEMINI_API_KEY`, `AI_MODEL`) and then its handler. Remember the free tier is
~5–15 requests/minute: a burst of questions returns `quota_exhausted` (429) and
the app simply falls back to its offline FAQ answer.

## Setup

1. Get a free Gemini API key at <https://aistudio.google.com> (free tier,
   Flash models only — e.g. `gemini-2.5-flash`).
2. Deploy (from the repo root) — this ships `config.json` and every handler:

   ```bash
   supabase functions deploy ai
   ```

   Do **not** pass `--no-verify-jwt`; the checked-in `config.json` is what keeps
   the function bootable and reachable. If you are not linked to the project,
   add `--project-ref <your-project-ref>`.

3. Set secrets (never commit these):

   ```bash
   supabase secrets set GEMINI_API_KEY=your-key-here
   supabase secrets set AI_MODEL=gemini-2.5-flash
   ```

4. Smoke-test with the `ping` task (see below). If `ping` does not return
   `{"ok":true}`, no feature task will work — fix the boot first.

> ⚠️ Free-tier limits are tight (~5–15 requests/minute, a few hundred per day).
> All features must degrade gracefully — the Flutter `AiService` returns `null`
> and the app falls back to its non-AI path.

## Smoke test

```bash
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/ai" \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"task":"ping","payload":{}}'
```

Expected: `HTTP/1.1 200 OK` and body `{"ok":true}`.

If you get `503 {"code":"BOOT_ERROR"}` instead, the function is not running —
see [When every task returns 503 BOOT_ERROR](#when-every-task-returns-503-boot_error).
