import { z } from "zod";
import { analysisResultSchema } from "./analysis-result.js";
import { explanationResponseSchema } from "./explanation.js";

export const jobStatusSchema = z.enum(["queued", "processing", "completed", "failed"]);

export const jobResultSchema = z.object({
  status: jobStatusSchema,
  result: analysisResultSchema.optional(),
  explanation: explanationResponseSchema.optional(),
  error: z.string().optional(),
});

export type JobStatus = z.infer<typeof jobStatusSchema>;
export type JobResult = z.infer<typeof jobResultSchema>;
