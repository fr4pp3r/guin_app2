// AI edge function — single gateway for all future AI features.
//
// Contract:
//   Request:  POST { "task": string, "payload": object }
//   Success:  200 { "ok": true } (ping) or { "result": {...} } (feature tasks)
//   Failure:  <status> { "error": { "code": string, "message": string } }
//
// Auth: the platform gateway enforces verify_jwt (default ON) — requests must
// carry `Authorization: Bearer <jwt>` where the JWT is a valid project token.
// The app does not use Supabase Auth, so in practice the bearer token is the
// project's anon key (itself such a JWT). If SUPABASE_JWT_SECRET is set the
// function re-verifies locally; otherwise the gateway is the gate.

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

const JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET") ?? "";

async function verifyJwt(req: Request): Promise<boolean> {
  // The platform gateway (verify_jwt, default ON for deployed functions)
  // already rejects calls without a valid project JWT, so in-function
  // re-verification is defense-in-depth, not the primary gate. It only runs
  // when SUPABASE_JWT_SECRET is available; the CLI refuses to set
  // SUPABASE_-prefixed secret names, so on standard deployments this is
  // skipped and the gateway is the gate.
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
