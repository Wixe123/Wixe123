import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/server/auth";
import { renderThumbnailPng } from "@/lib/server/render";
import { gradientToHex } from "@/lib/gradient-colors";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { style, gradient, ctrEstimate } = await req.json().catch(() => ({}));
  const [c1, c2] = gradientToHex(gradient ?? "");

  try {
    const png = renderThumbnailPng({
      style: style ?? "Bold",
      colorHex1: c1,
      colorHex2: c2,
      ctrEstimate: ctrEstimate ?? 10,
    });
    return new NextResponse(new Uint8Array(png), {
      headers: {
        "Content-Type": "image/png",
        "Content-Disposition": `attachment; filename="thumbnail-${(style ?? "bold").toLowerCase()}.png"`,
      },
    });
  } catch (err) {
    console.error("Thumbnail render failed:", err);
    return NextResponse.json({ error: "Render failed" }, { status: 500 });
  }
}
