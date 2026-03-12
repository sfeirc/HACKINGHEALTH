/** Route de santé : GET /health pour les checks de disponibilité (load balancer, k8s). */
import type { FastifyInstance } from "fastify";

export async function registerHealthRoutes(app: FastifyInstance) {
  app.get("/health", async () => ({ status: "ok" }));
}
