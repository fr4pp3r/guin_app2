// Face match edge function — manages official-enrolled face samples
// (enroll / verify / list / delete). The rows are biometric data: only this
// function may touch them, and photos surface only as 1-hour signed URLs —
// never public URLs.
//
// Contract:
//   Request:  POST { "action": "enroll" | "verify" | "list" | "delete" }
//     enroll { fullName: string, dob: "YYYY-MM-DD", embedding: number[],
//              photoBase64: string, enrolledBy?: uuid }
//     verify { fullName: string, embedding: number[] }
//     list   {}
//     delete { id: uuid }
//   Success:  200 { "ok": true, "enrollmentId": uuid }
//             200 { "ok": true, "matched": bool, "score": number,
//                   "reason"?: "not_enrolled", "enrollmentId"?: uuid }
//             200 { "ok": true, "enrollments": [{ id, fullName, dob,
//                   createdAt, photoUrl }] }
//             200 { "ok": true }
//   Failure:  <status> { "error": { "code": string, "message": string } }
//     400 invalid_embedding | bad_request
//     404 not_found
//     500 config_error | 502 upstream_failure
//
// face_enrollments has RLS enabled with ZERO policies (a deliberate deviation
// from the house USING (true) pattern — the rows hold face embeddings), and
// the face-samples bucket is private with no storage policy. Both are
// reachable only from this function via the service-role key, same raw
// PostgREST convention as ../email-otp/index.ts and ../push/index.ts. The
// match threshold (MATCH_THRESHOLD) lives only in this file.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, errorResponse, jsonResponse } from "../ai/_shared.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MATCH_THRESHOLD = 0.5; // cosine >= this counts as a face match
const SIGN_TTL_SECONDS = 3600; // signed photo URLs expire after 1 hour

function configOk(): boolean {
  return Boolean(SUPABASE_URL && SERVICE_ROLE_KEY);
}

// ── Service-role clients (§ house pattern: raw fetch, no SDK) ───────────────

interface CallInit {
  method?: string;
  headers?: Record<string, string>;
  body?: BodyInit;
}

function serviceHeaders(): Record<string, string> {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  };
}

