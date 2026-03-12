#!/usr/bin/env node
/**
 * Verifies that the AI vision pipeline works: uploads image, polls until completed,
 * prints screening (findings) and explanation. Requires API + Redis + ML running, OPENAI_API_KEY in .env.
 * Usage: node scripts/verify-ai-vision.mjs [path/to/image.jpg]
 */
import { readFileSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagePath = process.argv[2] || path.join(__dirname, "..", "Les-causes-dapparition-des-caries-dentaires-1024x576.jpg");
const API_URL = process.env.API_URL || "http://127.0.0.1:3000";

async function main() {
  if (!existsSync(imagePath)) {
    console.error("Image not found:", imagePath);
    process.exit(1);
  }

  console.log("Image:", imagePath);
  console.log("API:", API_URL);
  console.log("");

  const buf = readFileSync(imagePath);
  const form = new FormData();
  form.append("image", new Blob([buf]), "image.jpg");

  const uploadRes = await fetch(`${API_URL}/v1/analyze`, { method: "POST", body: form });
  if (!uploadRes.ok) {
    console.error("Upload failed:", uploadRes.status, await uploadRes.text());
    process.exit(1);
  }

  const { jobId } = await uploadRes.json();
  if (!jobId) {
    console.error("No jobId");
    process.exit(1);
  }
  console.log("JobId:", jobId);
  console.log("Polling for result (vision screening + explanation)...");

  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const jobRes = await fetch(`${API_URL}/v1/jobs/${jobId}`);
    const job = await jobRes.json();

    if (job.status === "failed") {
      console.error("\nJob FAILED:", job.error);
      process.exit(1);
    }
    if (job.status === "completed") {
      console.log("\n--- AI SCREENING (from vision) ---");
      const s = job.result?.screening;
      if (s) {
        console.log("  has_cavity:", s.has_cavity ?? s.hasCavity);
        console.log("  cavity_danger_score:", s.cavity_danger_score ?? s.cavityDangerScore);
        console.log("  risk_level:", s.risk_level ?? s.riskLevel);
        console.log("  findings:", (s.findings || []).length);
        (s.findings || []).forEach((f, i) => console.log(`    ${i + 1}. ${f.region} — ${f.severity} (confidence: ${f.confidence})${f.label ? " [" + f.label + "]" : ""}`));
      } else {
        console.log("  (no screening)");
      }
      console.log("\n--- AI EXPLANATION (from vision) ---");
      const e = job.explanation;
      if (e) {
        console.log("  title:", e.summary_title);
        console.log("  text:", e.summary_text);
        if (e.reasoning) console.log("  reasoning:", e.reasoning);
      } else {
        console.log("  (null — OpenAI key missing or explanation failed)");
      }
      console.log("\n[OK] AI vision pipeline returned real data.");
      console.log("\nIf explanation is in English or findings look generic, restart the API so it loads .env and latest code:");
      console.log("  cd services/api && npm run dev");
      return;
    }
    process.stdout.write(".");
  }
  console.error("\nTimeout waiting for job.");
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
