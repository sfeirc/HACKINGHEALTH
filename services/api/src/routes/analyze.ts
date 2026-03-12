/**
 * Routes d'analyse : POST /v1/analyze (upload image → file d'attente BullMQ, retourne jobId).
 * Le worker traite le job (ML + vision + explication) et met à jour Redis.
 */
import type { FastifyInstance } from "fastify";
import { Queue } from "bullmq";
import { randomUUID } from "crypto";
import { getRedis } from "../lib/redis.js";
import { env } from "../lib/env.js";
import { logger } from "../lib/logger.js";

const ANALYSIS_QUEUE_NAME = "analysis_queue";
const JOB_RESULT_TTL = 3600;

export async function registerAnalyzeRoutes(app: FastifyInstance) {
  const redis = getRedis();

  const analysisQueue = new Queue(ANALYSIS_QUEUE_NAME, {
    connection: { url: env.redisUrl, maxRetriesPerRequest: null },
    defaultJobOptions: { removeOnComplete: { count: 1000 }, attempts: 2 },
  });

  app.post<{
    Body: unknown;
  }>("/v1/analyze", async (request, reply) => {
    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ error: "Missing image file" });
    }

    const buffer = await data.toBuffer();
    const jobId = randomUUID();

    await analysisQueue.add(
      "analyze",
      {
        jobId,
        imageBase64: buffer.toString("base64"),
        requestedAt: new Date().toISOString(),
      },
      { jobId }
    );

    await redis.set(
      `job:${jobId}`,
      JSON.stringify({ status: "queued" }),
      "EX",
      JOB_RESULT_TTL
    );

    logger.info({ jobId }, "Analysis job enqueued");

    return reply.send({ jobId, status: "queued" });
  });

  app.addHook("onClose", async () => {
    await analysisQueue.close();
  });
}
