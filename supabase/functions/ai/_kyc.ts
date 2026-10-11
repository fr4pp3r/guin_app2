// Shared KYC primitives for the `id-verifier` AI task.
//
// One Gemini call inspects the registrant's uploaded government ID (front, plus
// back when the ID has two sides) and their live selfie, and answers four
// questions: "does this look like a genuine ID of the DECLARED type", "what
// document is it really", "does the selfie look like a live capture", and "is
// the capture usable" — plus a field-consistency pass against the submitted
// registration form. The vocabulary, payload validation and defensive coercion
// live here so a handler never diverges from the frozen contract.
//
// There is deliberately NO face-match check: the selfie is never compared to the
// face printed on the ID (see handlers/id_verifier.ts).
//
// Conventions mirror _shared.ts: strict validation with errorResponse-ready
// messages, and every model-supplied value coerced to a safe default instead
// of trusted. Handlers import from here the same way they import callGemini.

// Images travel as base64 strings and go straight to Gemini as inline_data
// parts, so they never touch disk or a log line. A data: URL wrapper from the
// client is tolerated; the payload contract is plain base64.
export const DEFAULT_MIME_TYPE = "image/jpeg";
export const MAX_IMAGE_BYTES = 700_000;
export const MAX_TEXT_LENGTH = 200;

// ID types a registrant may present. Registration accepts ANY valid government
// ID — this is the canonical enum and must stay in sync with the CHECK
// constraint on users_profile.kyc_id_type.
export const ID_TYPES = [
  "barangay_id",
  "drivers_license",
  "passport",
  "national_id",
  "umid",
  "prc",
  "sss",
  "philhealth",
  "postal_id",
  "voters_id",
  "other",
] as const;
export type IdType = typeof ID_TYPES[number];

// Human-readable name of each ID type, used in the prompt so the model knows
// which document it is supposed to be looking at.
export const ID_TYPE_LABELS: Record<IdType, string> = {
  barangay_id: "barangay ID",
  drivers_license: "driver's license",
  passport: "passport",
  national_id: "national ID (PhilSys)",
  umid: "UMID",
  prc: "PRC ID",
  sss: "SSS ID",
  philhealth: "PhilHealth ID",
  postal_id: "postal ID",
  voters_id: "voter's ID",
  other: "government-issued ID",
};

// Verdict on whether the uploaded document is a plausible genuine ID of the
// DECLARED type. 'unreadable' is kept apart from 'uncertain' on purpose: an
// unreadable capture is a capture problem (re-shoot), not an authenticity
// problem, and a reviewer should read the two differently.
export const AUTHENTICITY = [
  "authentic",
  "suspicious",
  "unreadable",
  "uncertain",
] as const;
export type Authenticity = typeof AUTHENTICITY[number];

// Usability of the selfie capture. 'no_face' means the frame contains no
// usable face at all (camera pointed away, occluded, motion-blurred).
export const SELFIE_QUALITIES = [
  "good",
  "poor",
  "no_face",
  "uncertain",
] as const;
export type SelfieQuality = typeof SELFIE_QUALITIES[number];

// Per-form-field consistency verdict. 'unverifiable' means the field could not
// be read on the document at all, which is not a mismatch.
export const FIELD_CHECK_VERDICTS = [
  "match",
  "mismatch",
  "unverifiable",
] as const;
export type FieldCheckVerdict = typeof FIELD_CHECK_VERDICTS[number];

// Form fields the model is asked to cross-check against the ID.
export const FORM_FIELD_KEYS = [
  "full_name",
  "date_of_birth",
  "address",
  "gender",
] as const;

// Passive anti-spoof signal — NOT a proof of liveness. The model sees still
// images, so it can flag screen moiré, screen bezels, printed-photo texture
// and cutout faces, but it cannot watch a blink or a head turn. 'uncertain' is
// the honest default.
export const SPOOF_SIGNALS = [
  "live_looking",
  "spoof_suspected",
  "uncertain",
] as const;
export type SpoofSignal = typeof SPOOF_SIGNALS[number];

// The only two recommendations this feature can ever emit. Both are ADVISORY:
// registration is always manually reviewed, so there is no approve/reject
// verdict anywhere in this contract.
export const RECOMMENDATIONS = ["looks_ok", "needs_review"] as const;
export type Recommendation = typeof RECOMMENDATIONS[number];

export interface B64Image {
  key: string;
  mimeType: string;
  data: string;
}

type DecodeResult =
  | { ok: true; mimeType: string; data: string }
  | { ok: false; message: string };

