import type { FastifyInstance } from "fastify";
import { getRedis } from "../lib/redis.js";

export async function registerJobsRoutes(app: FastifyInstance) {
  const redis = getRedis();

  app.get<{
    Params: { jobId: string };
  }>("/v1/jobs/:jobId", async (request, reply) => {
    const { jobId } = request.params;
    const raw = await redis.get(`job:${jobId}`);
    if (!raw) {
      return reply.status(404).send({ error: "Job not found" });
    }
    const data = JSON.parse(raw);
    return reply.send(data);
  });
}
