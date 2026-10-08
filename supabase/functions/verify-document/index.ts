import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname;

  // Extract documentId from path: /verify-document/:documentId
  const match = path.match(/\/verify-document\/([^\/]+)/);
  const documentId = match ? decodeURIComponent(match[1]) : null;
  const token = url.searchParams.get("token");

  if (!documentId) {
    return new Response(
      JSON.stringify({ error: "Document ID is required" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  try {
    // Resolve document: try parent token first, then print copy token
    let verification = null;
    let copy = null;

    if (token) {
      // Try parent verification token
      const { data: parent } = await supabase
        .from("document_verifications")
        .select("*")
        .eq("document_id", documentId)
        .eq("verification_token", token)
        .maybeSingle();

      if (parent) {
        verification = parent;
      } else {
        // Try print copy token
        const { data: copyData } = await supabase
          .from("document_print_copies")
          .select("*")
          .eq("verification_token", token)
          .maybeSingle();

        if (copyData) {
          copy = copyData;
          const { data: parentByCopy } = await supabase
            .from("document_verifications")
            .select("*")
            .eq("document_id", copyData.document_id)
            .maybeSingle();
          verification = parentByCopy;
        }
      }
    } else {
      // No token: lookup by document ID only (view-only)
      const { data: parentOnly } = await supabase
        .from("document_verifications")
        .select("*")
        .eq("document_id", documentId)
        .maybeSingle();
      verification = parentOnly;
    }

    if (!verification) {
      return new Response(
        JSON.stringify({ error: "Document not found or verification token is invalid" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Evaluate access rules
    const decision = evaluateAccess(verification);

    // POST: consume one use
    if (req.method === "POST") {
      if (!token) {
        return new Response(
          JSON.stringify({ error: "Token required to consume document" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (decision !== "allowed") {
        return new Response(
          JSON.stringify({ error: "Document cannot be used", decision }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Optimistic lock: update only if use_count matches
      const newUseCount = (verification.use_count || 0) + 1;
      const isSingleUse = verification.single_use || false;
      const maxUses = verification.max_uses || null;
      const shouldMarkUsed = isSingleUse || (maxUses !== null && newUseCount >= maxUses);

      const { data: updated, error: updateErr } = await supabase
        .from("document_verifications")
        .update({
          use_count: newUseCount,
          used_at: new Date().toISOString(),
          ...(shouldMarkUsed ? { status: "used" } : {}),
        })
        .eq("document_id", documentId)
        .eq("verification_token", verification.verification_token)
        .eq("use_count", verification.use_count)
        .select()
        .maybeSingle();

      if (!updated) {
        return new Response(
          JSON.stringify({ error: "Concurrent update detected, please retry" }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Update copy last_used_at if applicable
      if (copy) {
        await supabase
          .from("document_print_copies")
          .update({ last_used_at: new Date().toISOString() })
          .eq("id", copy.id);
      }

      return new Response(
        JSON.stringify({
          success: true,
          decision: "allowed",
          verification: updated,
          copy: copy,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: always serve HTML for browser requests; JSON only if ?format=json
    const format = url.searchParams.get("format");
    if (format === "json") {
      return new Response(
        JSON.stringify({ verification, copy, decision }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const html = renderHtml(verification, copy, decision, token);
    return new Response(html, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "text/html; charset=utf-8",
      },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function evaluateAccess(v: any): string {
  const now = new Date();
  const status = v.status;
  const expiresAt = v.expires_at ? new Date(v.expires_at) : null;
  const singleUse = v.single_use || false;
  const maxUses = v.max_uses || null;
  const useCount = v.use_count || 0;

  if (status === "revoked") return "revoked";
  if (status === "used") return "used";
  if (expiresAt && now > expiresAt) return "expired";
  if (singleUse && useCount > 0) return "used";
  if (maxUses !== null && useCount >= maxUses) return "useLimitReached";
  return "allowed";
}

function renderHtml(v: any, copy: any, decision: string, token: string | null): string {
  const tone = decision === "allowed" ? "#2E7D32" : decision === "notFound" ? "#D32F2F" : "#F57C00";
  const icon = decision === "allowed" ? "✓" : decision === "notFound" ? "✕" : "⚠";
  const title = decision === "allowed" ? "Document Verified" : decision === "notFound" ? "Not Found" : "Verification Issue";
  const message = decision === "allowed"
    ? "This document is authentic and valid."
    : decision === "notFound"
    ? "No document matches this ID and token."
    : "This document has restrictions that prevent its use.";

  const remaining = v.max_uses ? Math.max(0, v.max_uses - (v.use_count || 0)) : null;
  const expired = v.expires_at ? new Date() > new Date(v.expires_at) : false;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document Verification - Barangay Guion</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F5F7FA; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { background: white; border-radius: 20px; padding: 32px; max-width: 480px; width: 100%; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .header { text-align: center; margin-bottom: 24px; }
    .icon { width: 64px; height: 64px; border-radius: 50%; background: ${tone}; color: white; display: inline-flex; align-items: center; justify-content: center; font-size: 32px; margin-bottom: 16px; }
    h1 { font-size: 22px; color: ${tone}; margin-bottom: 8px; }
    .message { color: #666; font-size: 14px; line-height: 1.5; }
    .details { margin-top: 24px; border-top: 1px solid #eee; padding-top: 20px; }
    .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #f5f5f5; }
    .row:last-child { border-bottom: none; }
    .label { color: #888; font-size: 13px; font-weight: 600; }
    .value { color: #333; font-size: 13px; font-weight: 600; text-align: right; }
    .badge { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; background: ${tone}20; color: ${tone}; }
    .use-btn { display: block; width: 100%; margin-top: 20px; padding: 14px; border: none; border-radius: 14px; background: #1976D2; color: white; font-size: 15px; font-weight: 700; cursor: pointer; transition: background 0.2s; }
    .use-btn:hover { background: #1565C0; }
    .use-btn:disabled { background: #ccc; cursor: not-allowed; }
    .footer { text-align: center; margin-top: 20px; color: #999; font-size: 11px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="icon">${icon}</div>
      <h1>${title}</h1>
      <p class="message">${message}</p>
    </div>
    <div class="details">
      <div class="row"><span class="label">Document Type</span><span class="value">${v.document_type || 'N/A'}</span></div>
      <div class="row"><span class="label">Citizen Name</span><span class="value">${v.citizen_name || 'N/A'}</span></div>
      <div class="row"><span class="label">Status</span><span class="value"><span class="badge">${(v.status || 'unknown').replace(/_/g, ' ')}</span></span></div>
      <div class="row"><span class="label">Issued</span><span class="value">${v.issued_at ? new Date(v.issued_at).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' }) : 'N/A'}</span></div>
      <div class="row"><span class="label">Expiry</span><span class="value">${v.expires_at ? new Date(v.expires_at).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' }) : 'No expiry'}</span></div>
      <div class="row"><span class="label">Usage</span><span class="value">${v.single_use ? 'Single use' : 'Multi use'}</span></div>
      ${remaining !== null ? `<div class="row"><span class="label">Uses Remaining</span><span class="value">${remaining} of ${v.max_uses}</span></div>` : ''}
      ${copy ? `<div class="row"><span class="label">Print Copy</span><span class="value">${copy.serial || copy.copy_number || 'N/A'}</span></div>` : ''}
    </div>
    ${token && decision === 'allowed' ? '<button class="use-btn" onclick="useDocument()">Mark as Used</button>' : ''}
    <div class="footer">Barangay Guion E-Document System</div>
  </div>
  <script>
    async function useDocument() {
      const btn = document.querySelector('.use-btn');
      btn.disabled = true;
      btn.textContent = 'Recording...';
      try {
        const res = await fetch(window.location.href, { method: 'POST' });
        const data = await res.json();
        if (data.success) {
          btn.textContent = 'Document Used Successfully';
          btn.style.background = '#2E7D32';
        } else {
          btn.textContent = data.error || 'Error';
          btn.style.background = '#D32F2F';
        }
      } catch (e) {
        btn.textContent = 'Network Error';
        btn.style.background = '#D32F2F';
      }
    }
  </script>
</body>
</html>`;
}