// PostgREST: network error or non-2xx throws { status: 502, code:
// "upstream_failure" }; every call here is required.
async function rest(path: string, init: CallInit = {}): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      ...init,
      headers: { ...serviceHeaders(), ...init.headers },
    });
  } catch (e) {
    console.error(`face-match rest request failed: ${String(e)}`);
    throw Object.assign(new Error("Supabase request failed"), {
      status: 502,
      code: "upstream_failure",
    });
  }
  if (!res.ok) {
    console.error(`face-match rest status=${res.status}`);
    throw Object.assign(new Error(`Supabase request failed (${res.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }
  return res;
}

// Storage API: only network errors throw; the caller inspects status,
// because signing/deleting a missing object must degrade, not fail.
async function storageFetch(
  path: string,
  init: CallInit = {},
): Promise<Response> {
  try {
    return await fetch(`${SUPABASE_URL}/storage/v1/${path}`, {
      ...init,
      headers: { ...serviceHeaders(), ...init.headers },
    });
  } catch (e) {
    console.error(`face-match storage request failed: ${String(e)}`);
    throw Object.assign(new Error("Storage request failed"), {
      status: 502,
      code: "upstream_failure",
    });
  }
}

// ── Face math ────────────────────────────────────────────────────────────────

function validEmbedding(v: unknown): v is number[] {
  return (
    Array.isArray(v) &&
    v.length >= 32 &&
    v.length <= 2048 &&
    v.every((x) => typeof x === "number" && Number.isFinite(x))
  );
}

// Cosine similarity; zero norm or dimension mismatch → 0.
function cosine(a: number[], b: number[]): number {
  if (a.length !== b.length) return 0;
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

function base64ToBytes(b64: string): ArrayBuffer {
  // Tolerate an accidental "data:<mime>;base64," prefix.
  const raw = atob(b64.replace(/^data:[^,]+,/, ""));
  const bytes = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

function normalizeName(v: unknown): string {
  return typeof v === "string" ? v.trim().toLowerCase() : "";
}

// ── Actions ──────────────────────────────────────────────────────────────────

interface EnrollmentRow {
  id: string;
  full_name: string;
  full_name_normalized: string;
  dob: string;
  embedding: number[];
  photo_path: string;
  created_at: string;
}

async function handleEnroll(body: Record<string, unknown>): Promise<Response> {
  const fullName = typeof body.fullName === "string" ? body.fullName.trim() : "";
  const dob = typeof body.dob === "string" ? body.dob.trim() : "";
  const photoBase64 = typeof body.photoBase64 === "string" ? body.photoBase64 : "";
  const enrolledBy =
    typeof body.enrolledBy === "string" && body.enrolledBy.trim() !== ""
      ? body.enrolledBy.trim()
      : null;

  if (!fullName) {
    return errorResponse(400, "bad_request", '"fullName" is required');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dob)) {
    return errorResponse(400, "bad_request", '"dob" must be "YYYY-MM-DD"');
  }
  if (!validEmbedding(body.embedding)) {
    return errorResponse(
      400,
      "invalid_embedding",
      "embedding must be an array of 32..2048 finite numbers",
    );
  }
  if (!photoBase64) {
    return errorResponse(400, "bad_request", '"photoBase64" is required');
  }

  let photoBytes: ArrayBuffer;
  try {
    photoBytes = base64ToBytes(photoBase64);
  } catch {
    return errorResponse(400, "bad_request", "photoBase64 is not valid base64");
  }

  const photoPath = `enrollments/${crypto.randomUUID()}.png`;
  const upload = await storageFetch(`face-samples/${photoPath}`, {
    method: "POST",
    headers: { "Content-Type": "image/png" },
    body: new Blob([photoBytes]),
  });
  if (!upload.ok) {
    console.error(`face-match photo upload status=${upload.status}`);
    throw Object.assign(new Error(`Photo upload failed (${upload.status})`), {
      status: 502,
      code: "upstream_failure",
    });
  }

  // Client already normalizes the name; the server re-normalizes defensively.
  const inserted = (await rest("face_enrollments", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({
      full_name: fullName,
      full_name_normalized: fullName.toLowerCase(),
      dob,
      embedding: body.embedding,
      photo_path: photoPath,
      enrolled_by: enrolledBy,
    }),
  })).json() as { id?: string };
  if (!inserted.id) {
    throw Object.assign(new Error("Enrollment insert returned no id"), {
      status: 502,
      code: "upstream_failure",
    });
  }
  console.log(`face-match action=enroll name=${fullName}`);
  return jsonResponse(200, { ok: true, enrollmentId: inserted.id });
}

async function handleVerify(body: Record<string, unknown>): Promise<Response> {
  const normalized = normalizeName(body.fullName);
  if (!normalized) {
    return errorResponse(400, "bad_request", '"fullName" is required');
  }
  if (!validEmbedding(body.embedding)) {
    return errorResponse(
      400,
      "invalid_embedding",
      "embedding must be an array of 32..2048 finite numbers",
    );
  }
  const embedding = body.embedding as number[];

  // Every row with that normalized name is a candidate (father/son): the
  // best score wins.
  const rows = (await (
    await rest(
      `face_enrollments?full_name_normalized=eq.${encodeURIComponent(normalized)}&select=id,embedding`,
    )
  ).json()) as Array<{ id: string; embedding: unknown }>;

  if (!Array.isArray(rows) || rows.length === 0) {
    console.log(`face-match action=verify name=${normalized} matched=false`);
    return jsonResponse(200, {
      ok: true,
      matched: false,
      score: 0,
      reason: "not_enrolled",
    });
  }

  let bestScore = cosine(embedding, Array.isArray(rows[0].embedding) ? rows[0].embedding as number[] : []);
  let bestId = rows[0].id;
  for (let i = 1; i < rows.length; i++) {
    const score = cosine(embedding, Array.isArray(rows[i].embedding) ? rows[i].embedding as number[] : []);
    if (score > bestScore) {
      bestScore = score;
      bestId = rows[i].id;
    }
  }
  const matched = bestScore >= MATCH_THRESHOLD;
  console.log(`face-match action=verify name=${normalized} matched=${matched} score=${bestScore.toFixed(4)}`);
  return jsonResponse(200, {
    ok: true,
    matched,
    score: bestScore,
    enrollmentId: bestId,
  });
}

// 1-hour signed URL for a photo; broken/missing object → null, never an
// error (the list still returns the other rows).
async function signedPhotoUrl(photoPath: string): Promise<string | null> {
  try {
    const res = await storageFetch(`object/sign/face-samples/${photoPath}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ expiresIn: SIGN_TTL_SECONDS }),
    });
    if (!res.ok) {
      console.error(`face-match photo sign status=${res.status}`);
      return null;
    }
    const data = (await res.json()) as { signedURL?: string };
    if (!data.signedURL) return null;
    return data.signedURL.startsWith("http")
      ? data.signedURL
      : `${SUPABASE_URL}/storage/v1${data.signedURL}`;
  } catch {
    return null;
  }
}

