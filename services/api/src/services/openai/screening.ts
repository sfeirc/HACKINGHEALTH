import OpenAI from "openai";
import { env } from "../../lib/env.js";
import { logger } from "../../lib/logger.js";
import type { Screening } from "@oralscan-ai/shared-types";

const VISION_MODELS = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4-vision-preview"];
function getVisionModel(): string {
  const env = process.env.OPENAI_EXPLANATION_MODEL ?? "gpt-4o";
  return VISION_MODELS.includes(env) ? env : "gpt-4o";
}

export interface VisionScreeningResult {
  has_cavity: boolean;
  cavity_danger_score: number;
  findings: Array<{
    region: string;
    severity: "low" | "moderate" | "high";
    confidence: number;
    label?: string;
  }>;
}

/**
 * Uses vision to detect cavities and suspicious areas. Returns screening data to merge with ML result.
 * Region codes: upper_left_molar_area, upper_right_molar_area, lower_left_molar_area, lower_right_molar_area, upper_incisor_area, lower_incisor_area.
 */
export async function getVisionScreening(
  imageBase64: string
): Promise<VisionScreeningResult | null> {
  if (!env.openaiApiKey || !imageBase64) return null;
  try {
    const openai = new OpenAI({ apiKey: env.openaiApiKey });
    const systemContent = `You are an expert dental assistant. Analyze the intraoral image for ALL cavities and carious lesions. No mock data — report only what you actually SEE in the image.

**Critical:** Scan the ENTIRE image: BOTH sides of the mouth. "Patient's right side" is often on the left of the photo when facing the camera. List EVERY distinct cavity or carious lesion as a separate finding (e.g. if you see 2 caries on the right, output 2 findings).

**Task:** Output valid JSON only (no markdown):
{
  "has_cavity": boolean,
  "cavity_danger_score": number (0-100),
  "findings": [
    { "region": string, "severity": "low"|"moderate"|"high", "confidence": number (0-1), "label": string }
  ]
}

**Rules:**
- has_cavity: true if you see ANY definite cavitation (hole, break in enamel) or clear carious lesion (dark brown/black area with structural loss). Multiple cavities = true. Amalgam fillings are NOT cavities; active decay (dark irregular lesion, hole) IS.
- cavity_danger_score: 0 only if zero cavities. Otherwise 1-100: one small=30-50, one large=50-70, two or more cavities=65-90, severe/multiple=85-100.
- findings: ONE ENTRY PER CAVITY OR CONCERN. Do not merge. Use region codes so we can map: upper_left_molar_area, upper_right_molar_area, lower_left_molar_area, lower_right_molar_area, upper_incisor_area, lower_incisor_area. For patient's RIGHT side use upper_right_molar_area or upper_right_incisor_area (or "upper_right_premolar", "upper_right_canine"). For patient's LEFT use upper_left_*. severity: high = clear cavity/carious lesion; moderate = likely cavity; low = staining/early. confidence 0.7-1.0 for definite cavities.
- label: "cavity" or "carious_lesion" for each definite cavity you see; "suspicious_caries_region" only for uncertain areas.
- If you see 2 cavities (e.g. one on lateral incisor/canine, one on premolar on the right), return 2 findings with region describing each (e.g. upper_right_incisor_area and upper_right_molar_area).
- If no teeth or no decay visible, return has_cavity: false, cavity_danger_score: 0, findings: [].`;

    const completion = await openai.chat.completions.create({
      model: getVisionModel(),
      messages: [
        { role: "system", content: systemContent },
        {
          role: "user",
          content: [
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
                detail: "high" as const,
              },
            },
            { type: "text", text: "Analyze this intraoral image. List every cavity or carious lesion you see (both sides). Output the JSON only." },
          ],
        },
      ],
      max_completion_tokens: 1024,
    });

    const raw = completion.choices[0]?.message?.content;
    if (typeof raw !== "string" || !raw) return null;

    const json = parseJsonFromMessage(raw);
    if (!json || typeof json.has_cavity !== "boolean") return null;

    const findings = Array.isArray(json.findings) ? json.findings : [];
    const cavity_danger_score = Math.min(
      100,
      Math.max(0, Math.round(Number(json.cavity_danger_score) || 0))
    );

    const normalized: VisionScreeningResult = {
      has_cavity: json.has_cavity,
      cavity_danger_score,
      findings: findings
        .filter(
          (f: unknown) =>
            f &&
            typeof f === "object" &&
            typeof (f as { region?: unknown }).region === "string"
        )
        .map((f: { region: string; severity?: string; confidence?: number; label?: string }) => ({
          region: normalizeRegion((f as { region: string }).region),
          severity: ["low", "moderate", "high"].includes(String(f.severity))
            ? (f.severity as "low" | "moderate" | "high")
            : "moderate",
          confidence: Math.min(1, Math.max(0, Number(f.confidence) || 0.5)),
          label: typeof f.label === "string" ? f.label : undefined,
        })),
    };
    return normalized;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    logger.warn({ err, message: msg }, "Vision screening failed — check OPENAI_EXPLANATION_MODEL (use gpt-4o) and API key");
    return null;
  }
}

