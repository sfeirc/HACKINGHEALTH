/** Configuration chargée depuis les variables d'environnement (production ou développement). */
export const env = {
  port: Number(process.env.PORT) || 3000,
  redisUrl: process.env.REDIS_URL || "redis://localhost:6379",
  mlServiceUrl: process.env.ML_SERVICE_URL || "http://localhost:8000",
  openaiApiKey: process.env.OPENAI_API_KEY ?? "",
  nodeEnv: process.env.NODE_ENV || "development",
  /** Origine(s) CORS autorisées (vide = tout autoriser en dev). En production, définir CORS_ORIGIN. */
  corsOrigin: process.env.CORS_ORIGIN || "",
};
export const isProduction = env.nodeEnv === "production";
