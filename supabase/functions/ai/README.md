# `ai` Edge Function

Single server-side gateway for all future AI features. Holds the Gemini API key
as a Supabase secret — the Flutter app never sees it. See the main
`DOCUMENTATION.md` for the overall architecture.

## Contract

**Request** — `POST /functions/v1/ai`

```json
{ "task": "ping", "payload": {} }
```

Headers: `Authorization: Bearer <supabase-jwt>`, `Content-Type: application/json`.

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
| 400    | `bad_request`      | Missing/unknown task, bad JSON           |
| 401    | `unauthorized`     | Missing/invalid bearer token             |
| 429    | `quota_exhausted`  | Gemini free-tier quota exhausted         |
| 502    | `upstream_failure` | Gemini upstream error                    |

Error envelope: `{ "error": { "code": string, "message": string } }`.

**Tasks today:** `ping` (connectivity test), `document-processor` (AI document
validation) and `incident-classifier` (AI incident categorization) — both live.

## Adding a feature

Handler modules live in `handlers/*.ts` and export an async `TaskHandler` as their
**default export**. Import them **statically** in `index.ts` and register in the
`routes` map. Do NOT use runtime `import()` with computed specifiers — the deploy
bundler only ships statically-resolvable imports, and dynamically-loaded handlers
silently 501 in production.

## Auth model

The platform gateway enforces `verify_jwt` (default ON for deployed functions) —
every request needs `Authorization: Bearer <jwt>`, a valid project token. Because
the app does not use Supabase Auth, the anon key embedded in the client satisfies
this: it gates the function to clients that hold a valid project credential and
prevents open internet abuse. In-function re-verification is optional
defense-in-depth that only runs if `SUPABASE_JWT_SECRET` is set (the CLI refuses
`SUPABASE_`-prefixed secret names, so on standard deployments the gateway is the
gate and the client must still send the bearer — `AiService` does).

## Setup

1. Get a free Gemini API key at <https://aistudio.google.com> (free tier,
   Flash models only — e.g. `gemini-2.5-flash`).
2. Deploy:

   ```bash
   supabase functions deploy ai
   ```

3. Set secrets (never commit these):

   ```bash
   supabase secrets set GEMINI_API_KEY=your-key-here
   supabase secrets set AI_MODEL=gemini-2.5-flash
   ```

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
