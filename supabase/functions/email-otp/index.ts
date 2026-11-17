// Email OTP edge function — sends a 6-digit code via Gmail SMTP and verifies it.
//
// Contract:
//   Request:  POST { "action": "send" | "verify", "email": string, "code"?: string }
//   Success:  200 { "ok": true }
//   Failure:  <status> { "error": { "code": string, "message": string } }
//     400 invalid_email | invalid_code | bad_request
//     429 rate_limited (send cooldown / hourly cap) | too_many_attempts (verify)
//     500 config_error | 502 upstream_failure
//
// Codes are never stored in plaintext (SHA-256 of OTP_PEPPER + code) and never
// echoed in any response or log. The email_otps / verified_emails tables have
// RLS enabled with no client policies — this function uses the service-role
// key via raw PostgREST fetch, same convention as ../push/index.ts.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, errorResponse, jsonResponse } from "../ai/_shared.ts";
import nodemailer from "https://esm.sh/nodemailer@6.9.12/denonext/nodemailer.mjs";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GMAIL_EMAIL = Deno.env.get("GMAIL_EMAIL") ?? "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") ?? "";
const OTP_PEPPER = Deno.env.get("OTP_PEPPER") ?? "";

function configOk(): boolean {
  return Boolean(SUPABASE_URL && SERVICE_ROLE_KEY && GMAIL_EMAIL && GMAIL_APP_PASSWORD && OTP_PEPPER);
}

// ── Service-role REST client (same pattern as push/index.ts) ─────────────────

async function restGet(table: string, email: string): Promise<unknown> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${table}?email=eq.${encodeURIComponent(email)}`,
    {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    },
  );
  if (!res.ok) {
    throw Object.assign(new Error(`Supabase read failed (${res.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }
  const rows = (await res.json()) as unknown[];
  return rows[0] ?? null;
}

async function restUpsert(table: string, data: Record<string, unknown>): Promise<void> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=representation",
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    throw Object.assign(new Error(`Supabase write failed (${res.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }
}

async function restDelete(table: string, email: string): Promise<void> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${table}?email=eq.${encodeURIComponent(email)}`,
    {
      method: "DELETE",
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    },
  );
  if (!res.ok) {
    throw Object.assign(new Error(`Supabase delete failed (${res.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }
}

// ── OTP helpers ──────────────────────────────────────────────────────────────

// 6 digits from crypto.getRandomValues. Modulo over 2^32 has a negligible bias
// for a 5-minute, 5-attempt code — acceptable here.
function generateOtp(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return String(buf[0] % 1000000).padStart(6, "0");
}

async function sha256Hex(message: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sendOtpEmail(email: string, otp: string): Promise<void> {
  const transport = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: GMAIL_EMAIL, pass: GMAIL_APP_PASSWORD },
  });
  await transport.sendMail({
    from: GMAIL_EMAIL,
    to: email,
    subject: "Your Barangay E-Document System verification code",
    text: `Your verification code is: ${otp}\n\nIt expires in 5 minutes. If you did not request this, you can ignore this email.`,
    html: `<p>Your verification code is: <strong>${otp}</strong></p><p>It expires in 5 minutes. If you did not request this, you can ignore this email.</p>`,
  });
}

// ── Actions ──────────────────────────────────────────────────────────────────

async function handleSend(email: string): Promise<Response> {
  const row = (await restGet("email_otps", email)) as
    | { send_count: number; send_window_start: string; last_sent_at: string }
    | null;
  const now = new Date();

  let record: Record<string, unknown>;
  if (row) {
    record = row as unknown as Record<string, unknown>;
    // Rate limit order per plan: window check → cooldown → write.
    if (now.getTime() - new Date(row.send_window_start).getTime() > 3600000) {
      record.send_count = 1;
      record.send_window_start = now.toISOString();
    } else {
      if (row.send_count >= 3) {
        return errorResponse(429, "rate_limited", "Too many code requests this hour, try again later");
      }
      record.send_count = row.send_count + 1;
    }
    if (now.getTime() - new Date(row.last_sent_at).getTime() < 60000) {
      return errorResponse(429, "rate_limited", "Please wait a minute before requesting a new code");
    }
  } else {
    record = { email, send_count: 1, send_window_start: now.toISOString() };
  }

  const otp = generateOtp();
  record.code_hash = await sha256Hex(OTP_PEPPER + otp);
  record.expires_at = new Date(now.getTime() + 300000).toISOString();
  record.attempts = 0;
  record.last_sent_at = now.toISOString();

  await restUpsert("email_otps", record);
  await sendOtpEmail(email, otp);
  console.log(`email-otp action=send email=${email}`);
  return jsonResponse(200, { ok: true });
}

async function handleVerify(email: string, code: string): Promise<Response> {
  const row = (await restGet("email_otps", email)) as
    | { code_hash: string; expires_at: string; attempts: number }
    | null;
  if (!row) {
    return errorResponse(400, "invalid_code", "Invalid or expired code");
  }
  if (row.attempts >= 5) {
    return errorResponse(429, "too_many_attempts", "Too many attempts, request a new code");
  }
  if (new Date(row.expires_at) < new Date()) {
    return errorResponse(400, "invalid_code", "Invalid or expired code");
  }

  const hash = await sha256Hex(OTP_PEPPER + code);
  if (hash !== row.code_hash) {
    // Fail closed: if the attempt counter cannot be persisted, do not answer.
    await restUpsert("email_otps", { email, attempts: row.attempts + 1 });
    return errorResponse(400, "invalid_code", "Invalid or expired code");
  }

  await restUpsert("verified_emails", { email });
  await restDelete("email_otps", email);

  // Carry-forward: keep existing profiles' flag fresh. The Task-1 trigger
  // derives email_verified from verified_emails going forward; this PATCH is
  // best-effort housekeeping and must not fail an already-successful verify.
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/users_profile?email=eq.${encodeURIComponent(email)}`,
      {
        method: "PATCH",
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email_verified: true }),
      },
    );
    if (!res.ok) {
      console.error(`email-otp profile sync status=${res.status}`);
    }
  } catch (e) {
    console.error(`email-otp profile sync failed: ${String(e)}`);
  }

  console.log(`email-otp action=verify email=${email} ok=true`);
  return jsonResponse(200, { ok: true });
}

// ── Router ───────────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "bad_request", "Use POST");
  }
  if (!configOk()) {
    return errorResponse(500, "config_error", "Server configuration missing");
  }

  let body: { action?: unknown; email?: unknown; code?: unknown };
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "bad_request", "Body must be valid JSON");
  }

  const email = typeof body.email === "string" ? body.email : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return errorResponse(400, "invalid_email", "A valid email address is required");
  }

  try {
    if (body.action === "send") {
      return await handleSend(email);
    }
    if (body.action === "verify") {
      const code = typeof body.code === "string" ? body.code : "";
      if (!code) {
        return errorResponse(400, "invalid_code", "Invalid or expired code");
      }
      return await handleVerify(email, code);
    }
    return errorResponse(400, "bad_request", '"action" must be "send" or "verify"');
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    console.error(`email-otp failed: ${err.code ?? "unknown"}`);
    return errorResponse(
      err.status ?? 502,
      err.code ?? "upstream_failure",
      err.message ?? "Email OTP request failed",
    );
  }
});
