# verify-document

Supabase Edge Function for public document verification via browser.

## Purpose

Serves a lightweight HTML verification page that external agencies can access
by scanning a QR code on a barangay-issued document — no Flutter app required.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/verify-document/:documentId?token=...` | Serve HTML verification page |
| GET | `/verify-document/:documentId?token=...` (Accept: application/json) | Return JSON verification data |
| POST | `/verify-document/:documentId?token=...` | Consume one use of the document |

## Deploy

```bash
supabase functions deploy verify-document --no-verify-jwt
```

> **Important:** `--no-verify-jwt` is required because this is a public endpoint — anyone with a QR code can verify a document without logging in.

## Environment

Uses the standard Supabase Edge Function environment variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## QR Code URL Format

```
https://<project-ref>.supabase.co/functions/v1/verify-document/BRGY-GUION-2026-000123?token=<64hex>
```

Or with a custom domain:
```
https://barangay-guion.app/verify-document/BRGY-GUION-2026-000123?token=<64hex>
```

## Verification Logic

Mirrors the Flutter app's `VerificationService`:
1. Resolve document by `documentId` + `token` (parent or print copy)
2. Evaluate access rules (expiry, single-use, use limit)
3. POST atomically increments `use_count` with optimistic locking
4. Returns HTML for browsers, JSON for API consumers
