import { z } from "zod";

export const explanationResponseSchema = z.object({
  summary_title: z.string(),
  summary_text: z.string(),
  next_action: z.enum(["consult_dentist", "retake_photo", "no_action"]),
  retake_needed: z.boolean(),
  /** 2–4 sentences: what you see (cavitation vs staining vs demineralization), why score/risk, and any mismatch with numeric analysis. */
  reasoning: z.string().optional(),
});

export type ExplanationResponse = z.infer<typeof explanationResponseSchema>;
