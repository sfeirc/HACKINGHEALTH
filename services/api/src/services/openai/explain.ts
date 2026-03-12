import OpenAI from "openai";
import { env } from "../../lib/env.js";
import { logger } from "../../lib/logger.js";
import type { AnalysisResult, ExplanationResponse } from "@oralscan-ai/shared-types";

const VISION_MODELS = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4-vision-preview"];
function getVisionModel(): string {
  const env = process.env.OPENAI_EXPLANATION_MODEL ?? "gpt-4o";
  return VISION_MODELS.includes(env) ? env : "gpt-4o";
}

export async function getExplanation(
  analysis: AnalysisResult,
  imageBase64?: string
): Promise<ExplanationResponse | null> {
  if (!env.openaiApiKey) {
    return null;
  }
  try {
    const openai = new OpenAI({ apiKey: env.openaiApiKey });

    const systemContent = `You are an expert dental assistant. Analyze the intraoral image with the same rigor as a clinician.

**Language:** You MUST respond ONLY in French. Every string in your JSON output (summary_title, summary_text, reasoning) must be in French.

**Vision checklist (when the image is provided):**
- Cavitation: visible hole, break in enamel, or clear structural defect (= definite cavity).
- Carious lesion: dark brown/black discoloration with loss of tooth structure (= cavity).
- Demineralization: white spots or early enamel changes (= suspicious area, NOT a cavity yet).
- Staining: surface discoloration without cavitation (not a cavity).
- Restorations: fillings; note secondary caries at margins if visible.
- Name which teeth/areas you see (e.g. molaire supérieure droite, face occlusale).

**Reconcile with numeric analysis:** You receive automated data: has_cavity (true only if definite cavity), findings (regions + severity). CRITICAL: If has_cavity is false but there are findings (e.g. "upper_left_molar_area", "moderate"), that means "suspicious area" or "zone à surveiller" — NOT a cavity. Your summary_text MUST reflect this: say "Aucune cavité confirmée" and, if there are findings, "Une zone d'attention a été repérée" or "zone à surveiller", then recommend a dental check. Never say both "cavity detected" and "no cavity" in a contradictory way. Align summary with what you SEE: if you see no cavitation, say no cavity; if you see a suspicious area, say "zone à surveiller" and recommend consultation.

**Output:** Valid JSON only (no markdown), all text in French:
{ "summary_title": string, "summary_text": string, "next_action": "consult_dentist" | "retake_photo" | "no_action", "retake_needed": boolean, "reasoning": string }

- summary_title: court titre (ex. "Analyse terminée").
- summary_text: 1–2 phrases pour l'utilisateur; rassurant; préciser "aucune cavité" ou "cavité visible", et en cas de zone suspecte sans cavité "zone à surveiller" + consulter un dentiste.
- reasoning: 2–4 phrases (en français): ce que vous voyez (cavitation ou zone suspecte, quelle zone), cohérence avec l'analyse numérique, justification du niveau de risque.`;

    const userContent: OpenAI.Chat.Completions.ChatCompletionContentPart[] = [
      {
        type: "text",
        text: `Résultat de l'analyse numérique:\n${JSON.stringify(analysis)}\n\nRegardez l'image (si fournie), puis répondez en JSON avec summary_title, summary_text, next_action, retake_needed et reasoning. Tous les textes en français.`,
      },
    ];
    if (imageBase64 && imageBase64.length > 0) {
      userContent.unshift({
        type: "image_url",
        image_url: {
          url: `data:image/jpeg;base64,${imageBase64}`,
          detail: "high" as const,
        },
      });
    }

    const completion = await openai.chat.completions.create({
      model: getVisionModel(),
      messages: [
        { role: "system", content: systemContent },
        { role: "user", content: userContent },
      ],
      max_completion_tokens: 1536,
    });

    const raw = completion.choices[0]?.message?.content;
    if (typeof raw !== "string" || !raw) return null;

    const json = parseJsonFromMessage(raw);
    const nextAction = json?.next_action;
    if (
      json &&
      typeof json.summary_title === "string" &&
      typeof json.summary_text === "string" &&
      typeof nextAction === "string" &&
      ["consult_dentist", "retake_photo", "no_action"].includes(nextAction) &&
      typeof json.retake_needed === "boolean"
    ) {
      const reasoning =
        typeof json.reasoning === "string" && json.reasoning.trim().length > 0
          ? json.reasoning.trim()
          : undefined;
      return { ...json, reasoning } as ExplanationResponse;
    }
  } catch (err) {
    logger.warn({ err }, "OpenAI explanation failed");
  }
  return null;
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

