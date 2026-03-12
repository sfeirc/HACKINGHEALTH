/**
 * Worker BullMQ : traite les jobs d'analyse (image → ML → vision OpenAI → explication).
 * Met à jour Redis (statut), enregistre les artefacts (photo, données) et les soumissions.
 */
import { Worker, Job } from "bullmq";
import { getRedis } from "../../lib/redis.js";
import { env } from "../../lib/env.js";
import { saveJobArtifacts } from "../../lib/storage.js";
import { callMlInfer } from "../ml/client.js";
import { getExplanation } from "../openai/explain.js";
import { getVisionScreening, screeningToResult } from "../openai/screening.js";
import type { AnalysisJobPayload, AnalysisResult } from "@oralscan-ai/shared-types";
import { analysisResultSchema } from "@oralscan-ai/shared-types";
import { logger } from "../../lib/logger.js";

const ANALYSIS_QUEUE_NAME = "analysis_queue";
const JOB_RESULT_TTL = 3600;

export function startAnalysisWorker(): Worker {
  const redis = getRedis();
  const worker = new Worker<AnalysisJobPayload>(
    ANALYSIS_QUEUE_NAME,
    async (job: Job<AnalysisJobPayload>) => {
      const { jobId, imageBase64 } = job.data;

      await redis.set(
        `job:${jobId}`,
        JSON.stringify({ status: "processing" }),
        "EX",
        JOB_RESULT_TTL
      );

      const rawResult = await callMlInfer(imageBase64 ?? "");
      if (!rawResult) {
        await redis.set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: "Service d'analyse indisponible." }),
          "EX",
          JOB_RESULT_TTL
        );
        logger.warn(
          { jobId, mlServiceUrl: env.mlServiceUrl },
          "ML service unavailable (connection refused?). Start it with: cd services/ml && PYTHONPATH=. python3 -m uvicorn app.main:app --port 8000"
        );
        return;
      }

      const parsed = analysisResultSchema.safeParse(rawResult);
      if (!parsed.success) {
        await redis.set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: "Réponse d'analyse invalide." }),
          "EX",
          JOB_RESULT_TTL
        );
        logger.warn({ jobId, err: parsed.error }, "ML result invalid, job failed");
        return;
      }

      let analysisResult: AnalysisResult = parsed.data;
      const imageB64 = imageBase64 ?? "";

      // Vision-only: screening and explanation come ONLY from AI vision (no ML screening, no mock)
      if (!imageB64.length) {
        await redis.set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: "Image manquante." }),
          "EX",
          JOB_RESULT_TTL
        );
        logger.warn({ jobId }, "No image in job, cannot run vision");
        return;
      }
      if (!env.openaiApiKey) {
        await redis.set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: "Analyse vision non configurée (OPENAI_API_KEY)." }),
          "EX",
          JOB_RESULT_TTL
        );
        logger.warn({ jobId }, "OpenAI API key missing, vision required");
        return;
      }

      const visionScreening = await getVisionScreening(imageB64);
      if (!visionScreening) {
        await redis.set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: "Analyse vision indisponible. Réessayez." }),
          "EX",
          JOB_RESULT_TTL
        );
        logger.warn({ jobId }, "Vision screening returned null");
        return;
      }

      const { screening, recommendation } = screeningToResult(visionScreening);
      analysisResult = {
        ...analysisResult,
        screening,
        recommendation,
      };

      const explanation = await getExplanation(analysisResult, imageB64);

      const payload = {
        status: "completed",
        result: analysisResult,
        explanation,
      };

      await redis.set(`job:${jobId}`, JSON.stringify(payload), "EX", JOB_RESULT_TTL);
      try {
        await saveJobArtifacts(jobId, imageB64, analysisResult, explanation);
      } catch (err) {
        logger.warn({ jobId, err }, "Failed to save job artifacts to storage");
      }
      logger.info({ jobId }, "Analysis job completed (vision-only)");
    },
    {
      connection: { url: env.redisUrl, maxRetriesPerRequest: null },
      concurrency: 2,
    }
  );

  worker.on("failed", (job, err) => {
    logger.error({ jobId: job?.id, err }, "Analysis job failed");
    if (job) {
      const jobId = (job.data as AnalysisJobPayload).jobId;
      redis
        .set(
          `job:${jobId}`,
          JSON.stringify({ status: "failed", error: String(err?.message ?? err) }),
          "EX",
          JOB_RESULT_TTL
        )
        .catch(() => {});
    }
  });

  return worker;
}
