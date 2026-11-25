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
const FRAUD_FLAGS = ["no_issues", "likely_fabricated", "definitely_duplicate", "potential_spam", "needs_human_review"] as const;

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
    fraudFlags: {
      type: "array",
      items: { type: "string", enum: [...FRAUD_FLAGS] },
      minItems: 1,
      maxItems: 3,
    },
  },
  required: ["summary", "riskLevel", "escalationRecommended", "reviewNotes", "fraudFlags"],
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
    "- fraudFlags: array of 1-3 flags from: no_issues, likely_fabricated, definitely_duplicate, potential_spam, needs_human_review",
    "  Use 'likely_fabricated' for reports with unrealistic details, conflicting information, or patterns suggesting deliberate falsehoods.",
    "  Use 'definitely_duplicate' for reports that are identical or nearly identical to recent submissions.",
    "  Use 'potential_spam' for repetitive, templated, or clearly automated-looking content.",
    "  Use 'needs_human_review' when fraud cannot be determined from content alone.",
    "  Use 'no_issues' when the report appears legitimate.",
    "",
    "Guidelines:",
    "- Be factual, avoid speculation beyond what is stated.",
    "- For minor disputes use low/moderate; for threats to safety use high; immediate danger = critical.",
    "- If unclear, choose the safer review flag ('review') for escalationRecommended.",
    "- Never include PII beyond what is provided; respect anonymity.",
    "- Scan for signs of fabrication: inconsistent details, impossible timelines, template language, or content that seems staged.",
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

  // Extract fraud flags: default to first plausible option
  let fraudFlags: string[] = ["no_issues"];
  if (Array.isArray(obj.fraudFlags)) {
    const flags: string[] = [];
    for (const f of obj.fraudFlags) {
      if (typeof f === "string" && FRAUD_FLAGS.includes(f as any)) {
        flags.push(f as string);
      }
    }
    if (flags.length > 0) {
      fraudFlags = flags.slice(0, 3);
    }
  }

  return jsonResponse(200, {
    result: {
      summary,
      riskLevel,
      escalationRecommended,
      reviewNotes,
      suggestedNextSteps,
      fraudFlags,
    },
  });
}

// Router compatibility (kebab-case task -> snake_case module export)
export { incidentReviewer as incident_reviewer };
export default incidentReviewer;
