import { NextResponse } from "next/server";
import { existsSync, unlinkSync } from "node:fs";
import { getCurrentUser, deleteUserAccount, clearSessionCookie } from "@/lib/server/auth";
import { listProjects } from "@/lib/server/projects";

export async function POST() {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  for (const project of listProjects(user.id)) {
    for (const filePath of [project.video_path, project.thumbnail_path]) {
      if (filePath && existsSync(filePath)) unlinkSync(filePath);
    }
  }

  deleteUserAccount(user.id);
  await clearSessionCookie();
  return NextResponse.json({ ok: true });
}
