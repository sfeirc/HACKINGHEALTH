import { env } from "../../lib/env.js";
import { logger } from "../../lib/logger.js";
import type { AnalysisResult } from "@oralscan-ai/shared-types";

export async function callMlInfer(imageBase64: string): Promise<AnalysisResult | null> {
  try {
    const response = await fetch(`${env.mlServiceUrl}/infer`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ image: imageBase64 }),
    });
    if (!response.ok) {
      logger.warn({ status: response.status }, "ML service error");
      return null;
    }
    const json = await response.json();
    return json as AnalysisResult;
  } catch (err) {
    logger.warn({ err }, "ML service request failed");
    return null;
  }
}
