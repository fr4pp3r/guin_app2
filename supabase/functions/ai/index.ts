// AI edge function — single gateway for all future AI features.
//
// Contract:
//   Request:  POST { "task": string, "payload": object }
//   Success:  200 { "ok": true } (ping) or { "result": {...} } (feature tasks)
//   Failure:  <status> { "error": { "code": string, "message": string } }
//
// Auth: the client sends `Authorization: Bearer <anon key>` — see
// `supabase/functions/ai/README.md` § Auth model. Note the deployed function
// does NOT accept a Supabase Auth access token (this app has no Supabase Auth);
// only the project credential the client already holds.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import * as jose from "https://esm.sh/jose@5.9.6";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
} from "./_shared.ts";
import documentProcessor from "./handlers/document_processor.ts";
import incidentClassifier from "./handlers/incident_classifier.ts";
import incidentReviewer from "./handlers/incident_reviewer.ts";
import idVerifier from "./handlers/id_verifier.ts";
import receiptParser from "./handlers/receipt_parser.ts";
import chatbot from "./handlers/chatbot.ts";

// Redeploy note: `supabase functions deploy ai` (no --no-verify-jwt) is the
// correct command. It ships `config.json` alongside this file, which is what
// pins verify_jwt=false so the gateway does not demand a Supabase Auth JWT —
// this app does not use Supabase Auth, so without that file every call gets
// rejected before it reaches the handlers. A missing/incorrect config is one of
// the few ways this function can fail to boot (HTTP 503 BOOT_ERROR), so keep
// it in sync with the deployed function.

const JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET") ?? "";

async function verifyJwt(req: Request): Promise<boolean> {
  // verify_jwt is OFF for this function (see config.json): the app does not use
  // Supabase Auth, so a gateway that demands an Auth JWT would reject every
  // call. The bearer token the client sends is the project anon key, which
  // stops open internet abuse but is not an identity — this function is
  // therefore callable by anyone holding a project credential, exactly like the
  // app's own direct Supabase calls.
  if (!JWT_SECRET) return true;
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return false;
  try {
    await jose.jwtVerify(token, new TextEncoder().encode(JWT_SECRET), {
      algorithms: ["HS256"],
    });
    return true;
  } catch {
    return false;
  }
}

// Feature handlers live in ./handlers/*.ts and export an async TaskHandler as
// their DEFAULT export. They are imported statically above (the deploy bundler
// only ships statically-resolvable imports — a runtime `import()` registry did
// not get bundled, so handlers 501'd in production) and registered here.
type TaskHandler = (payload: Record<string, unknown>) => Promise<Response>;

const routes: Record<string, TaskHandler> = {
  "document-processor": documentProcessor,
  "incident-classifier": incidentClassifier,
  "incident-reviewer": incidentReviewer,
  "id-verifier": idVerifier,
  "receipt-parser": receiptParser,
  chatbot,
  ping: () => Promise.resolve(jsonResponse(200, { ok: true })),
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "bad_request", "Use POST");
  }
  if (!(await verifyJwt(req))) {
    return errorResponse(401, "unauthorized", "Missing or invalid bearer token");
  }

  let body: { task?: unknown; payload?: unknown };
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "bad_request", "Body must be valid JSON");
  }
  if (typeof body.task !== "string" || body.task.length === 0) {
    return errorResponse(400, "bad_request", '"task" must be a non-empty string');
  }
  const payload =
    body.payload && typeof body.payload === "object" && !Array.isArray(body.payload)
      ? (body.payload as Record<string, unknown>)
      : {};

  const handler = routes[body.task];
  if (!handler) {
    return errorResponse(400, "bad_request", `Unknown task: ${body.task}`);
  }
  console.log(`ai task=${body.task}`);
  return await handler(payload);
});
