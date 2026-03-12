import type { AnalysisResult } from "@oralscan-ai/shared-types";

export function getMockAnalysisResult(): AnalysisResult {
  return {
    image_quality: {
      usable: true,
      blur_score: 0.12,
      brightness_score: 0.78,
      mouth_visibility_score: 0.84,
      reasons: [],
    },
    screening: {
      risk_level: "moderate",
      confidence: 0.83,
      findings: [
        {
          label: "suspicious_caries_region",
          region: "upper_left_molar_area",
          severity: "moderate",
          confidence: 0.79,
        },
      ],
      has_cavity: false,
      cavity_danger_score: 52,
    },
    recommendation: {
      action: "consult_dentist",
      message:
        "Une zone d'attention a été repérée. Il est recommandé de consulter un dentiste pour un contrôle.",
    },
  };
}