function parseJsonFromMessage(raw: string): Record<string, unknown> | null {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(trimmed.slice(start, end + 1)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function normalizeRegion(region: string): string {
  const s = region.toLowerCase().replace(/\s+/g, "_");
  // Upper arch
  if (s.includes("upper") && s.includes("left") && (s.includes("molar") || s.includes("molaire") || s.includes("premolar")))
    return "upper_left_molar_area";
  if (s.includes("upper") && s.includes("right") && (s.includes("molar") || s.includes("molaire") || s.includes("premolar")))
    return "upper_right_molar_area";
  if (s.includes("upper") && s.includes("left") && (s.includes("incisor") || s.includes("canine") || s.includes("incisive") || s.includes("canin")))
    return "upper_incisor_area";
  if (s.includes("upper") && s.includes("right") && (s.includes("incisor") || s.includes("canine") || s.includes("incisive") || s.includes("canin")))
    return "upper_right_incisor_area";
  if (s.includes("upper") && s.includes("incisor")) return "upper_incisor_area";
  if (s.includes("upper") && s.includes("right")) return "upper_right_molar_area";
  if (s.includes("upper") && s.includes("left")) return "upper_left_molar_area";
  // Lower arch
  if (s.includes("lower") && s.includes("left") && (s.includes("molar") || s.includes("molaire")))
    return "lower_left_molar_area";
  if (s.includes("lower") && s.includes("right") && (s.includes("molar") || s.includes("molaire")))
    return "lower_right_molar_area";
  if (s.includes("lower") && s.includes("incisor")) return "lower_incisor_area";
  return region || "unknown_region";
}

/** Build screening + recommendation from vision result (mirrors ML postprocess). */
export function screeningToResult(screening: VisionScreeningResult): {
  screening: Screening;
  recommendation: { action: "consult_dentist" | "retake_photo" | "no_action"; message: string };
} {
  const { has_cavity, cavity_danger_score, findings } = screening;
  let risk_level: "low" | "moderate" | "high" = "low";
  const confidence =
    findings.length > 0
      ? findings.reduce((a, f) => a + f.confidence, 0) / findings.length
      : 0;
  if (confidence >= 0.7) risk_level = "moderate";
  if (confidence >= 0.85) risk_level = "high";

  const screeningOut: Screening = {
    risk_level,
    confidence: Math.round(confidence * 100) / 100,
    findings: findings.map((f) => ({
      region: f.region,
      severity: f.severity,
      confidence: f.confidence,
      label: f.label,
    })),
    has_cavity,
    cavity_danger_score,
  };

  let action: "consult_dentist" | "retake_photo" | "no_action" = "no_action";
  let message = "Aucun constat significatif.";
  if (risk_level === "moderate") {
    action = "consult_dentist";
    message =
      "Une zone d'attention a été repérée. Il est recommandé de consulter un dentiste pour un contrôle.";
  } else if (risk_level === "high") {
    action = "consult_dentist";
    message = "Zones d'attention repérées. Veuillez consulter un dentiste.";
  }

  return { screening: screeningOut, recommendation: { action, message } };
}
