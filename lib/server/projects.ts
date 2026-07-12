import "server-only";
import { randomUUID } from "node:crypto";
import { getDb } from "./db";

export type ProjectRow = {
  id: string;
  user_id: string;
  name: string;
  platform: string;
  audience: string;
  objective: string;
  ratio: string;
  hook: string;
  body: string;
  cta: string;
  avatar_name: string;
  avatar_emoji: string;
  avatar_gradient: string;
  voice_name: string;
  virality_score: number;
  ad_quality_score: number;
  hook_strength: number;
  ctr_prediction: number;
  status: string;
  favorite: number;
  video_path: string | null;
  thumbnail_path: string | null;
  created_at: number;
};

export type NewProject = Omit<ProjectRow, "id" | "user_id" | "status" | "favorite" | "created_at">;

export function createProject(userId: string, data: NewProject): ProjectRow {
  const db = getDb();
  const id = randomUUID();
  const createdAt = Date.now();
  db.prepare(
    `INSERT INTO projects (
      id, user_id, name, platform, audience, objective, ratio, hook, body, cta,
      avatar_name, avatar_emoji, avatar_gradient, voice_name,
      virality_score, ad_quality_score, hook_strength, ctr_prediction,
      status, favorite, video_path, thumbnail_path, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Ready', 0, ?, ?, ?)`
  ).run(
    id,
    userId,
    data.name,
    data.platform,
    data.audience,
    data.objective,
    data.ratio,
    data.hook,
    data.body,
    data.cta,
    data.avatar_name,
    data.avatar_emoji,
    data.avatar_gradient,
    data.voice_name,
    data.virality_score,
    data.ad_quality_score,
    data.hook_strength,
    data.ctr_prediction,
    data.video_path,
    data.thumbnail_path,
    createdAt
  );
  return getProjectById(id)!;
}

export function listProjects(userId: string): ProjectRow[] {
  const db = getDb();
  return db
    .prepare("SELECT * FROM projects WHERE user_id = ? ORDER BY created_at DESC")
    .all(userId) as ProjectRow[];
}

export function getProjectById(id: string): ProjectRow | null {
  const db = getDb();
  return (db.prepare("SELECT * FROM projects WHERE id = ?").get(id) as ProjectRow | undefined) ?? null;
}

export function toggleFavorite(userId: string, id: string): void {
  const db = getDb();
  db.prepare(
    "UPDATE projects SET favorite = CASE WHEN favorite = 1 THEN 0 ELSE 1 END WHERE id = ? AND user_id = ?"
  ).run(id, userId);
}

export function deleteProject(userId: string, id: string): void {
  const db = getDb();
  db.prepare("DELETE FROM projects WHERE id = ? AND user_id = ?").run(id, userId);
}

export function toClientProject(p: ProjectRow) {
  return {
    id: p.id,
    name: p.name,
    platform: p.platform,
    audience: p.audience,
    objective: p.objective,
    ratio: p.ratio,
    hook: p.hook,
    body: p.body,
    cta: p.cta,
    avatarName: p.avatar_name,
    avatarEmoji: p.avatar_emoji,
    avatarGradient: p.avatar_gradient,
    voiceName: p.voice_name,
    viralityScore: p.virality_score,
    adQualityScore: p.ad_quality_score,
    hookStrength: p.hook_strength,
    ctrPrediction: p.ctr_prediction,
    status: p.status,
    favorite: Boolean(p.favorite),
    hasVideo: Boolean(p.video_path),
    createdAt: p.created_at,
    fileName: p.video_path ? p.video_path.split("/").pop()! : null,
  };
}
