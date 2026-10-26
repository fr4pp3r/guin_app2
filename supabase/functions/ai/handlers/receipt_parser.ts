// Handler for the `receipt-parser` AI task.
// Extracts GCash payment details from a receipt/screenshot.
// Only extracts reference number, amount, date. Never names/phone numbers.
// Advisory only — treasurer must confirm.

import {
  callGemini,
  errorResponse,
  jsonResponse,
} from "../_shared.ts";
import { decodeImages, hasImage, type B64Image } from "../_kyc.ts";

const PROMPT_VERSION = "v1";

const IMAGE_SLOTS = [
  { key: "receipt_b64" },
] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    referenceNumber: { type: "string" },
    amount: { type: "number" },
    date: { type: "string" },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    ambiguous: { type: "boolean" },
  },
  required: ["referenceNumber", "amount", "date", "confidence", "ambiguous"],
};

const SYSTEM_PROMPT =
  "You extract ONLY payment fields from a GCash receipt screenshot. " +
  "Never extract names, phone numbers, GCash numbers, emails, addresses, or other PII. " +
  "Return the SINGLE transaction if multiple appear; if genuinely ambiguous, set ambiguous=true. " +
  "Normalize referenceNumber: strip spaces/dashes, uppercase. " +
  "Currency is PHP only. amount is a number (no currency symbol). " +
  "date should be ISO 8601 (YYYY-MM-DD) in PHT (UTC+8) if ambiguous, infer from receipt; else best guess. " +
  "confidence 0-1. Return JSON only.";

const USER_PROMPT =
  "Look for GCash transaction details. Focus on: Ref No./Reference Number (10-20 chars typical), " +
  "Gross/Total/Amount Paid in PHP, Transaction Date/Time (PHT). " +
  "If multiple transactions visible, pick the one matching the expected amount if provided. " +
  "If cannot read clearly, return low confidence but best guess; set ambiguous true if unsure which txn.";

function buildPrompt(expectedAmount?: number): string {
  let p = USER_PROMPT;
  if (typeof expectedAmount === "number" && !isNaN(expectedAmount)) {
    p += ` Expected amount: PHP ${expectedAmount.toFixed(2)}.`;
  }
  return p;
}

async function receiptParser(
  payload: Record<string, unknown>,
): Promise<Response> {
  // decodeImages returns a discriminated union and decodes in slot order; a
  // non-optional slot that is missing or malformed comes back as ok:false with
  // a caller-safe message, so no separate hasImage() probe is needed.
  const decoded = decodeImages(payload, IMAGE_SLOTS);
  if (!decoded.ok) {
    return errorResponse(400, "bad_request", decoded.message);
  }
  const images: B64Image[] = decoded.images;
  if (!hasImage(images, "receipt_b64")) {
    return errorResponse(400, "bad_request", '"receipt_b64" is required');
  }
  const receipt = images.find((image) => image.key === "receipt_b64");

  const expectedAmount = typeof payload.expectedAmount === "number"
    ? payload.expectedAmount
    : (typeof payload.expected_amount === "number" ? payload.expected_amount : undefined);

  const prompt = `${SYSTEM_PROMPT}\n\n${buildPrompt(expectedAmount)}`;

  let raw: unknown;
  try {
    raw = await callGemini(prompt, {
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0,
      images: receipt
        ? [{ mime_type: receipt.mimeType, data: receipt.data }]
        : [],
    });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    return errorResponse(
      typeof err.status === "number" ? err.status : 502,
      typeof err.code === "string" ? err.code : "upstream_failure",
      typeof err.message === "string" ? err.message : "AI request failed",
    );
  }

  // Advisory only: whatever cannot be read is reported as null/low confidence
  // rather than guessed, and the treasurer still confirms every payment.
  const obj = (typeof raw === "object" && raw !== null && !Array.isArray(raw))
    ? raw as Record<string, unknown>
    : {};

  return jsonResponse(200, {
    result: {
      referenceNumber: typeof obj.referenceNumber === "string"
        ? obj.referenceNumber
        : "",
      amount: typeof obj.amount === "number" && isFinite(obj.amount)
        ? obj.amount
        : 0,
      date: typeof obj.date === "string" ? obj.date : "",
      // An unusable read can never look confident.
      confidence: typeof obj.confidence === "number" && isFinite(obj.confidence)
        ? Math.min(Math.max(obj.confidence, 0), 1)
        : 0,
      ambiguous: obj.ambiguous !== false,
    },
    meta: {
      prompt_version: PROMPT_VERSION,
      image_count: 1,
    },
  });
}

export default receiptParser;
