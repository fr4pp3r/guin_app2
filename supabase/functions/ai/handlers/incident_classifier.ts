// Handler for the `incident-classifier` AI task.
//
// Classifies a barangay incident report into reportType + priority using
// Gemini. Always defensive: malformed/ambiguous model output is normalized
// to safe defaults, upstream failures surface as structured errors, and the
// prompt contents are never logged.

import {
  callGemini,
  errorResponse,
  jsonResponse,
} from "../_shared.ts";

const REPORT_TYPES = ["complaint", "disturbance", "threat", "emergency", "other"] as const;
const PRIORITIES = ["low", "normal", "high", "urgent"] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    reportType: { type: "string", enum: [...REPORT_TYPES] },
    priority: { type: "string", enum: [...PRIORITIES] },
    rationale: { type: "string" },
  },
  required: ["reportType", "priority", "rationale"],
};

function coerceEnum<T extends string>(
  value: unknown,
  allowed: readonly T[],
  fallback: T,
): T {
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    for (const option of allowed) {
      if (option === normalized) return option;
    }
  }
  return fallback;
}

export async function incidentClassifier(
  payload: Record<string, unknown>,
): Promise<Response> {
  const title = typeof payload.title === "string" ? payload.title : "";
  const description =
    typeof payload.description === "string" ? payload.description : "";

  if (title.trim().length === 0 && description.trim().length === 0) {
    return errorResponse(
      400,
      "bad_request",
      '"title" and "description" cannot both be empty',
    );
  }

  const prompt = [
    "You are a classifier for a Philippine barangay incident reporting system.",
    "Classify the incident report below into exactly one reportType and one priority.",
    "",
    "Allowed reportType values: complaint, disturbance, threat, emergency, other.",
    "Allowed priority values: low, normal, high, urgent.",
    "",
    "Rules:",
    "- Return ONLY these exact values for reportType and priority, never invent new ones.",
    "- If the report is unclear, ambiguous, or does not fit any category, use reportType \"other\" and priority \"normal\".",
    "- Use \"urgent\" only for immediate danger to life or property; \"high\" for serious but not immediate threats; \"low\" for minor, non-urgent concerns.",
    "- rationale must be a single short sentence, at most ~150 characters, explaining the choice in plain language.",
    "- Do not include any text outside the JSON object.",
    "",
    `Title: ${title.slice(0, 500)}`,
    `Description: ${description.slice(0, 4000)}`,
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
  const reportType = coerceEnum(obj.reportType, REPORT_TYPES, "other");
  const priority = coerceEnum(obj.priority, PRIORITIES, "normal");
  let rationale =
    typeof obj.rationale === "string" && obj.rationale.trim().length > 0
      ? obj.rationale.trim()
      : "Defaulted to a safe classification.";
  if (rationale.length > 200) {
    rationale = `${rationale.slice(0, 197)}...`;
  }

  return jsonResponse(200, { result: { reportType, priority, rationale } });
}

// Router lookup derives the module export name from the task name
// (kebab-case -> snake_case). Provide both shapes, plus a default.
export { incidentClassifier as incident_classifier };
export default incidentClassifier;
