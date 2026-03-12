/**
 * Load .env from repo root so OPENAI_API_KEY etc. are available.
 * Must be imported first in index.ts (before env.js).
 */
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// From dist/lib/ or src/lib/: go up to repo root (HACKINGHEALTH) for .env
// dist/lib -> api -> services -> HACKINGHEALTH = ../../../../.env
// src/lib (tsx) -> api -> services -> HACKINGHEALTH = ../../../../.env
const repoRoot = path.resolve(__dirname, "../../../..");
dotenv.config({ path: path.join(repoRoot, ".env") });
