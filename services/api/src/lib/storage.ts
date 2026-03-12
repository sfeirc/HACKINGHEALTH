/**
 * Stockage local : photos, données de job, et fichier des soumissions (submissions.json).
 * Préfère le répertoire du package (services/api/storage), avec repli selon process.cwd().
 */
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API_ROOT = path.resolve(__dirname, "..", "..");
const STORAGE_BY_PACKAGE = path.join(API_ROOT, "storage");
const STORAGE_BY_CWD = path.join(process.cwd(), "storage");
const STORAGE_BY_CWD_API = path.join(process.cwd(), "services", "api", "storage");

export const STORAGE_DIR = STORAGE_BY_PACKAGE;
const SUBMISSIONS_FILE = path.join(STORAGE_BY_PACKAGE, "submissions.json");
const PHOTOS_DIR = path.join(STORAGE_BY_PACKAGE, "photos");
const DATA_DIR = path.join(STORAGE_BY_PACKAGE, "data");

export interface JobData {
  result: unknown;
  explanation: unknown;
}

/** Enregistrement d'une soumission utilisateur (formulaire après analyse). */
export interface SubmissionRecord {
  id: string;
  jobId: string;
  firstName: string;
  lastName: string;
  phone: string;
  dateOfBirth: string;
  gender?: string;
  locationOfBirth?: string;
  photoPath: string;
  score: number;
  report: string;
  createdAt: string;
}

/** Crée les répertoires storage/photos et storage/data si besoin. */
async function ensureDirs() {
  await fs.mkdir(PHOTOS_DIR, { recursive: true });
  await fs.mkdir(DATA_DIR, { recursive: true });
}

/** Enregistre la photo et les données de résultat pour un job (appelé par le worker). */
export async function saveJobArtifacts(
  jobId: string,
  imageBase64: string,
  result: unknown,
  explanation: unknown
): Promise<void> {
  await ensureDirs();
  const photoPath = path.join(PHOTOS_DIR, `${jobId}.jpg`);
  const dataPath = path.join(DATA_DIR, `${jobId}.json`);
  const buf = Buffer.from(imageBase64, "base64");
  await fs.writeFile(photoPath, buf);
  await fs.writeFile(
    dataPath,
    JSON.stringify({ result, explanation }, null, 0),
    "utf8"
  );
}

export async function readJobData(jobId: string): Promise<JobData | null> {
  const dataPath = path.join(DATA_DIR, `${jobId}.json`);
  try {
    const raw = await fs.readFile(dataPath, "utf8");
    return JSON.parse(raw) as JobData;
  } catch {
    return null;
  }
}

export async function getPhotoPath(jobId: string): Promise<string | null> {
  const photoPath = path.join(PHOTOS_DIR, `${jobId}.jpg`);
  try {
    await fs.access(photoPath);
    return photoPath;
  } catch {
    return null;
  }
}

/** Chemins possibles du fichier des soumissions (selon le répertoire de lancement). */
const SUBMISSIONS_CANDIDATES = [
  path.join(STORAGE_BY_PACKAGE, "submissions.json"),
  path.join(STORAGE_BY_CWD, "submissions.json"),
  path.join(STORAGE_BY_CWD_API, "submissions.json"),
];

/** Lit le tableau des soumissions depuis le premier fichier trouvé. */
async function readSubmissionsJson(): Promise<SubmissionRecord[]> {
  await ensureDirs();
  for (const filePath of SUBMISSIONS_CANDIDATES) {
    try {
      const raw = await fs.readFile(filePath, "utf8");
      const arr = JSON.parse(raw);
      if (Array.isArray(arr)) return arr;
    } catch {
      continue;
    }
  }
  return [];
}

export async function readSubmissions(): Promise<SubmissionRecord[]> {
  return readSubmissionsJson();
}

/** Ajoute une soumission au fichier submissions.json (écrit dans le storage du package). */
export async function appendSubmission(record: SubmissionRecord): Promise<void> {
  const list = await readSubmissionsJson();
  list.push(record);
  await fs.mkdir(path.dirname(SUBMISSIONS_FILE), { recursive: true });
  await fs.writeFile(SUBMISSIONS_FILE, JSON.stringify(list, null, 2), "utf8");
}
