// reCAPTCHA v2 edge function — serves the challenge page and verifies tokens.
//
// Contract:
//   GET  /          → HTML page with reCAPTCHA widget (site key from env)
//   POST /verify    → { "token": "..." } → 200 { "ok": true } | error
//
// Deploy: `supabase functions deploy captcha` (no --no-verify-jwt).
// Secrets: RECAPTCHA_SITE_KEY (public), RECAPTCHA_SECRET_KEY (private).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
} from "../ai/_shared.ts";

const SITE_KEY = Deno.env.get("RECAPTCHA_SITE_KEY") ?? "";
const SECRET_KEY = Deno.env.get("RECAPTCHA_SECRET_KEY") ?? "";

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify you are human</title>
  <script src="https://www.google.com/recaptcha/api.js" async defer></script>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: #f5f5f5;
    }
    .captcha-container {
      background: white;
      padding: 24px;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      text-align: center;
      max-width: 400px;
      width: 90%;
    }
    .captcha-container h2 {
      margin-top: 0;
      font-size: 18px;
      color: #333;
    }
    .captcha-container p {
      font-size: 14px;
      color: #666;
      margin-bottom: 16px;
    }
    .g-recaptcha {
      margin: 16px 0;
    }
    .error {
      color: #d32f2f;
      font-size: 13px;
      margin-top: 12px;
      display: none;
    }
  </style>
</head>
<body>
  <div class="captcha-container">
    <h2>Verify you are human</h2>
    <p>Please complete the reCAPTCHA to continue.</p>
    <div class="g-recaptcha" data-sitekey="${SITE_KEY}"></div>
    <div class="error" id="error">Verification failed. Please try again.</div>
  </div>
  <script>
    var errorShown = false;
    function showToken(token) {
      if (window.flutterChannel) {
        window.flutterChannel.postJSON({ type: 'captcha_solved', token: token });
      }
    }
    function showError() {
      if (!errorShown) {
        errorShown = true;
        document.getElementById('error').style.display = 'block';
      }
    }
    window.onload = function() {
      try {
        grecaptcha.ready(function() {
          grecaptcha.execute('${SITE_KEY}', {action: 'submit'}).then(function(token) {
            showToken(token);
          });
        });
      } catch (e) {
        showError();
      }
    };
    window.addEventListener('error', function(e) {
      if (e.message && e.message.indexOf('recaptcha') !== -1) {
        showError();
      }
    });
  </script>
</body>
</html>`;

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // Serve the captcha page
  if (req.method === "GET" && url.pathname === "/") {
    if (!SITE_KEY) {
      return errorResponse(500, "config_error", "RECAPTCHA_SITE_KEY not configured");
    }
    return new Response(HTML, {
      headers: { ...corsHeaders, "Content-Type": "text/html" },
    });
  }

  // Verify a token
  if (req.method === "POST" && url.pathname === "/verify") {
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