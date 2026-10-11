// Handler for the `id-verifier` AI task.
//
// Advisory ID pre-check for a barangay registration. One Gemini call inspects
// the registrant's uploaded government ID (front, plus back when the ID has two
// sides) and their live selfie:
//
//   (a) ID AUTHENTICITY / plausibility: does the document look like a genuine
//       government ID of the DECLARED type — layout, seal, security features,
//       consistent typography — with no signs of tampering? Registration
//       accepts ANY valid ID (barangay ID, driver's license, passport,
//       national ID, UMID, PRC, SSS, PhilHealth, postal ID, voter's ID, ...),
//       so there is no comparison against a captain-uploaded sample of the same
//       card: no single sample can stand in for an arbitrary ID type.
//   (b) DETECTED TYPE: what the document appears to be on its own merits, and
//       whether that agrees with the declared type.
//   (c) SELFIE QUALITY: is the selfie usable as a capture at all.
//   (d) LIVENESS: a passive anti-spoof signal over the selfie (screen moiré,
//       bezel, print/replay artefacts). Still images cannot prove liveness —
//       it is a signal only.
//   (e) FIELD CONSISTENCY: the ID data against the submitted form fields.
//
// There is deliberately NO face match. The selfie is NEVER compared to the face
// printed on the ID — registration is always manually reviewed, so an advisory
// face comparison would add a biometric judgement the product does not make.
// The prompt must never ask for one either.
//
// Always defensive: malformed/ambiguous model output is normalized to safe
// defaults ('uncertain' -> needs_review), upstream failures surface as
// structured errors, and neither the images nor the prompt contents are
// logged. The recommendation is computed in code, never taken from the model,
// and is ADVISORY ONLY — 'looks_ok' or 'needs_review', never an approval and
// never a rejection.

import {
  AUTHENTICITY,
  coerceEnum,
  coerceFieldChecks,
  coerceLiveness,
  coerceStringList,
  decodeImages,
  FORM_FIELD_KEYS,
  hasImage,
  ID_TYPES,
  ID_TYPE_LABELS,
  looksOk,
  normalizeIdType,
  SELFIE_QUALITIES,
  SPOOF_SIGNALS,
  type B64Image,
} from "../_kyc.ts";
import {
  callGemini,
  errorResponse,
  jsonResponse,
} from "../_shared.ts";

const PROMPT_VERSION = "v5";

const MAX_ADDRESS_LENGTH = 500;

// Image slots in the exact order Gemini receives them. Front and selfie are
// mandatory; the back is optional because single-sided IDs (passports,
// front-only cards) do not have one.
const IMAGE_SLOTS = [
  { key: "id_image_front_b64" },
  { key: "id_image_back_b64", optional: true },
  { key: "selfie_b64" },
] as const;

const RESPONSE_SCHEMA: Record<string, unknown> = {
  type: "object",
  properties: {
    // Plausible genuine ID of the DECLARED type, untampered, data consistent.
    id_authenticity: { type: "string", enum: [...AUTHENTICITY] },
    // What the document appears to be on its own merits; "unknown" when it
    // cannot be identified at all.
    id_type_guess: { type: "string", enum: [...ID_TYPES, "unknown"] },
    // Usability of the selfie capture.
    selfie_quality: { type: "string", enum: [...SELFIE_QUALITIES] },
    // Passive anti-spoof read of the selfie. A signal, not a proof.
    liveness: {
      type: "object",
      properties: {
        spoof_signal: { type: "string", enum: [...SPOOF_SIGNALS] },
        notes: { type: "string", nullable: true },
      },
      required: ["spoof_signal", "notes"],
    },
    // One verdict per registration form field.
    field_checks: {
      type: "object",
      properties: {
        full_name: { type: "string" },
        date_of_birth: { type: "string" },
        address: { type: "string" },
        gender: { type: "string" },
      },
      required: [...FORM_FIELD_KEYS],
    },
    // 2-4 short plain-language notes for the human reviewer.
    reasons: { type: "array", items: { type: "string" } },
  },
  required: [
    "id_authenticity",
    "id_type_guess",
    "selfie_quality",
    "liveness",
    "field_checks",
    "reasons",
  ],
};

