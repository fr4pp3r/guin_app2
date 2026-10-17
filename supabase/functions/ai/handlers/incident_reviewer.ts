// Handler for the `incident-reviewer` AI task.
//
// Generates an analysis and review of a barangay incident report.
// Returns structured analysis covering: summary, risk level, review notes,
// suggested next steps, and whether escalation is recommended.
// Always defensive: malformed model output is normalized to safe defaults,
// upstream failures surface as structured errors, and prompt contents are never logged.

import {
  callGemini,
  errorResponse,
  jsonResponse,
} from "../_shared.ts";

const RISK_LEVELS = ["low", "moderate", "high", "critical"] as const;
const ESCALATION = ["yes", "no", "review"] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    summary: { type: "string" },
    riskLevel: { type: "string", enum: [...RISK_LEVELS] },
    escalationRecommended: { type: "string", enum: [...ESCALATION] },
    reviewNotes: { type: "string" },
    suggestedNextSteps: {
      type: "array",
      items: { type: "string" },
      minItems: 0,
      maxItems: 5,
    },
  },
  required: ["summary", "riskLevel", "escalationRecommended", "reviewNotes"],
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

export async function incidentReviewer(
  payload: Record<string, unknown>,
): Promise<Response> {
  const title = typeof payload.title === "string" ? payload.title : "";
  const description =
    typeof payload.description === "string" ? payload.description : "";
  const location = typeof payload.location === "string" ? payload.location : "";
  const reportType =
    typeof payload.reportType === "string" ? payload.reportType : "";
  const priority = typeof payload.priority === "string" ? payload.priority : "";
  const isSensitive =
    typeof payload.isSensitive === "boolean" ? payload.isSensitive : false;
  const isAnonymous =
    typeof payload.isAnonymous === "boolean" ? payload.isAnonymous : false;

  if (title.trim().length === 0 && description.trim().length === 0) {
    return errorResponse(
      400,
      "bad_request",
      '"title" and "description" cannot both be empty',
    );
  }

  const prompt = [
    "You are an AI analyst for a Philippine barangay incident review desk.",
    "Analyze and review the incident report below. Provide a practical, neutral, and safety-conscious assessment.",
    "",
    "Output requirements (JSON ONLY):",
    "- summary: one sentence (<=150 chars) summarizing the report",
    "- riskLevel: one of low, moderate, high, critical (use critical only for imminent life-threatening danger)",
    "- escalationRecommended: one of yes, no, review",
    "- reviewNotes: 1-2 sentences (<=300 chars) with analysis/review",
    "- suggestedNextSteps: array of 0-5 short bullet items (each <=80 chars)",
    "",
    "Guidelines:",
    "- Be factual, avoid speculation beyond what is stated.",
    "- For minor disputes use low/moderate; for threats to safety use high; immediate danger = critical.",
    "- If unclear, choose the safer review flag ('review') for escalationRecommended.",
    "- Never include PII beyond what is provided; respect anonymity.",
    "- Do not include any text outside the JSON object.",
    "",
    `Report type: ${reportType}`,
    `Priority: ${priority}`,
    `Title: ${title.slice(0, 500)}`,
    `Description: ${description.slice(0, 4000)}`,
    `Location: ${location.slice(0, 500)}`,
    `Sensitive: ${isSensitive}`,
    `Anonymous: ${isAnonymous}`,
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
  const summary =
    typeof obj.summary === "string" && obj.summary.trim().length > 0
      ? obj.summary.trim().slice(0, 150)
      : "AI analysis generated for this incident report.";
  const riskLevel = coerceEnum(obj.riskLevel, RISK_LEVELS, "low");
  const escalationRecommended = coerceEnum(
    obj.escalationRecommended,
    ESCALATION,
    "review",
  );
  let reviewNotes =
    typeof obj.reviewNotes === "string" && obj.reviewNotes.trim().length > 0
      ? obj.reviewNotes.trim()
      : "No additional review notes.";
  if (reviewNotes.length > 300) {
    reviewNotes = `${reviewNotes.slice(0, 297)}...`;
  }

  let suggestedNextSteps: string[] = [];
  if (Array.isArray(obj.suggestedNextSteps)) {
    for (const s of obj.suggestedNextSteps) {
      if (typeof s === "string" && s.trim().length > 0) {
        suggestedNextSteps.push(s.trim().slice(0, 80));
        if (suggestedNextSteps.length >= 5) break;
      }
    }
  }

  return jsonResponse(200, {
    result: {
      summary,
      riskLevel,
      escalationRecommended,
      reviewNotes,
      suggestedNextSteps,
    },
  });
}

// Router compatibility (kebab-case task -> snake_case module export)
export { incidentReviewer as incident_reviewer };
export default incidentReviewer;
