import { describe, it } from "node:test";
import assert from "node:assert";
import { analysisResultSchema } from "@oralscan-ai/shared-types";
import { getMockAnalysisResult } from "../src/services/queue/mock-result.js";

describe("mock-result", () => {
  it("getMockAnalysisResult returns valid AnalysisResult", () => {
    const result = getMockAnalysisResult();
    const parsed = analysisResultSchema.safeParse(result);
    assert.strictEqual(parsed.success, true, parsed.success ? "" : JSON.stringify(parsed.error.errors));
    assert.strictEqual(result.image_quality.usable, true);
    assert.ok(["low", "moderate", "high"].includes(result.screening.risk_level));
    assert.ok(result.screening.findings.length > 0);
    assert.ok(result.recommendation?.message.length > 0);
    assert.strictEqual(typeof result.screening.has_cavity, "boolean");
    assert.strictEqual(typeof result.screening.cavity_danger_score, "number");
    assert.ok(result.screening.cavity_danger_score >= 0 && result.screening.cavity_danger_score <= 100);
  });
});
