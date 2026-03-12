/**
 * Construction de l'application Fastify (API Dent ta Maison).
 * Enregistre CORS, multipart, et les routes santé, analyse, jobs, soumission, admin.
 */
import Fastify from "fastify";
import cors from "@fastify/cors";
import multipart from "@fastify/multipart";
import { env, isProduction } from "./lib/env.js";
import { registerHealthRoutes } from "./routes/health.js";
import { registerAnalyzeRoutes } from "./routes/analyze.js";
import { registerJobsRoutes } from "./routes/jobs.js";
import { registerSubmitRoutes } from "./routes/submit.js";
import { registerAdminRoutes } from "./routes/admin.js";

export async function buildApp() {
  const app = Fastify({ logger: false });

  await app.register(cors, {
    origin: env.corsOrigin || true,
    methods: ["GET", "POST", "HEAD"],
    allowedHeaders: ["Content-Type"],
  });

  await app.register(multipart, { limits: { fileSize: 10 * 1024 * 1024 } });

  if (isProduction) {
    app.setErrorHandler((err, _request, reply) => {
      const status = err.statusCode ?? 500;
      const message = status >= 500 ? "Erreur interne" : (err.message ?? "Erreur");
      reply.status(status).send({ error: message });
    });
  }

  await registerHealthRoutes(app);
  await registerAnalyzeRoutes(app);
  await registerJobsRoutes(app);
  await registerSubmitRoutes(app);
  await registerAdminRoutes(app);

  return app;
}
