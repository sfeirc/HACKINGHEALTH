/**
 * Route de soumission : POST /v1/submit (formulaire après analyse).
 * Enregistre la soumission (coordonnées, score, rapport) et sert les photos via GET /v1/photos/:jobId.
 */
import fs from "fs";
import type { FastifyInstance } from "fastify";
import { readJobData, readSubmissions, appendSubmission, getPhotoPath } from "../lib/storage.js";
import type { SubmissionRecord } from "../lib/storage.js";
import { randomUUID } from "crypto";

const SUBMIT_BODY_SCHEMA = {
  type: "object",
  required: ["jobId", "firstName", "lastName", "phone", "dateOfBirth"],
  properties: {
    jobId: { type: "string" },
    firstName: { type: "string" },
    lastName: { type: "string" },
    phone: { type: "string" },
    dateOfBirth: { type: "string" },
    gender: { type: "string" },
    locationOfBirth: { type: "string" },
  },
} as const;

export async function registerSubmitRoutes(app: FastifyInstance) {
  app.post<{
    Body: { jobId: string; firstName: string; lastName: string; phone: string; dateOfBirth: string; gender?: string; locationOfBirth?: string };
  }>("/v1/submit", {
    schema: { body: SUBMIT_BODY_SCHEMA },
  }, async (request, reply) => {
    const { jobId, firstName, lastName, phone, dateOfBirth, gender, locationOfBirth } = request.body;
    const jobData = await readJobData(jobId);
    if (!jobData) {
      return reply.status(404).send({ error: "Job data not found. Analysis may have expired." });
    }
    const result = jobData.result as { screening?: { cavity_danger_score?: number } };
    const explanation = jobData.explanation as { summary_text?: string } | undefined;
    const score = result?.screening?.cavity_danger_score ?? 0;
    const report = explanation?.summary_text ?? "";

    const record: SubmissionRecord = {
      id: randomUUID(),
      jobId,
      firstName,
      lastName,
      phone,
      dateOfBirth,
      gender: gender ?? "",
      locationOfBirth: locationOfBirth ?? "",
      photoPath: `photos/${jobId}.jpg`,
      score,
      report,
      createdAt: new Date().toISOString(),
    };
    await appendSubmission(record);
    return reply.status(201).send({ ok: true, id: record.id });
  });

  app.get("/v1/submissions", async (_request, reply) => {
    const list = await readSubmissions();
    return reply.send(list);
  });

  app.get<{ Params: { jobId: string } }>("/v1/photos/:jobId", async (request, reply) => {
    const { jobId } = request.params;
    const photoPath = await getPhotoPath(jobId);
    if (!photoPath) {
      return reply.status(404).send({ error: "Photo not found" });
    }
    const stream = fs.createReadStream(photoPath);
    return reply.type("image/jpeg").send(stream);
  });
}
