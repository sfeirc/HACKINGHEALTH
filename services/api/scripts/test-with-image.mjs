#!/usr/bin/env node
/**
 * Test full API with an image file: POST /v1/analyze → poll /v1/jobs/:jobId.
 * Usage: node scripts/test-with-image.mjs <path-to-image.jpg>
 * Requires: Redis, API (PORT=3000), ML (ML_SERVICE_URL=http://localhost:8000) running.
 */
import { readFileSync } from "fs";
import { existsSync } from "fs";

const imagePath = process.argv[2] || new URL("../../Les-causes-dapparition-des-caries-dentaires-1024x576.jpg", import.meta.url).pathname;
const API_URL = process.env.API_URL || "http://127.0.0.1:3000";

async function main() {
  console.log("Image:", imagePath);
  console.log("API:", API_URL);

  if (!existsSync(imagePath)) {
    console.error("Image not found:", imagePath);
    process.exit(1);
  }

  // 1. Upload (multipart)
  const buf = readFileSync(imagePath);
  const form = new FormData();
  form.append("image", new Blob([buf]), "image.jpg");

  const uploadRes = await fetch(`${API_URL}/v1/analyze`, {
    method: "POST",
    body: form,
  });
  if (!uploadRes.ok) {
    console.error("Upload failed:", uploadRes.status, await uploadRes.text());
    process.exit(1);
  }
  const { jobId } = await uploadRes.json();
  if (!jobId) {
    console.error("No jobId in response");
    process.exit(1);
  }
  console.log("JobId:", jobId);

  // 2. Poll
  for (let i = 0; i < 15; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const jobRes = await fetch(`${API_URL}/v1/jobs/${jobId}`);
    if (!jobRes.ok) {
      console.error("Job poll failed:", jobRes.status);
      process.exit(1);
    }
    const job = await jobRes.json();
    console.log("  Poll", i + 1, "status:", job.status);
    if (job.status === "completed") {
      console.log("\nResult:", JSON.stringify(job.result, null, 2));
      if (job.explanation) {
        console.log("\nExplanation:", JSON.stringify(job.explanation, null, 2));
      } else {
        console.log("\nExplanation: (null - OpenAI not configured or failed)");
      }
      console.log("\n[OK] E2E with image passed.");
      return;
    }
    if (job.status === "failed") {
      console.error("Job failed:", job.error);
      process.exit(1);
    }
  }
  console.error("Job did not complete in time");
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
