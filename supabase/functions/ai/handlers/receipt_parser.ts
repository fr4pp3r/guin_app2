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

export async function receiptParser(
  payload: Record<string, unknown>,
): Promise<Response> {
  const images = decodeImages(payload, IMAGE_SLOTS);
  if (!hasImage(images, "receipt_b64")) {
    return errorResponse("missing_receipt", "receipt_b64 is required");
  }

  const expectedAmount = typeof payload.expectedAmount === "number"
    ? payload.expectedAmount
    : (typeof payload.expected_amount === "number" ? payload.expected_amount : undefined);

  const contents = [
    {
      role: "user",
      parts: [
        { text: buildPrompt(expectedAmount) },
        { inline_data: { mime_type: "image/png", data: (images.receipt_b64 as B64Image).data } },
      ],
    },
  ];

  const geminiResult = await callGemini({
    systemInstruction: SYSTEM_PROMPT,
    contents,
    responseSchema: RESPONSE_SCHEMA,
    temperature: 0,
  });

  if (!geminiResult.ok) {
    return errorResponse(geminiResult.error.code, geminiResult.error.message);
  }

  return jsonResponse({
    result: geminiResult.data,
    meta: {
      prompt_version: PROMPT_VERSION,
      image_count: 1,
    },
  });
}

export default receiptParser;