function decodeImage(
  value: unknown,
  field: string,
  optional: boolean,
): DecodeResult {
  if (value === undefined || value === null) {
    return optional
      ? { ok: false, message: "" }
      : { ok: false, message: `"${field}" must be a non-empty string` };
  }
  if (typeof value !== "string") {
    return { ok: false, message: `"${field}" must be a non-empty string` };
  }
  let trimmed = value.trim();
  if (trimmed.length === 0) {
    return optional
      ? { ok: false, message: "" }
      : { ok: false, message: `"${field}" must be a non-empty string` };
  }
  let mimeType = DEFAULT_MIME_TYPE;
  const dataUrl = /^data:([^;,]+)(;[^,]*)?,/i.exec(trimmed);
  if (dataUrl) {
    const declared = dataUrl[1].trim().toLowerCase();
    if (declared.length > 0) mimeType = declared;
    trimmed = trimmed.slice(dataUrl[0].length);
  }
  const base64 = trimmed.replace(/\s+/g, "");
  if (base64.length === 0) {
    return optional
      ? { ok: false, message: "" }
      : { ok: false, message: `"${field}" must be a non-empty string` };
  }
  let bytes = 0;
  try {
    // atob() throws on invalid base64 and yields one char per decoded byte.
    bytes = atob(base64).length;
  } catch {
    return { ok: false, message: `"${field}" must be a valid base64 string` };
  }
  if (bytes > MAX_IMAGE_BYTES) {
    return {
      ok: false,
      message: `"${field}" must decode to at most ${MAX_IMAGE_BYTES} bytes`,
    };
  }
  return { ok: true, mimeType, data: base64 };
}

export interface ImageSlot {
  key: string;
  /** Single-sided IDs (passports, front-only cards) legitimately have no back
   *  image; an absent optional slot is not a validation error. */
  optional?: boolean;
}

export type DecodedImages =
  | { ok: true; images: B64Image[] }
  | { ok: false; message: string };

/** Decodes the payload images in slot order. Every non-optional slot must be
 *  present, non-empty, base64 and within the size cap; optional slots are
 *  skipped when absent. The returned order is the order Gemini receives. */
export function decodeImages(
  payload: Record<string, unknown>,
  slots: readonly ImageSlot[],
): DecodedImages {
  const images: B64Image[] = [];
  for (const slot of slots) {
    const decoded = decodeImage(payload[slot.key], slot.key, !!slot.optional);
    if (decoded.ok) {
      images.push({ key: slot.key, mimeType: decoded.mimeType, data: decoded.data });
      continue;
    }
    if (decoded.message.length > 0) {
      return { ok: false, message: decoded.message };
    }
    // Absent optional slot: nothing to send for that side.
  }
  return { ok: true, images };
}

export function hasImage(images: B64Image[], key: string): boolean {
  return images.some((image) => image.key === key);
}

export function coerceEnum<T extends string>(
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

// Extracted / reason strings are transient and never guessed by the model,
// so anything missing or non-string collapses to null.
export function coerceText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  return trimmed.slice(0, MAX_TEXT_LENGTH);
}

export function coerceStringList(value: unknown): string[] {
  const items: string[] = [];
  if (Array.isArray(value)) {
    for (const item of value) {
      const text = coerceText(item);
      if (text !== null) items.push(text);
    }
  }
  return items;
}

export function coerceRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export interface Liveness {
  spoofSignal: SpoofSignal;
  notes: string | null;
}

/** Wraps the model's passive anti-spoof read. A missing or malformed block
 *  becomes 'uncertain' — never a silent 'live_looking'. */
export function coerceLiveness(value: unknown): Liveness {
  const obj = coerceRecord(value);
  return {
    spoofSignal: coerceEnum(obj.spoof_signal, SPOOF_SIGNALS, "uncertain"),
    notes: coerceText(obj.notes),
  };
}

/** Keeps only the form-field keys the model is allowed to grade, each coerced
 *  to a [FieldCheckVerdict]; anything else (unknown key, wrong type, empty
 *  value) is dropped so the stored map never grows an unexpected shape. */
export function coerceFieldChecks(value: unknown): Record<string, FieldCheckVerdict> {
  const obj = coerceRecord(value);
  const checks: Record<string, FieldCheckVerdict> = {};
  for (const key of FORM_FIELD_KEYS) {
    if (!(key in obj)) continue;
    checks[key] = coerceEnum(
      obj[key],
      FIELD_CHECK_VERDICTS,
      "unverifiable",
    );
  }
  return checks;
}

export interface AdvisoryInput {
  authenticity: Authenticity;
  idTypeMatch: boolean;
  selfieQuality: SelfieQuality;
  spoofSignal: SpoofSignal;
}

/**
 * The single deterministic rule behind `recommendation`. It is computed in
 * code, never taken from the model, and both of its outcomes are ADVISORY:
 * registration is always manually reviewed by a captain, so 'looks_ok' is a
 * hint that the capture looks clean — never an approval, and never a rejection.
 * Anything less than a confident, type-matching, spoof-free read (including
 * every coerced 'uncertain') reads as 'needs_review'.
 */
export function looksOk(input: AdvisoryInput): boolean {
  return input.authenticity === "authentic" &&
    input.idTypeMatch &&
    input.selfieQuality === "good" &&
    input.spoofSignal === "live_looking";
}

/** Error message for a missing/unknown `id_type`. */
export function idTypeError(field: string): string {
  return `"${field}" must be one of: ${ID_TYPES.join(", ")}`;
}

/** Validates the declared ID type and returns it normalized. */
export function normalizeIdType(
  value: unknown,
  field: string,
): { ok: true; idType: IdType } | { ok: false; message: string } {
  if (typeof value !== "string") {
    return { ok: false, message: idTypeError(field) };
  }
  const normalized = value.trim().toLowerCase();
  for (const option of ID_TYPES) {
    if (option === normalized) return { ok: true, idType: option };
  }
  return { ok: false, message: idTypeError(field) };
}