const IMAGE_SLOT_LABELS: Record<string, string> = {
  id_image_front_b64: "ID FRONT",
  id_image_back_b64: "ID BACK",
  selfie_b64: "SELFIE",
};

export async function idVerifier(
  payload: Record<string, unknown>,
): Promise<Response> {
  const declared = normalizeIdType(payload.id_type, "id_type");
  if (!declared.ok) {
    return errorResponse(400, "bad_request", declared.message);
  }
  const idType = declared.idType;

  // Front and selfie are mandatory; the back is optional for single-sided IDs.
  const decodedImages = decodeImages(payload, IMAGE_SLOTS);
  if (!decodedImages.ok) {
    return errorResponse(400, "bad_request", decodedImages.message);
  }
  const images = decodedImages.images;
  const idBackPresent = hasImage(images, "id_image_back_b64");

  const formFields = payload.form_fields &&
      typeof payload.form_fields === "object" &&
      !Array.isArray(payload.form_fields)
    ? payload.form_fields as Record<string, unknown>
    : null;
  if (formFields === null) {
    return errorResponse(400, "bad_request", '"form_fields" must be an object');
  }
  const formValue = (key: string): string => {
    const value = formFields[key];
    return typeof value === "string" ? value.trim() : "";
  };
  const formFieldsJson = JSON.stringify({
    full_name: formValue("full_name"),
    date_of_birth: formValue("date_of_birth"),
    address: formValue("address").slice(0, MAX_ADDRESS_LENGTH),
    gender: formValue("gender"),
  });

  // The image list is built from what was actually supplied, so the numbering
  // in the prompt always matches the parts Gemini receives.
  const imageList = images.map((image: B64Image, index: number) =>
    `Image ${index + 1} — ${IMAGE_SLOT_LABELS[image.key]}: ${
      image.key === "selfie_b64"
        ? "a live selfie photograph of the registrant, captured by them in person."
        : `the ${
          IMAGE_SLOT_LABELS[image.key] === "ID BACK" ? "back" : "front"
        } of the registrant's ID.`
    }`
  );

  const prompt = [
    "You are an identity-verification assistant for a Philippine barangay resident registration system.",
    `The registrant declares that the document they uploaded is a ${ID_TYPE_LABELS[idType]}.`,
    `You are given ${images.length} images, in this exact order:`,
    ...imageList,
    idBackPresent
      ? ""
      : "(The ID has only one side in this capture: there is no back image. Its absence is expected and must not by itself lower any verdict.)",
    "",
    "IMPORTANT: a human reviewer makes the final decision on every registration. Your job is to describe what the images show so the reviewer can work faster. Do NOT approve, reject, or decide who the person is.",
    "IMPORTANT: do NOT compare the selfie with the portrait printed on the ID, and do not judge whether the person in the selfie is the same person as the ID holder. Judge the selfie on its own technical quality only.",
    "",
    "Perform these checks and report them separately:",
    `1. ID AUTHENTICITY: does the ID look like a GENUINE ${ID_TYPE_LABELS[idType]} — correct layout and field structure for that document type, official seal or coat of arms, security features such as microtext, guilloche patterns, holographic or colour-shifting marks, and (for a passport) a machine-readable zone — with consistent typography and no signs of tampering such as a spliced photo, mismatched fonts, re-printed text, edited serials, or a layout that does not belong to the declared type? Report "authentic", "suspicious", "unreadable" (the capture itself is too poor to judge) or "uncertain" (you cannot tell).`,
    `2. ID TYPE: independently judge what the document actually is (id_type_guess), choosing from the same list the declared type comes from: ${ID_TYPES.join(", ")}, or "unknown" when you cannot tell. A guess of "unknown", or one that clearly disagrees with the declared type, means id_authenticity cannot be "authentic".`,
    "3. SELFIE QUALITY: grade the selfie capture alone — is it a usable in-person photo with a clearly visible, reasonably lit face? Report \"good\", \"poor\" (blurred, very dark, heavily occluded, extreme angle), \"no_face\" (no usable face in frame) or \"uncertain\".",
    "4. LIVENESS: a passive anti-spoof read of the SELFIE. Look only for what a still image can reveal: screen moiré or pixel-grid patterns, a screen bezel or device edge in frame, printed-photo texture, a cut-out or holes around the face, and re-use of the same picture. Report spoof_signal \"live_looking\" (none of those artefacts), \"spoof_suspected\" (clear evidence of at least one) or \"uncertain\" (cannot tell), with an optional short concrete note.",
    "5. FIELD CONSISTENCY: compare the data printed on the ID against the registration form fields given below, one verdict per field — \"match\", \"mismatch\" or \"unverifiable\":",
    "- full_name: ignore letter case, middle names/initials and name ordering; the form value is missing or the names clearly refer to different people => \"mismatch\"; the name is not legible on the ID => \"unverifiable\".",
    "- date_of_birth: equivalent date formats are fine; either value missing or the dates clearly differ => \"mismatch\"; not legible on the ID => \"unverifiable\".",
    "- address: compare for the reviewer's information only. A current residential address may legitimately differ from the address printed on an ID, so a differing address is \"match\" unless it is plainly a different person's address.",
    "- gender: \"match\" when consistent (an ID may abbreviate, e.g. M / Male); \"mismatch\" when it clearly differs; \"unverifiable\" when the ID does not state it or it is not legible.",
    "",
    "Rules:",
    "- Prefer an honest \"uncertain\" or \"unverifiable\" over a confident wrong answer.",
    "- If the ID capture is a photocopy/xerox or a photo of a screen, report id_authenticity \"unreadable\" and say so in reasons.",
    "- reasons must be 2-4 short plain-language notes (at most ~120 characters each) aimed at the human reviewer: what you saw, what is missing, what you are unsure about.",
    "- Do not include any name, ID number, address or other personal data quoted from the document in reasons; describe the finding, not the data.",
    "- Return only the JSON object described by the response schema; never include any text outside it.",
    "",
    `Registration form fields: ${formFieldsJson}`,
  ].join("\n");

  let raw: unknown;
  try {
    raw = await callGemini(prompt, {
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0.2,
      images: images.map((image) => ({
        mime_type: image.mimeType,
        data: image.data,
      })),
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

  // 'uncertain' fallback: an off-schema read can never clear anything.
  const authenticity = coerceEnum(
    obj.id_authenticity,
    AUTHENTICITY,
    "uncertain",
  );
  const selfieQuality = coerceEnum(
    obj.selfie_quality,
    SELFIE_QUALITIES,
    "uncertain",
  );
  // 'unknown' means the document could not be identified at all, which is
  // never a type match.
  const idTypeGuess = coerceEnum(
    obj.id_type_guess,
    [...ID_TYPES, "unknown"] as const,
    "unknown",
  );
  const liveness = coerceLiveness(obj.liveness);
  const fieldChecks = coerceFieldChecks(obj.field_checks);
  const reasons = coerceStringList(obj.reasons);

  // Deterministic, never model-decided: the detected type has to agree with the
  // declared one for the capture to be a clean read. This is a hint for the
  // reviewer, not an approval — the captain always decides.
  const idTypeMatch = idTypeGuess !== "unknown" && idTypeGuess === idType;

  const recommendation = looksOk({
    authenticity,
    idTypeMatch,
    selfieQuality,
    spoofSignal: liveness.spoofSignal,
  })
    ? "looks_ok"
    : "needs_review";

  return jsonResponse(200, {
    result: {
      id_authenticity: authenticity,
      id_type_guess: idTypeGuess,
      id_type_match: idTypeMatch,
      selfie_quality: selfieQuality,
      liveness: {
        spoof_signal: liveness.spoofSignal,
        ...(liveness.notes ? { notes: liveness.notes } : {}),
      },
      field_checks: fieldChecks,
      recommendation,
      reasons,
      prompt_version: PROMPT_VERSION,
    },
  });
}

// Router lookup derives the module export name from the task name
// (kebab-case -> snake_case). Provide both shapes, plus a default.
export { idVerifier as id_verifier };
export default idVerifier;