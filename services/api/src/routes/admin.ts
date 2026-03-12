/**
 * Route admin : page HTML listant les soumissions (score, rapport, photo, coordonnées).
 * GET /admin — pas d'authentification ; en production, protéger par reverse-proxy ou auth.
 */
import type { FastifyInstance } from "fastify";
import { readSubmissions } from "../lib/storage.js";
import type { SubmissionRecord } from "../lib/storage.js";

function escapeHtml(s: string | null | undefined): string {
  if (s == null) return "";
  const t = String(s);
  return t
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function scoreClass(n: number): string {
  if (n <= 30) return "low";
  if (n <= 60) return "mid";
  return "high";
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleDateString("fr-FR", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function renderCards(list: SubmissionRecord[]): string {
  if (list.length === 0) {
    return '<p class="empty">Aucune soumission pour l\'instant.</p>';
  }
  const cards = list.map((s) => {
    const photoUrl = "/v1/photos/" + encodeURIComponent(s.jobId);
    const score = Number(s.score) || 0;
    const name = escapeHtml(s.firstName) + " " + escapeHtml(s.lastName);
    const gender = s.gender ? `<span><strong>Sexe</strong> ${escapeHtml(s.gender)}</span>` : "";
    const locationOfBirth = s.locationOfBirth ? `<span><strong>Lieu de naissance</strong> ${escapeHtml(s.locationOfBirth)}</span>` : "";
    const metaExtra = [gender, locationOfBirth].filter(Boolean).join("");
    return `<article class="card">
    <div class="card-photo"><img src="${escapeHtml(photoUrl)}" alt=""></div>
    <div class="card-body">
      <h2 class="card-name">${name}</h2>
      <div class="card-score-wrap"><span class="card-score ${scoreClass(score)}"><span class="card-score-num">${escapeHtml(String(score))}</span><span class="card-score-denom">/100</span></span></div>
      <div class="card-meta"><span><strong>Tél.</strong> ${escapeHtml(s.phone)}</span><span><strong>Naissance</strong> ${escapeHtml(s.dateOfBirth)}</span>${metaExtra ? " " + metaExtra : ""}</div>
      <p class="card-report">${escapeHtml(s.report || "—")}</p>
      <time class="card-date">Soumis le ${formatDate(s.createdAt)}</time>
    </div>
  </article>`;
  });
  return '<div class="list">' + cards.join("") + "</div>";
}

function adminHtml(cardsHtml: string): string {
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin — OralScan</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 32px 24px; background: linear-gradient(160deg, #f0f4f8 0%, #e2e8f0 100%); min-height: 100vh; }
    .page-header { margin-bottom: 32px; }
    .page-title { margin: 0; font-size: 1.75rem; font-weight: 700; color: #0f172a; letter-spacing: -0.02em; }
    .page-subtitle { margin: 6px 0 0; font-size: 0.9rem; color: #64748b; }
    .list { display: flex; flex-direction: column; gap: 20px; max-width: 900px; margin: 0 auto; }
    .card { background: #fff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,.06), 0 1px 3px rgba(0,0,0,.04); overflow: hidden; display: flex; flex-wrap: wrap; gap: 0; transition: box-shadow .2s; }
    .card:hover { box-shadow: 0 8px 30px rgba(0,0,0,.08), 0 2px 6px rgba(0,0,0,.05); }
    .card-photo { width: 140px; min-height: 140px; background: #f1f5f9; flex-shrink: 0; }
    .card-photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .card-body { flex: 1; min-width: 0; padding: 24px; display: grid; gap: 16px; grid-template-columns: 1fr auto; grid-template-rows: auto auto 1fr; }
    .card-name { font-size: 1.25rem; font-weight: 600; color: #0f172a; grid-column: 1; }
    .card-score-wrap { grid-column: 2; grid-row: 1 / 3; display: flex; align-items: flex-start; }
    .card-score { display: inline-flex; align-items: baseline; gap: 2px; font-weight: 700; padding: 10px 16px; border-radius: 12px; min-width: 72px; justify-content: center; }
    .card-score-num { font-size: 1.5rem; line-height: 1; }
    .card-score-denom { font-size: 0.95rem; opacity: 0.85; font-weight: 600; }
    .card-score.low { background: #dcfce7; color: #166534; }
    .card-score.mid { background: #fef3c7; color: #b45309; }
    .card-score.high { background: #fee2e2; color: #b91c1c; }
    .card-meta { font-size: 0.875rem; color: #64748b; display: flex; flex-wrap: wrap; gap: 16px 24px; }
    .card-meta span { display: inline-flex; align-items: center; gap: 6px; }
    .card-meta strong { color: #334155; font-weight: 500; }
    .card-report { grid-column: 1 / -1; font-size: 0.9rem; line-height: 1.55; color: #475569; background: #f8fafc; padding: 14px 18px; border-radius: 12px; border-left: 4px solid #94a3b8; margin: 0; }
    .card-date { font-size: 0.75rem; color: #94a3b8; grid-column: 1 / -1; }
    .empty { text-align: center; color: #64748b; padding: 64px 24px; font-size: 1rem; background: #fff; border-radius: 16px; box-shadow: 0 2px 12px rgba(0,0,0,.04); max-width: 400px; margin: 0 auto; }
  </style>
</head>
<body>
  <header class="page-header">
    <h1 class="page-title">Admin — Soumissions</h1>
    <p class="page-subtitle">Résultats des analyses et coordonnées des patients</p>
  </header>
  <div id="root">${cardsHtml}</div>
</body>
</html>`;
}

export async function registerAdminRoutes(app: FastifyInstance) {
  app.get("/admin", async (_request, reply) => {
    const list = await readSubmissions();
    const cardsHtml = renderCards(list);
    const html = adminHtml(cardsHtml);
    reply.header("Cache-Control", "no-store, no-cache, must-revalidate");
    return reply.type("text/html; charset=utf-8").send(html);
  });
}
