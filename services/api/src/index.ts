/**
 * Point d'entrée de l'API Dent ta Maison.
 * Charge .env, démarre le worker d'analyse (BullMQ), écoute sur le port configuré.
 */
import "./lib/loadEnv.js";
import { buildApp } from "./app.js";
import { env } from "./lib/env.js";
import { logger } from "./lib/logger.js";
import { startAnalysisWorker } from "./services/queue/worker.js";

async function main() {
  if (!env.openaiApiKey) {
    logger.warn("OPENAI_API_KEY non défini — les analyses échoueront (vision requise). Vérifier .env à la racine.");
  } else {
    logger.info("OpenAI configuré — dépistage visuel et explications activés");
  }
  logger.info({ mlServiceUrl: env.mlServiceUrl }, "URL du service ML");

  const worker = startAnalysisWorker();
  const app = await buildApp();

  try {
    await app.listen({ port: env.port, host: "0.0.0.0" });
    logger.info({ port: env.port }, "API en écoute");
  } catch (err) {
    logger.error(err);
    process.exit(1);
  }

  const shutdown = async () => {
    await worker.close();
    await app.close();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main();
