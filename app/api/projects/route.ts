import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/server/auth";
import { createProject, listProjects, toClientProject } from "@/lib/server/projects";
import { renderProjectAssets } from "@/lib/server/render";
import { gradientToHex } from "@/lib/gradient-colors";
import { getDb } from "@/lib/server/db";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const projects = listProjects(user.id).map(toClientProject);
  return NextResponse.json({ projects });
}

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await req.json().catch(() => ({}));
  const {
    name, platform, audience, objective, ratio,
    hook, bodyText, cta, avatarName, avatarEmoji, avatarGradient, voiceName,
    viralityScore, adQualityScore, hookStrength, ctrPrediction,
  } = body ?? {};

  if (!name || !hook || !cta || !avatarName || !voiceName) {
    return NextResponse.json({ error: "Missing required project fields" }, { status: 400 });
  }

  const project = createProject(user.id, {
    name,
    platform: platform ?? "TikTok",
    audience: audience ?? "Everyone",
    objective: objective ?? "Sales",
    ratio: ratio ?? "9:16",
    hook,
    body: bodyText ?? "",
    cta,
    avatar_name: avatarName,
    avatar_emoji: avatarEmoji ?? "🙂",
    avatar_gradient: avatarGradient ?? "from-violet-500 to-fuchsia-500",
    voice_name: voiceName,
    virality_score: viralityScore ?? 0,
    ad_quality_score: adQualityScore ?? 0,
    hook_strength: hookStrength ?? 0,
    ctr_prediction: ctrPrediction ?? 0,
    video_path: null,
    thumbnail_path: null,
  });

  // Render a real MP4 + PNG for this project (gradient background, script
  // text burned in as captions via ffmpeg) so downloads are genuine files.
  try {
    const [c1, c2] = gradientToHex(project.avatar_gradient);
    const { videoPath, thumbnailPath } = renderProjectAssets({
      id: project.id,
      hook: project.hook,
      cta: project.cta,
      avatarName: project.avatar_name,
      voiceName: project.voice_name,
      ratio: (project.ratio as "9:16" | "1:1" | "16:9") ?? "9:16",
      colorHex1: c1,
      colorHex2: c2,
    });
    const db = getDb();
    db.prepare("UPDATE projects SET video_path = ?, thumbnail_path = ? WHERE id = ?").run(
      videoPath,
      thumbnailPath,
      project.id
    );
    project.video_path = videoPath;
    project.thumbnail_path = thumbnailPath;
  } catch (err) {
    console.error("Render failed:", err);
  }

  return NextResponse.json({ project: toClientProject(project) });
}
