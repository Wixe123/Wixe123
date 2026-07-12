import { NextRequest, NextResponse } from "next/server";
import { readFileSync, existsSync } from "node:fs";
import { getCurrentUser } from "@/lib/server/auth";
import { getProjectById } from "@/lib/server/projects";

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const id = req.nextUrl.searchParams.get("id");
  const type = req.nextUrl.searchParams.get("type") === "thumbnail" ? "thumbnail" : "video";
  if (!id) return NextResponse.json({ error: "Missing id" }, { status: 400 });

  const project = getProjectById(id);
  if (!project || project.user_id !== user.id) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  const filePath = type === "thumbnail" ? project.thumbnail_path : project.video_path;
  if (!filePath || !existsSync(filePath)) {
    return NextResponse.json({ error: "File not available" }, { status: 404 });
  }

  const bytes = readFileSync(filePath);
  const ext = type === "thumbnail" ? "png" : "mp4";
  const contentType = type === "thumbnail" ? "image/png" : "video/mp4";
  const safeName = project.name.replace(/[^a-z0-9-_]+/gi, "-").toLowerCase();

  return new NextResponse(new Uint8Array(bytes), {
    headers: {
      "Content-Type": contentType,
      "Content-Disposition": `attachment; filename="${safeName}.${ext}"`,
      "Content-Length": String(bytes.length),
    },
  });
}
