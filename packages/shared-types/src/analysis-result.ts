import { z } from "zod";

export const imageQualitySchema = z.object({
  usable: z.boolean(),
  blur_score: z.number().min(0).max(1).optional(),
  brightness_score: z.number().min(0).max(1).optional(),
  mouth_visibility_score: z.number().min(0).max(1).optional(),
  reasons: z.array(z.string()),
});

export const findingSchema = z.object({
  label: z.string().optional(),
  region: z.string(),
  severity: z.enum(["low", "moderate", "high"]),
  confidence: z.number().min(0).max(1),
});

export const screeningSchema = z.object({
  risk_level: z.enum(["low", "moderate", "high"]),
  confidence: z.number().min(0).max(1),
  findings: z.array(findingSchema),
  has_cavity: z.boolean(),
  cavity_danger_score: z.number().min(0).max(100).int(),
});

export const recommendationSchema = z.object({
  action: z.enum(["consult_dentist", "retake_photo", "no_action"]),
  message: z.string(),
});

export const analysisResultSchema = z.object({
  image_quality: imageQualitySchema,
  screening: screeningSchema,
  recommendation: recommendationSchema.optional(),
});

export type ImageQuality = z.infer<typeof imageQualitySchema>;
export type Finding = z.infer<typeof findingSchema>;
export type Screening = z.infer<typeof screeningSchema>;
export type Recommendation = z.infer<typeof recommendationSchema>;
export type AnalysisResult = z.infer<typeof analysisResultSchema>;
