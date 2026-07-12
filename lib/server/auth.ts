import "server-only";
import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { getDb } from "./db";

const SESSION_COOKIE = "creatorai_session";
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

export type User = { id: string; name: string; email: string; createdAt: number };

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return `${salt}:${hash}`;
}

function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const candidate = scryptSync(password, salt, 64);
  const expected = Buffer.from(hash, "hex");
  if (candidate.length !== expected.length) return false;
  return timingSafeEqual(candidate, expected);
}

export function createUser(name: string, email: string, password: string): User {
  const db = getDb();
  const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email.toLowerCase());
  if (existing) throw new Error("An account with this email already exists");

  const id = randomUUID();
  const createdAt = Date.now();
  db.prepare(
    "INSERT INTO users (id, name, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)"
  ).run(id, name, email.toLowerCase(), hashPassword(password), createdAt);

  return { id, name, email: email.toLowerCase(), createdAt };
}

export function verifyCredentials(email: string, password: string): User | null {
  const db = getDb();
  const row = db
    .prepare("SELECT id, name, email, password_hash, created_at FROM users WHERE email = ?")
    .get(email.toLowerCase()) as
    | { id: string; name: string; email: string; password_hash: string; created_at: number }
    | undefined;
  if (!row) return null;
  if (!verifyPassword(password, row.password_hash)) return null;
  return { id: row.id, name: row.name, email: row.email, createdAt: row.created_at };
}

export function createSession(userId: string): { token: string; expiresAt: number } {
  const db = getDb();
  const token = randomBytes(32).toString("hex");
  const expiresAt = Date.now() + SESSION_TTL_MS;
  db.prepare("INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)").run(
    token,
    userId,
    expiresAt
  );
  return { token, expiresAt };
}

export function destroySession(token: string) {
  const db = getDb();
  db.prepare("DELETE FROM sessions WHERE token = ?").run(token);
}

export function getUserBySessionToken(token: string): User | null {
  const db = getDb();
  const row = db
    .prepare(
      `SELECT u.id, u.name, u.email, u.created_at, s.expires_at
       FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE s.token = ?`
    )
    .get(token) as
    | { id: string; name: string; email: string; created_at: number; expires_at: number }
    | undefined;
  if (!row) return null;
  if (row.expires_at < Date.now()) {
    destroySession(token);
    return null;
  }
  return { id: row.id, name: row.name, email: row.email, createdAt: row.created_at };
}

export async function getCurrentUser(): Promise<User | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  return getUserBySessionToken(token);
}

export async function setSessionCookie(token: string, expiresAt: number) {
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires: new Date(expiresAt),
  });
}

export async function clearSessionCookie() {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (token) destroySession(token);
  cookieStore.delete(SESSION_COOKIE);
}

export function updateUserName(userId: string, name: string): void {
  const db = getDb();
  db.prepare("UPDATE users SET name = ? WHERE id = ?").run(name, userId);
}

export function updateUserPassword(userId: string, currentPassword: string, newPassword: string): void {
  const db = getDb();
  const row = db.prepare("SELECT password_hash FROM users WHERE id = ?").get(userId) as
    | { password_hash: string }
    | undefined;
  if (!row || !verifyPassword(currentPassword, row.password_hash)) {
    throw new Error("Current password is incorrect");
  }
  db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").run(hashPassword(newPassword), userId);
}

export function deleteUserAccount(userId: string): void {
  const db = getDb();
  db.prepare("DELETE FROM users WHERE id = ?").run(userId);
}

export function initials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
}
