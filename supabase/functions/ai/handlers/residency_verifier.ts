// Handler for the `residency-verifier` AI task.
//
// OCRs a utility-bill / secondary-ID image, checks name match against the
// submitted full_name (case-insensitive, partial-match tolerance), and whether
// the address mentions Barangay Poblacion. Returns an advisory verdict that is
// never used to block the user — if the image is unreadable the handler returns
// low confidence and let the human officer decide.
//
// Schema:
//   Input:  { residency_proof_b64: string, full_name: string }
//   Output: { is_confirmed: boolean, address_match: string, notes: string[], confidence: number }

import { callGemini, errorResponse, jsonResponse } from "../_shared.ts";
import { decodeImages, hasImage, type B64Image } from "../_kyc.ts";

const PROMPT_VERSION = "v1";

const IMAGE_SLOTS = [{ key: "residency_proof_b64" }] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    is_confirmed: { type: "boolean" },
    address_match: {
      type: "string",
      enum: ["confirmed", "not_confirmed", "unverifiable"],
    },
    notes: { type: "array", items: { type: "string" } },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
  required: ["is_confirmed", "address_match", "notes", "confidence"],
};

const SYSTEM_PROMPT = [
  "You are a document-extraction assistant for a Philippine barangay (village) system.",
  "The user uploaded a utility bill or secondary ID to prove they live in Barangay Poblacion.",
  "",
  "Your job is to extract two things from the document image:",
  "1. The name on the document.",
  "2. The full residential address on the document.",
  "",
  "Then judge residency for Barangay Poblacion only:",
  "- Report address_match 'confirmed' when the address explicitly mentions Poblacion (e.g. 'Brgy. Poblacion', 'Barangay Poblacion', 'Poblacion, [municipality]').",
  "- Report address_match 'not_confirmed' when the address is legible but clearly names a different barangay.",
  "- Report address_match 'unverifiable' when the address is illegible, missing, or cut off.",
  "",
  "Also compare the extracted name to the provided full_name (case-insensitive, allow partial match). Include one note about the name match in the notes array.",
  "",
  "Return ONLY the JSON object described by the response schema. Never include extra text.",
].join("\n");

export async function residencyVerifier(
  payload: Record<string, unknown>,
): Promise<Response> {
  const decoded = decodeImages(payload, IMAGE_SLOTS);
  if (!decoded.ok) {
    return errorResponse(400, "bad_request", decoded.message);
  }
  const images: B64Image[] = decoded.images;
  if (!hasImage(images, "residency_proof_b64")) {
    return errorResponse(
      400,
      "bad_request",
      '"residency_proof_b64" is required',
    );
  }
  const image = images.find((i) => i.key === "residency_proof_b64")!;

  const fullName = typeof payload.full_name === "string"
    ? payload.full_name.trim()
    : "";

  const prompt = [
    SYSTEM_PROMPT,
    "",
    `Full name provided by user for cross-check: "${fullName}".`,
    "Look at the image and report what you find.",
  ].join("\n");

  let raw: unknown;
  try {
    raw = await callGemini(prompt, {
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0.1,
      images: [{ mime_type: image.mimeType, data: image.data }],
    });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    return errorResponse(
      typeof err.status === "number" ? err.status : 502,
      typeof err.code === "string" ? err.code : "upstream_failure",
      typeof err.message === "string" ? err.message : "AI request failed",
    );
  }

  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return errorResponse(
      502,
      "upstream_failure",
      "AI returned an unusable result",
    );
  }

  const obj = raw as Record<string, unknown>;

  const addressMatchValues = ["confirmed", "not_confirmed", "unverifiable"] as const;
  const addressMatch = (addressMatchValues as readonly string[]).includes(obj.address_match as string)
    ? (obj.address_match as "confirmed" | "not_confirmed" | "unverifiable")
    : "unverifiable";

  const isConfirmed = addressMatch === "confirmed" &&
    (obj.is_confirmed === true);

  const notes: string[] = [];
  if (Array.isArray(obj.notes)) {
    for (const item of obj.notes) {
      if (typeof item === "string" && item.trim().length > 0) {
        notes.push(item.slice(0, 200));
      }
    }
  }

  const confidence = typeof obj.confidence === "number" &&
      isFinite(obj.confidence)
    ? Math.min(Math.max(obj.confidence, 0), 1)
    : 0;

  // Shortcut: when address is unverifiable we clamp confidence low; upgrade only
  // if the model itself signals high certainty — leave final discretion to humans.
  const effectiveConfidence = addressMatch === "unverifiable"
    ? Math.min(confidence, 0.3)
    : confidence;

  return jsonResponse(200, {
    result: {
      is_confirmed: isConfirmed,
      address_match: addressMatch,
      notes,
      confidence: effectiveConfidence,
    },
    meta: { prompt_version: PROMPT_VERSION },
  });
}

// Router lookup derives the module export name from the task name
// (kebab-case -> snake_case). Provide both shapes, plus a default.
export { residencyVerifier as residency_verifier };
export default residencyVerifier;