async function handleList(): Promise<Response> {
  const rows = (await (
    await rest(
      "face_enrollments?select=id,full_name,dob,photo_path,created_at&order=created_at.desc",
    )
  ).json()) as EnrollmentRow[];

  const enrollments: Array<{
    id: string;
    fullName: string;
    dob: string;
    createdAt: string;
    photoUrl: string | null;
  }> = [];
  for (const row of rows) {
    enrollments.push({
      id: row.id,
      fullName: row.full_name,
      dob: row.dob,
      createdAt: row.created_at,
      photoUrl: await signedPhotoUrl(row.photo_path),
    });
  }
  return jsonResponse(200, { ok: true, enrollments });
}

async function handleDelete(body: Record<string, unknown>): Promise<Response> {
  const id = typeof body.id === "string" ? body.id.trim() : "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    return errorResponse(400, "bad_request", '"id" must be a uuid');
  }

  // Read first so we know the photo to clean up and whether the row exists.
  const rows = (await (
    await rest(`face_enrollments?id=eq.${encodeURIComponent(id)}&select=photo_path`)
  ).json()) as Array<{ photo_path: string }>;
  if (!Array.isArray(rows) || rows.length === 0) {
    return errorResponse(404, "not_found", "No enrollment with that id");
  }

  await rest(`face_enrollments?id=eq.${encodeURIComponent(id)}`, {
    method: "DELETE",
  });

  // Best-effort: an orphaned photo in a private bucket is harmless; a failed
  // row delete is not. Never fail the request over the photo cleanup.
  try {
    const res = await storageFetch(`object/face-samples/${rows[0].photo_path}`, {
      method: "DELETE",
    });
    if (!res.ok) {
      console.error(`face-match photo delete status=${res.status}`);
    }
  } catch (e) {
    console.error(`face-match photo delete failed: ${String(e)}`);
  }

  console.log(`face-match action=delete id=${id}`);
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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "bad_request", "Body must be valid JSON");
  }

  try {
    if (body.action === "enroll") {
      return await handleEnroll(body);
    }
    if (body.action === "verify") {
      return await handleVerify(body);
    }
    if (body.action === "list") {
      return await handleList();
    }
    if (body.action === "delete") {
      return await handleDelete(body);
    }
    return errorResponse(
      400,
      "bad_request",
      '"action" must be "enroll", "verify", "list" or "delete"',
    );
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    console.error(`face-match failed: ${err.code ?? "unknown"}`);
    return errorResponse(
      err.status ?? 502,
      err.code ?? "upstream_failure",
      err.message ?? "Face match request failed",
    );
  }
});