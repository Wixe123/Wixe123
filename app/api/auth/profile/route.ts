import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser, updateUserName } from "@/lib/server/auth";

export async function PATCH(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { name } = await req.json().catch(() => ({}));
  if (!name || !name.trim()) {
    return NextResponse.json({ error: "Name is required" }, { status: 400 });
  }
  updateUserName(user.id, name.trim());
  return NextResponse.json({ ok: true });
}
