// reCAPTCHA v2 edge function — verifies tokens only.
//
// Contract:
//   POST /verify    → { "token": "..." } → 200 { "ok": true } | error
//
// The HTML page is served from the bundled Flutter asset (assets/captcha.html)
// because the Supabase platform injects a `default-src 'none'; sandbox` CSP on
// GET responses that blocks all script execution.
//
// Deploy: `supabase functions deploy captcha` (no --no-verify-jwt).
// Secrets: RECAPTCHA_SITE_KEY (public, unused), RECAPTCHA_SECRET_KEY (private).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
} from "../ai/_shared.ts";

const SECRET_KEY = Deno.env.get("RECAPTCHA_SECRET_KEY") ?? "";

serve(async (req: Request): Promise<Response> => {
  const url = new URL(req.url);
  console.log("captcha request method=" + req.method + " path=" + url.pathname + " search=" + url.search);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Verify a token — accepts POST /captcha/verify AND POST /captcha (functions.invoke
  // sends to the function root with no path).
  const rootPath = url.pathname === "/captcha" || url.pathname === "/captcha/";
  if (req.method === "POST" && (url.pathname === "/captcha/verify" || rootPath)) {
    let body: { token?: unknown };
    try {
      body = await req.json();
    } catch {
      return errorResponse(400, "bad_request", "Body must be valid JSON");
    }

    const token = body.token;
    if (!token || typeof token !== "string") {
      return errorResponse(400, "bad_request", "token is required");
    }

    if (!SECRET_KEY) {
      return errorResponse(500, "config_error", "RECAPTCHA_SECRET_KEY not configured");
    }

    try {
      const verifyRes = await fetch(
        "https://www.google.com/recaptcha/api/siteverify",
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: "secret=" + SECRET_KEY + "&response=" + token,
        }
      );
      const data = await verifyRes.json();
      if (data.success) {
        return jsonResponse(200, { ok: true });
      }
      const codes = Array.isArray(data["error-codes"])
        ? data["error-codes"].join(", ")
        : "Verification failed";
      return errorResponse(400, "captcha_failed", codes);
    } catch (e) {
      console.error("captcha verify upstream failed:", String(e));
      return errorResponse(502, "upstream_failure", "reCAPTCHA verification request failed");
    }
  }

  return errorResponse(404, "not_found", "Not found");
});