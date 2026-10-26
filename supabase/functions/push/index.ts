// Push edge function — mirrors a notification row to Firebase Cloud Messaging.
//
// Contract:
//   Request:  POST { "user_id": uuid, "title"?: string, "message"?: string, "type"?: string }
//   Success:  200 { "ok": true, "sent": n, "failed": n }
//   Failure:  <status> { "error": { "code": string, "message": string } }
//
// Auth: same model as the `ai` function — `config.json` sets verify_jwt=false so
// the gateway does not demand a Supabase Auth JWT (this app has none), and the
// app sends the project anon key as its bearer token. The function itself uses
// the service-role key to read device_push_tokens and notifications, so RLS
// (which is permissive anyway) is irrelevant here.
//
// Delivery is best-effort by design: the caller (NotificationService) fires and
// forgets, because the in-app notification row is the source of truth. A push
// that fails — no device registered, no service-account secret, FCM down — must
// never surface to the user or affect the workflow that produced it.
//
// Setup and secrets: see ./README.md and PUSH_NOTIFICATIONS.md at the repo root.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// ── Service-role REST client (no SDK needed for two tables) ──────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(status: number, code: string, message: string): Response {
  return jsonResponse(status, { error: { code, message } });
}

async function restGet(path: string): Promise<unknown[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!res.ok) {
    throw Object.assign(new Error(`Supabase read failed (${res.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }
  return await res.json();
}

// ── FCM HTTP v1 access token (service-account JWT → OAuth2) ──────────────────

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlJson(value: unknown): string {
  const encoded = new TextEncoder().encode(JSON.stringify(value));
  return base64Url(new Uint8Array(encoded.buffer as ArrayBuffer));
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const bytes = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

interface CachedToken {
  value: string;
  expiresAt: number;
}

// Deno isolates are reused between invocations, so caching here removes an
// OAuth round-trip from almost every call.
let cachedToken: CachedToken | null = null;

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = base64UrlJson({ alg: "RS256", typ: "JWT" });
  const claims = base64UrlJson({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  });
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;

  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    console.error(`FCM token exchange failed status=${res.status}`);
    throw Object.assign(new Error("Could not obtain FCM access token"), {
      status: 502,
      code: "upstream_failure",
    });
  }
  const data = await res.json();
  cachedToken = {
    value: data.access_token as string,
    expiresAt: now + Number(data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

// ── Sending ─────────────────────────────────────────────────────────────────

interface TokenRow {
  token: string;
}

/** Reads the token rows for a set of users in one (or few) round-trips. */
async function tokensForUsers(userIds: string[]): Promise<TokenRow[]> {
  const inList = userIds.map((id) => `"${id}"`).join(",");
  return (await restGet(
    `device_push_tokens?user_id=in.(${encodeURIComponent(inList)})&select=token`,
  )) as TokenRow[];
}

/**
 * Sends one push to every token the users own.
 *
 * Returns how many sends FCM accepted and how many it rejected. Tokens FCM
 * reports as permanently invalid (the app was uninstalled, the token was
 * rotated away) are deleted so the table does not grow dead rows forever —
 * this is the only reason the function writes to the database at all.
 *
 * Accepts a list of users so a barangay-wide fan-out (announcements) is one
 * lookup and one loop instead of N invocations.
 */
async function sendToUsers(
  account: ServiceAccount,
  userIds: string[],
  title: string,
  message: string,
  type: string,
): Promise<{ sent: number; failed: number }> {
  const rows = await tokensForUsers(userIds);
  if (!Array.isArray(rows) || rows.length === 0) {
    return { sent: 0, failed: 0 };
  }

  const accessToken = await getAccessToken(account);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  let failed = 0;
  const deadTokens: string[] = [];

  for (const row of rows) {
    const token = row?.token;
    if (!token) continue;
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: message },
            // `notification_type` is the app's own enum value, carried through
            // so a future deep-link/tap handler can branch on it without
            // string-matching the title.
            data: { type },
            android: {
              priority: "high",
              notification: {
                // Must match PushService.channelId and the manifest's
                // default_notification_channel_id, or Android drops the
                // notification while the app is backgrounded.
                channel_id: "citeease_default",
                sound: "default",
              },
            },
          },
        }),
      });
      if (res.ok) {
        sent++;
        continue;
      }
      const body = await res.text();
      failed++;
      if (res.status === 404 || res.status === 400) {
        // UNREGISTERED / INVALID_ARGUMENT for this registration token.
        deadTokens.push(token);
      }
      console.error(`FCM send failed status=${res.status} body=${body.slice(0, 200)}`);
    } catch (e) {
      failed++;
      console.error(`FCM send error: ${String(e)}`);
    }
  }

  for (const token of deadTokens) {
    try {
      await fetch(
        `${SUPABASE_URL}/rest/v1/device_push_tokens?token=eq.${encodeURIComponent(token)}`,
        {
          method: "DELETE",
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          },
        },
      );
    } catch {
      // Pruning is housekeeping; never fail the request over it.
    }
  }

  return { sent, failed };
}

// ── Router ──────────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "bad_request", "Use POST");
  }

  let body: {
    user_id?: unknown;
    user_ids?: unknown;
    title?: unknown;
    message?: unknown;
    type?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "bad_request", "Body must be valid JSON");
  }

  // One recipient (`user_id`) or a barangay-wide fan-out (`user_ids`).
  const userIds: string[] = [];
  if (typeof body.user_id === "string" && body.user_id) {
    userIds.push(body.user_id);
  }
  if (Array.isArray(body.user_ids)) {
    for (const candidate of body.user_ids) {
      if (typeof candidate === "string" && candidate) userIds.push(candidate);
    }
  }
  if (userIds.length === 0) {
    return errorResponse(
      400,
      "bad_request",
      '"user_id" or "user_ids" must be provided',
    );
  }
  const targetId = userIds[0];

  let title = typeof body.title === "string" ? body.title : "";
  let message = typeof body.message === "string" ? body.message : "";
  let type = typeof body.type === "string" ? body.type : "system";

  // Fallback: if the caller did not echo the notification, read the newest row
  // for the user so the push still has content.
  if (!title || !message) {
    try {
      const rows = (await restGet(
        `notifications?user_id=eq.${encodeURIComponent(targetId)}` +
          `&select=title,message,type&order=created_at.desc&limit=1`,
      )) as Array<{ title?: string; message?: string; type?: string }>;
      const latest = Array.isArray(rows) ? rows[0] : undefined;
      if (latest) {
        title = title || String(latest.title ?? "");
        message = message || String(latest.message ?? "");
        type = type || String(latest.type ?? "system");
      }
    } catch (e) {
      console.error(`Notification lookup failed: ${String(e)}`);
    }
  }
  if (!title || !message) {
    return errorResponse(400, "bad_request", "No notification content to send");
  }

  if (!FIREBASE_SERVICE_ACCOUNT) {
    // Expected before step 4 of PUSH_NOTIFICATIONS.md. The app ignores this.
    return errorResponse(
      500,
      "not_configured",
      "FIREBASE_SERVICE_ACCOUNT secret is not set",
    );
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
  } catch {
    return errorResponse(
      500,
      "not_configured",
      "FIREBASE_SERVICE_ACCOUNT is not valid JSON",
    );
  }
  if (!account.client_email || !account.private_key || !account.project_id) {
    return errorResponse(
      500,
      "not_configured",
      "FIREBASE_SERVICE_ACCOUNT is missing client_email/private_key/project_id",
    );
  }

  // The private key is often pasted with literal \n escapes.
  account.private_key = account.private_key.replace(/\\n/g, "\n");

  try {
    const result = await sendToUsers(account, userIds, title, message, type);
    console.log(
      `push users=${userIds.length} sent=${result.sent} failed=${result.failed}`,
    );
    return jsonResponse(200, { ok: true, ...result });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    console.error(`push failed: ${String(e)}`);
    return errorResponse(
      err.status ?? 502,
      err.code ?? "upstream_failure",
      err.message ?? "Push delivery failed",
    );
  }
});
