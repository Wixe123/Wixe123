import "server-only";
import { DatabaseSync } from "node:sqlite";
import { mkdirSync, existsSync } from "node:fs";
import path from "node:path";

const DATA_DIR = path.join(process.cwd(), "data");
if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });

const DB_PATH = path.join(DATA_DIR, "app.db");

declare global {
  var __creatorai_db: DatabaseSync | undefined;
}

function createConnection(): DatabaseSync {
  const db = new DatabaseSync(DB_PATH);
  db.exec("PRAGMA journal_mode = WAL;");
  db.exec("PRAGMA foreign_keys = ON;");

  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      platform TEXT NOT NULL,
      audience TEXT NOT NULL,
      objective TEXT NOT NULL,
      ratio TEXT NOT NULL,
      hook TEXT NOT NULL,
      body TEXT NOT NULL,
      cta TEXT NOT NULL,
      avatar_name TEXT NOT NULL,
      avatar_emoji TEXT NOT NULL,
      avatar_gradient TEXT NOT NULL,
      voice_name TEXT NOT NULL,
      virality_score INTEGER NOT NULL,
      ad_quality_score INTEGER NOT NULL,
      hook_strength INTEGER NOT NULL,
      ctr_prediction INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'Ready',
      favorite INTEGER NOT NULL DEFAULT 0,
      video_path TEXT,
      thumbnail_path TEXT,
      created_at INTEGER NOT NULL
    );
  `);

  return db;
}

export function getDb(): DatabaseSync {
  if (!globalThis.__creatorai_db) {
    globalThis.__creatorai_db = createConnection();
  }
  return globalThis.__creatorai_db;
}
