import { Redis } from "ioredis";
import { env } from "./env.js";
import { logger } from "./logger.js";

let redis: Redis | null = null;

export function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(env.redisUrl, { maxRetriesPerRequest: null });
    redis.on("error", (err: Error) => logger.error({ err }, "Redis error"));
  }
  return redis;
}

export async function closeRedis(): Promise<void> {
  if (redis) {
    await redis.quit();
    redis = null;
  }
}
