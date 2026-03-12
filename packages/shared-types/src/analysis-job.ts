import { z } from "zod";

export const analysisJobPayloadSchema = z.object({
  jobId: z.string().uuid(),
  imagePath: z.string().optional(),
  imageBase64: z.string().optional(),
  requestedAt: z.string().datetime(),
});

export type AnalysisJobPayload = z.infer<typeof analysisJobPayloadSchema>;
