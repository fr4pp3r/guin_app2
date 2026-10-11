// Shared helpers for AI edge-function feature handlers.
//
// Feature lanes add a handler module under supabase/functions/ai/handlers/
// exporting an async `TaskHandler`:
//
//   import { callGemini, jsonResponse, errorResponse } from "../_shared.ts";
//   export const documentProcessor: TaskHandler = async (payload) => { ... };
//
// Handlers must:
//   - catch thrown errors from callGemini (which throws objects with
//     { status, code, message }) and map them via errorResponse(...)
//   - never log the API key or full prompt contents
// The router in index.ts registers each handler under its task name.

export interface GeminiImage {
  mime_type: string;
  data: string;
}

export interface GeminiOptions {
  model?: string;
  responseSchema?: Record<string, unknown>;
  temperature?: number;
  // Base64-encoded images sent as inline_data parts ahead of the text
  // prompt. Supports any number of images; the order is preserved.
  images?: GeminiImage[];
}

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(
  status: number,
  code: string,
  message: string,
): Response {
  return jsonResponse(status, { error: { code, message } });
}

const MODEL = Deno.env.get("AI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

// Calls the Gemini generateContent REST endpoint. Single retry on 429/503
// with ~1s backoff. Never logs the API key or prompt contents.
// Throws objects shaped { status, code, message, detail? } on failure.
export async function callGemini(
  prompt: string,
  opts: GeminiOptions = {},
): Promise<unknown> {
  if (!GEMINI_API_KEY) {
    throw Object.assign(new Error("GEMINI_API_KEY not configured"), {
      status: 500,
      code: "config_error",
    });
  }
  const model = opts.model ?? MODEL;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const generationConfig: Record<string, unknown> = {
    response_mime_type: "application/json",
  };
  if (opts.responseSchema) {
    generationConfig.response_schema = opts.responseSchema;
  }
  if (typeof opts.temperature === "number") {
    generationConfig.temperature = opts.temperature;
  }
  const parts: Array<Record<string, unknown>> = [];
  if (opts.images && opts.images.length > 0) {
    for (const image of opts.images) {
      parts.push({ inline_data: { mime_type: image.mime_type, data: image.data } });
    }
  }
  parts.push({ text: prompt });
  const body = JSON.stringify({
    contents: [{ role: "user", parts }],
    generationConfig,
  });

  let lastStatus = 0;
  let lastBody = "";
  for (let attempt = 0; attempt < 2; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, 1000));
    }
    let res: Response;
    try {
      res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY,
        },
        body,
      });
    } catch (e) {
      console.error(`AiService upstream fetch failed: ${String(e)}`);
      throw Object.assign(new Error("Upstream AI request failed"), {
        status: 502,
        code: "upstream_failure",
      });
    }
    if (res.ok) {
      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      try {
        return JSON.parse(text);
      } catch {
        return text;
      }
    }
    lastStatus = res.status;
    lastBody = await res.text();
    console.error(`Gemini upstream status=${lastStatus}`);
    if (res.status === 429 || res.status === 503) continue;
    break;
  }
  if (lastStatus === 429) {
    throw Object.assign(new Error("AI quota exhausted"), {
      status: 429,
      code: "quota_exhausted",
    });
  }
  throw Object.assign(new Error(`AI upstream failed (${lastStatus})`), {
    status: 502,
    code: "upstream_failure",
    detail: lastBody.slice(0, 200),
  });
}