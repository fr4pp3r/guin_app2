// Handler for the `document-processor` AI task.
//
// Validates/normalizes a barangay document request's purpose + documentData
// using Gemini. Always defensive: malformed/ambiguous model output is
// normalized to safe defaults, upstream failures surface as structured
// errors, and the prompt contents are never logged.

import {
  callGemini,
  errorResponse,
  jsonResponse,
} from "../_shared.ts";

const DOCUMENT_TYPES = [
  "barangay_clearance",
  "indigency",
  "barangay_id",
  "cedula",
] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    issues: { type: "array", items: { type: "string" } },
    suggestions: { type: "object" },
    normalizedPurpose: { type: "string" },
  },
  required: ["issues", "suggestions", "normalizedPurpose"],
};

export async function documentProcessor(
  payload: Record<string, unknown>,
): Promise<Response> {
  const documentType = typeof payload.documentType === "string"
    ? payload.documentType.trim()
    : "";
  const purpose = typeof payload.purpose === "string" ? payload.purpose : "";
  const documentData =
    payload.documentData && typeof payload.documentData === "object" &&
      !Array.isArray(payload.documentData)
      ? payload.documentData as Record<string, unknown>
      : null;

  if (documentType.length === 0) {
    return errorResponse(400, "bad_request", '"documentType" must be a non-empty string');
  }
  if (typeof payload.purpose !== "string") {
    return errorResponse(400, "bad_request", '"purpose" must be a string');
  }
  if (documentData === null) {
    return errorResponse(400, "bad_request", '"documentData" must be an object');
  }

  let documentDataJson = "{}";
  try {
    documentDataJson = JSON.stringify(documentData).slice(0, 4000);
  } catch {
    return errorResponse(400, "bad_request", '"documentData" must be JSON-serializable');
  }

  const prompt = [
    "You are validating a barangay document request for a Philippine local government unit.",
    `The document type must be one of: ${DOCUMENT_TYPES.join(", ")}.`,
    "You receive the requested documentType, purpose, and documentData (JSON).",
    "",
    "Return a JSON object with exactly three fields:",
    "- issues: array of plain-language strings describing semantic problems the citizen would want to fix before the request is processed (e.g. vague purpose, names or addresses that look inconsistent with each other, data that does not fit the document type). Empty array if nothing is wrong.",
    "- suggestions: object mapping a field name to a corrected value (string) for fields worth fixing. Empty object if nothing needs fixing.",
    "- normalizedPurpose: a cleaned-up version of the purpose, at least 5 characters, or an empty string if the purpose is unclear.",
    "",
    "Rules:",
    "- Do NOT invent required fields beyond what is provided in documentData.",
    "- Do NOT fabricate personal information.",
    "- If nothing is wrong, return an empty issues array, an empty suggestions object, and a normalizedPurpose (empty string only if the purpose is unclear).",
    "- Be concise and practical. Do not include any text outside the JSON.",
    "",
    `documentType: ${documentType.slice(0, 100)}`,
    `purpose: ${purpose.slice(0, 1000)}`,
    `documentData: ${documentDataJson}`,
  ].join("\n");

  let raw: unknown;
  try {
    raw = await callGemini(prompt, { responseSchema: RESPONSE_SCHEMA });
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

  const issues: string[] = [];
  if (Array.isArray(obj.issues)) {
    for (const item of obj.issues) {
      if (typeof item === "string" && item.trim().length > 0) {
        issues.push(item);
      }
    }
  }

  const suggestions: Record<string, string> = {};
  if (typeof obj.suggestions === "object" && obj.suggestions !== null &&
      !Array.isArray(obj.suggestions)) {
    for (const [key, value] of Object.entries(
      obj.suggestions as Record<string, unknown>,
    )) {
      if (typeof value === "string") {
        suggestions[key] = value;
      }
    }
  }

  const normalizedPurpose = typeof obj.normalizedPurpose === "string"
    ? obj.normalizedPurpose
    : "";

  return jsonResponse(200, { result: { issues, suggestions, normalizedPurpose } });
}

// Router lookup derives the module export name from the task name
// (kebab-case -> snake_case). Provide both shapes, plus a default.
export { documentProcessor as document_processor };
export default documentProcessor;
