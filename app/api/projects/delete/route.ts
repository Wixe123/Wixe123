import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/server/auth";
import { deleteProject, getProjectById } from "@/lib/server/projects";
import { unlinkSync, existsSync } from "node:fs";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { id } = await req.json().catch(() => ({}));
  if (!id) return NextResponse.json({ error: "Missing id" }, { status: 400 });

  const project = getProjectById(id);
  if (project && project.user_id === user.id) {
    for (const filePath of [project.video_path, project.thumbnail_path]) {
      if (filePath && existsSync(filePath)) unlinkSync(filePath);
    }
  }

  deleteProject(user.id, id);
  return NextResponse.json({ ok: true });
}
