#!/usr/bin/env node
/**
 * Test vision screening directly with an image (loads .env from repo root).
 * Usage: node scripts/test-vision-direct.mjs <path-to-image.jpg>
 */
import { readFileSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";
import dotenv from "dotenv";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../../..");
dotenv.config({ path: path.join(repoRoot, ".env") });

const imagePath = process.argv[2] || path.join(repoRoot, "Les-causes-dapparition-des-caries-dentaires-1024x576.jpg");

async function main() {
  if (!existsSync(imagePath)) {
    console.error("Image not found:", imagePath);
    process.exit(1);
  }
  const key = process.env.OPENAI_API_KEY;
  const model = process.env.OPENAI_EXPLANATION_MODEL ?? "gpt-4o";
  console.log("OPENAI_API_KEY set:", !!key);
  console.log("OPENAI_EXPLANATION_MODEL:", model);
  console.log("Image:", imagePath);
  const base64 = readFileSync(imagePath).toString("base64");
  console.log("Base64 length:", base64.length);

  const OpenAI = (await import("openai")).default;
  const openai = new OpenAI({ apiKey: key });

  const systemContent = `You are an expert dental assistant. Analyze the intraoral image for cavities. Output valid JSON only (no markdown):
{ "has_cavity": boolean, "cavity_danger_score": number (0-100), "findings": [ { "region": string, "severity": "low"|"moderate"|"high", "confidence": number } ] }
Use region codes like upper_left_molar_area, upper_right_molar_area. List every cavity you see.`;

  try {
    const completion = await openai.chat.completions.create({
      model: model,
      messages: [
        { role: "system", content: systemContent },
        {
          role: "user",
          content: [
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${base64}`, detail: "high" } },
            { type: "text", text: "Analyze this intraoral image. Output the JSON only." },
          ],
        },
      ],
      max_completion_tokens: 1024,
    });

    const raw = completion.choices[0]?.message?.content;
    console.log("\nRaw response (first 500 chars):", raw ? raw.slice(0, 500) : "(empty)");
    if (raw) {
      const start = raw.indexOf("{");
      const end = raw.lastIndexOf("}");
      if (start !== -1 && end > start) {
        const json = JSON.parse(raw.slice(start, end + 1));
        console.log("\nParsed:", JSON.stringify(json, null, 2));
        console.log("\n[OK] Vision API works with model", model);
      }
    }
  } catch (err) {
    console.error("\n[FAIL]", err.message);
    if (err.status) console.error("Status:", err.status);
    process.exit(1);
  }
}

main();
